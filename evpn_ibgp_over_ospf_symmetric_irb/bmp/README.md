# BMP → Kafka → ClickHouse → Grafana (Lab)

## Overview
Captures BMP messages from FRR routers, publishes them to Kafka with GoBMP, ingests them into ClickHouse, and visualizes them in Grafana.

## Flow (end-to-end)
1. **FRR routers → GoBMP (BMP TCP)**: routers establish BMP sessions and stream BMP messages to the collector on `5000`. This is an EVPN fabric, so the VTEPs monitor the `l2vpn evpn` table (`bmp monitor ipv4 evpn post-policy` and `loc-rib`); peer up/down state is always emitted regardless of what is monitored.
2. **GoBMP → Kafka (JSON)**: GoBMP parses BMP/BGP attributes into structured JSON and publishes to a fixed set of topics. The ones this lab consumes are:
   - `gobmp.parsed.peer` (peer up/down events and metadata)
   - `gobmp.parsed.evpn` (EVPN Type 2/3/5 NLRI; carries both post-policy and loc-rib routes, distinguished within the payload)
   - `gobmp.parsed.unicast_prefix_v4` (plain IPv4 unicast routes — see note below)

   **What is actually monitored:** the EVPN control plane (on the VTEPs) plus peer state. Plain IPv4 unicast only exists in one place in this fabric — `dc01border01`'s `Outside` VRF eBGP to `pe1` (default route in / tenant subnets out), and optionally the tenant VRF loc-rib — so the `unicast_prefix_v4` table stays empty until a `bmp monitor ipv4 unicast` target is added in the relevant instance on that node. There is no `unicast_prefix_v6` table: IPv6 is disabled fabric-wide (`no ipv6 forwarding` + sysctls), so no v6 topic is ever produced.

   **Where these topic names come from:** they are not configured here — they are defined by GoBMP itself. The collector has a hard-coded set of topic-name constants (all prefixed `gobmp.parsed.`), one per message category (peer, evpn, unicast prefixes, LS node/link/prefix, SR policy, etc.). GoBMP creates each topic the first time it has a message of that type to publish, so the topics that actually appear depend on what the routers send.

   **Note on `--split-af`:** the collector's **`--split-af=true`** flag (see `docker-compose.yml`) splits *unicast/L3VPN* prefixes by address family into `_v4` / `_v6` topics (e.g. `gobmp.parsed.unicast_prefix_v4` vs. a combined `gobmp.parsed.unicast_prefix` without the flag). **EVPN is not affected** — it is always a single `gobmp.parsed.evpn` topic. The flag is left enabled so unicast monitoring can be added later without changing topic names.

   **How to confirm the live topic list:** open the Kafka UI at `http://localhost:9000` — it lists every topic GoBMP has actually created, which is the authoritative, empirical source (the constants above are the definitive *possible* set; the UI shows the *present* set). This is how the topic names wired into the SQL were determined.

3. **Kafka → ClickHouse (ingest pipeline)**: Kafka Engine tables act as streaming readers for each topic (`JSONAsString`). Materialized views insert rows into MergeTree tables. `kafka_partition` and `kafka_offset` are captured from Kafka virtual columns alongside an `ingested_at DateTime64(3)` timestamp, giving a tie-free ordering key for "latest event per peer" queries.
4. **Grafana → ClickHouse (visualization)**: dashboards query the MergeTree tables (and the `bmp.peer_state` VIEW for current peer state) in the `bmp` database.

## State diagram
```mermaid
stateDiagram-v2
    [*] --> FRR
    FRR --> GoBMP: BMP TCP (port 5000)
    GoBMP --> Kafka: JSON messages
    Kafka --> CHKafka: Kafka Engine tables
    CHKafka --> CHMV: Materialized views
    CHMV --> CHMergeTree: MergeTree tables
    CHMergeTree --> Grafana: SQL queries
    Grafana --> [*]

    state CHKafka as "ClickHouse Kafka Engine"
    state CHMV as "ClickHouse MVs"
    state CHMergeTree as "ClickHouse MergeTree"
```

## Services (docker-compose.yml)
- **kafka**: broker (`9092` host, `9093` internal); health-gated via `bash /dev/tcp` probe (image is GraalVM native — no JVM, so `kafka-*.sh` tools cannot be used)
- **kafka-ui**: web UI for topics (`http://localhost:9000`)
- **bmp-collector**: GoBMP (`--source-port=5000`, `--kafka-server=kafka:9093`). Note there is intentionally **no host port mapping** for `5000` — the FRR routers reach the collector over the shared clab bridge (`br-frr-dci-provider`) by its container name/IP (`bmp-collector:5000`), so it never needs to be exposed on the host. On the FRR side, each router points its `bmp targets` monitoring session at that address.
- **clickhouse**: HTTP `8123`, native `9001`

## ClickHouse ingestion pattern
```
Kafka Engine table → Materialized View → MergeTree table
```
For `gobmp.parsed.peer`, the MV extracts BGP fields into **typed columns** at ingest time (no per-query JSON parsing). A `bmp.peer_state` VIEW on top provides current state (one row per router/neighbor pair) keyed on `kafka_offset` for tie-free "latest event" resolution.

For `gobmp.parsed.evpn` and `gobmp.parsed.unicast_prefix_v4`, the full JSON payload is stored alongside the Kafka offset; typed column extraction will be added per route type in a future pass.

## Grafana
Install the ClickHouse datasource plugin and point it at:
- Host: `clickhouse`
- Port: `8123`
- Database: `bmp`

Key tables / views for dashboards:

| Object | Type | Purpose |
| ------ | ---- | ------- |
| `bmp.gobmp_parsed_peer` | MergeTree | Raw peer event log (typed columns) |
| `bmp.peer_state` | VIEW | Current state per peer — use this for Up/Down panels |
| `bmp.gobmp_parsed_evpn` | MergeTree | EVPN NLRI event log (raw JSON + offset) |
| `bmp.gobmp_parsed_unicast_prefix_v4` | MergeTree | IPv4 unicast prefix log (raw JSON + offset) |
