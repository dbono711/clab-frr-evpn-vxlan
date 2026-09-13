-- Kafka → ClickHouse flow:
-- Kafka topics (gobmp.parsed.peer, gobmp.parsed.evpn, gobmp.parsed.unicast_prefix_v4)
-- → Kafka engine tables (streaming readers)
-- → materialized views (continuous ingest)
-- → MergeTree tables (persistent storage for Grafana queries).
--
-- This is an EVPN fabric, so the routes of interest (Type 2/3/5) are carried in
-- the l2vpn evpn table. The FRR nodes monitor that via
-- `bmp monitor ipv4 evpn post-policy` (+ loc-rib), which GoBMP publishes to the
-- single gobmp.parsed.evpn topic. Peer up/down is always emitted (gobmp.parsed.peer).
--
-- gobmp.parsed.unicast_prefix_v4 carries plain IPv4 unicast routes. The only
-- place these exist in this fabric is on dc01border01: the Outside VRF's eBGP to
-- pe1 (default route in / tenant subnets out), and optionally the tenant VRF
-- loc-rib. It stays empty until a `bmp monitor ipv4 unicast` target is added in
-- the relevant instance. No v6 table: IPv6 is disabled fabric-wide.
--
-- kafka_partition + kafka_offset are captured in all tables. Within a single Kafka
-- partition, offset is strictly monotonic, making it a tie-free "latest event" key
-- (argMax(…, kafka_offset)). ingested_at is DateTime64(3) for millisecond
-- resolution in Grafana time axes; it is the local arrival time, not the BMP
-- message timestamp (which is extracted per-table where useful).

-- Database for BMP lab ingestion (created once, reused across restarts).
CREATE DATABASE IF NOT EXISTS bmp;

-- =============================================================================
-- PEER (gobmp.parsed.peer)
--
-- Fields are extracted into typed columns at ingest time by the materialized
-- view. This avoids repeated JSON parsing in every Grafana query and makes the
-- GROUP BY (router, neighbor, peer_rd) ORDER BY on disk, so the peer_state VIEW
-- below is a simple scan.
--
-- Router identity: `local_bgp_id` is used as the canonical router key because it
-- is always populated on both `add` and `down` events. `router_ip` is '0.0.0.0'
-- on some peer-up messages and so is not reliable alone.
--
-- loc-rib pseudo-peer: when `bmp monitor ipv4 evpn loc-rib` is active, GoBMP
-- emits peer rows with remote_ip '0.0.0.0' and is_loc_rib = true. These are
-- not real BGP neighbors and are filtered in the peer_state VIEW below.
-- =============================================================================

CREATE TABLE IF NOT EXISTS bmp.gobmp_parsed_peer
(
  kafka_partition  UInt64,
  kafka_offset     UInt64,
  ingested_at      DateTime64(3) DEFAULT now64(3),
  -- BMP / BGP fields
  action           LowCardinality(String),  -- 'add' (session up) or 'down' (session down)
  router_ip        String,                  -- reporting router IP (may be '0.0.0.0' on early up events)
  local_bgp_id     String,                  -- reporting router BGP-ID; always set, used as router key
  local_ip         String,
  local_asn        UInt32,
  local_port       UInt16,
  remote_ip        String,                  -- neighbor IP; '0.0.0.0' = loc-rib pseudo-peer
  remote_bgp_id    String,
  remote_asn       UInt32,
  remote_port      UInt16,
  peer_rd          String,
  peer_type        UInt8,
  bmp_reason       UInt8,                   -- meaningful only on 'down' events (BMP reason code)
  is_prepolicy     Bool,
  is_loc_rib       Bool,
  bmp_timestamp    DateTime64(3),           -- timestamp carried inside the BMP message
  payload          String                   -- full raw JSON retained for any field not extracted above
)
ENGINE = MergeTree
ORDER BY (local_bgp_id, remote_ip, peer_rd, kafka_offset);
-- ORDER BY places all events for the same (router, neighbor) together on disk,
-- making the peer_state GROUP BY efficient.

-- Kafka engine table: streams raw JSON from gobmp.parsed.peer (no storage).
CREATE TABLE IF NOT EXISTS bmp.gobmp_parsed_peer_kafka
(
  payload String
)
ENGINE = Kafka('kafka:9093', 'gobmp.parsed.peer', 'clickhouse', 'JSONAsString')
SETTINGS kafka_num_consumers = 1, kafka_thread_per_consumer = 0;

-- Materialized view: extracts typed fields from each JSON row and writes into
-- the MergeTree table. _partition and _offset are Kafka engine virtual columns.
CREATE MATERIALIZED VIEW IF NOT EXISTS bmp.mv_gobmp_parsed_peer
TO bmp.gobmp_parsed_peer
AS
SELECT
  _partition                                                                        AS kafka_partition,
  _offset                                                                           AS kafka_offset,
  now64(3)                                                                          AS ingested_at,
  JSONExtractString(payload, 'action')                                              AS action,
  JSONExtractString(payload, 'router_ip')                                           AS router_ip,
  JSONExtractString(payload, 'local_bgp_id')                                        AS local_bgp_id,
  JSONExtractString(payload, 'local_ip')                                            AS local_ip,
  toUInt32OrZero(JSONExtractString(payload, 'local_asn'))                           AS local_asn,
  toUInt16OrZero(JSONExtractString(payload, 'local_port'))                          AS local_port,
  JSONExtractString(payload, 'remote_ip')                                           AS remote_ip,
  JSONExtractString(payload, 'remote_bgp_id')                                       AS remote_bgp_id,
  toUInt32OrZero(JSONExtractString(payload, 'remote_asn'))                          AS remote_asn,
  toUInt16OrZero(JSONExtractString(payload, 'remote_port'))                         AS remote_port,
  JSONExtractString(payload, 'peer_rd')                                             AS peer_rd,
  toUInt8OrZero(JSONExtractString(payload, 'peer_type'))                            AS peer_type,
  toUInt8OrZero(JSONExtractString(payload, 'bmp_reason'))                           AS bmp_reason,
  JSONExtractBool(payload, 'is_prepolicy')                                          AS is_prepolicy,
  JSONExtractBool(payload, 'is_loc_rib')                                            AS is_loc_rib,
  parseDateTime64BestEffortOrZero(JSONExtractString(payload, 'timestamp'), 3)       AS bmp_timestamp,
  payload                                                                           AS payload
FROM bmp.gobmp_parsed_peer_kafka;

-- VIEW: current peer state — one row per (router, neighbor, peer_rd), always current.
-- argMax(…, kafka_offset) selects the latest value per field within each peer group.
-- Keying on local_bgp_id (not router_ip) correctly unifies add/down events from
-- the same router. Filtering remote_ip != '0.0.0.0' removes the loc-rib pseudo-peer.
--
-- Grafana queries: SELECT * FROM bmp.peer_state ORDER BY router, neighbor
CREATE VIEW IF NOT EXISTS bmp.peer_state AS
SELECT
  local_bgp_id                                             AS router,
  remote_ip                                                AS neighbor,
  argMax(remote_bgp_id,   kafka_offset)                    AS neighbor_bgp_id,
  argMax(remote_asn,      kafka_offset)                    AS remote_asn,
  argMax(local_asn,       kafka_offset)                    AS local_asn,
  peer_rd,
  if(argMax(action, kafka_offset) = 'add', 'Up', 'Down')  AS state,
  argMax(bmp_timestamp,   kafka_offset)                    AS last_change,
  argMax(bmp_reason,      kafka_offset)                    AS last_down_reason
FROM bmp.gobmp_parsed_peer
WHERE remote_ip  != '0.0.0.0'
  AND is_loc_rib  = false
GROUP BY local_bgp_id, remote_ip, peer_rd;

-- =============================================================================
-- EVPN (gobmp.parsed.evpn)
--
-- Typed columns cover the fields common across route types (2/3/4/5) plus the
-- Type-2-specific mac/mac_len, used for the dashboard's Router/MAC variables.
-- `vni` is pulled out of `rawlabels[1]` at ingest time so panels don't need to
-- repeat that array extraction per query. Anything not extracted (base_attrs,
-- ext_community_list, labels, ...) stays available via `payload`.
--
-- Router identity: same fix as gobmp_parsed_peer — `router_ip` is '0.0.0.0' on
-- loc-rib records, so `remote_bgp_id` is the canonical router key here too.
-- =============================================================================

CREATE TABLE IF NOT EXISTS bmp.gobmp_parsed_evpn
(
  kafka_partition  UInt64,
  kafka_offset     UInt64,
  ingested_at      DateTime64(3) DEFAULT now64(3),
  -- BMP / BGP fields
  action           LowCardinality(String),  -- 'add' or 'del'
  route_type       UInt8,                   -- EVPN route type: 1=EAD, 2=MAC/IP, 3=IMET, 4=ES, 5=IP Prefix
  router_ip        String,                  -- reporting router IP; '0.0.0.0' on loc-rib records — see remote_bgp_id
  remote_bgp_id    String,                  -- reporting router's own BGP-ID on loc-rib records; canonical router key
  peer_ip          String,
  peer_asn         UInt32,
  peer_type        UInt8,
  is_loc_rib       Bool,
  vpn_rd           String,                  -- route distinguisher, e.g. '172.29.1.3:10'
  vni              UInt32,                  -- from rawlabels[1]; 0 if not present (e.g. Type 4 ES routes)
  nexthop          String,
  mac              String,                  -- Type 2 only; empty for other route types
  mac_len          UInt16,
  ip_address       String,                  -- Type 2 (optional) / Type 5
  ip_len           UInt8,
  eth_segment_id   String,                  -- Type 1 / Type 4
  bmp_timestamp    DateTime64(3),           -- timestamp carried inside the BMP message
  payload          String                   -- full raw JSON retained for any field not extracted above
)
ENGINE = MergeTree
ORDER BY (route_type, remote_bgp_id, vpn_rd, kafka_offset);
-- Sort key matches how every panel already queries this table: filter by
-- route_type first, then group by (router, RD) for "latest state" via
-- argMax(..., kafka_offset).

CREATE TABLE IF NOT EXISTS bmp.gobmp_parsed_evpn_kafka
(
  payload String
)
ENGINE = Kafka('kafka:9093', 'gobmp.parsed.evpn', 'clickhouse', 'JSONAsString')
SETTINGS kafka_num_consumers = 1, kafka_thread_per_consumer = 0;

CREATE MATERIALIZED VIEW IF NOT EXISTS bmp.mv_gobmp_parsed_evpn
TO bmp.gobmp_parsed_evpn
AS
SELECT
  _partition                                                                        AS kafka_partition,
  _offset                                                                           AS kafka_offset,
  now64(3)                                                                          AS ingested_at,
  JSONExtractString(payload, 'action')                                              AS action,
  toUInt8OrZero(JSONExtractString(payload, 'route_type'))                           AS route_type,
  JSONExtractString(payload, 'router_ip')                                           AS router_ip,
  JSONExtractString(payload, 'remote_bgp_id')                                       AS remote_bgp_id,
  JSONExtractString(payload, 'peer_ip')                                             AS peer_ip,
  toUInt32OrZero(JSONExtractString(payload, 'peer_asn'))                            AS peer_asn,
  toUInt8OrZero(JSONExtractString(payload, 'peer_type'))                            AS peer_type,
  JSONExtractBool(payload, 'is_loc_rib')                                            AS is_loc_rib,
  JSONExtractString(payload, 'vpn_rd')                                              AS vpn_rd,
  JSONExtract(payload, 'rawlabels', 'Array(UInt32)')[1]                             AS vni,
  JSONExtractString(payload, 'nexthop')                                             AS nexthop,
  JSONExtractString(payload, 'mac')                                                 AS mac,
  toUInt16OrZero(JSONExtractString(payload, 'mac_len'))                             AS mac_len,
  JSONExtractString(payload, 'ip_address')                                          AS ip_address,
  toUInt8OrZero(JSONExtractString(payload, 'ip_len'))                               AS ip_len,
  JSONExtractString(payload, 'eth_segment_id')                                      AS eth_segment_id,
  parseDateTime64BestEffortOrZero(JSONExtractString(payload, 'timestamp'), 3)       AS bmp_timestamp,
  payload                                                                           AS payload
FROM bmp.gobmp_parsed_evpn_kafka;

-- =============================================================================
-- UNICAST PREFIX v4 (gobmp.parsed.unicast_prefix_v4)
--
-- Source: dc01border01 Outside VRF eBGP to pe1 (and optionally tenant VRF
-- loc-rib). Table is pre-created; it stays empty until a
-- `bmp monitor ipv4 unicast` target is added to the relevant bgp instance.
-- Typed column extraction to be added alongside EVPN in a future pass.
-- =============================================================================

CREATE TABLE IF NOT EXISTS bmp.gobmp_parsed_unicast_prefix_v4
(
  kafka_partition  UInt64,
  kafka_offset     UInt64,
  ingested_at      DateTime64(3) DEFAULT now64(3),
  payload          String
)
ENGINE = MergeTree
ORDER BY (kafka_partition, kafka_offset);

CREATE TABLE IF NOT EXISTS bmp.gobmp_parsed_unicast_prefix_v4_kafka
(
  payload String
)
ENGINE = Kafka('kafka:9093', 'gobmp.parsed.unicast_prefix_v4', 'clickhouse', 'JSONAsString')
SETTINGS kafka_num_consumers = 1, kafka_thread_per_consumer = 0;

CREATE MATERIALIZED VIEW IF NOT EXISTS bmp.mv_gobmp_parsed_unicast_prefix_v4
TO bmp.gobmp_parsed_unicast_prefix_v4
AS
SELECT
  _partition  AS kafka_partition,
  _offset     AS kafka_offset,
  now64(3)    AS ingested_at,
  payload
FROM bmp.gobmp_parsed_unicast_prefix_v4_kafka;
