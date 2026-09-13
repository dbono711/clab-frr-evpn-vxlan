#!/bin/bash

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
mkdir -p /etc/frr/logs
chown -R frr:frr /etc/frr/logs
chmod 775 /etc/frr/logs

# ---------------------------------------------------------------------------
# Disable IPv6 node-wide
# ---------------------------------------------------------------------------
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1

# ---------------------------------------------------------------------------
# eth1 — trunked toward dc01border01, one routed VLAN sub-interface per
# tenant, each enslaved to its own VRF.
# ---------------------------------------------------------------------------

# TenantA inside leg
ip link add TenantA type vrf table 100
ip link set dev TenantA up
ip link add name eth1.1000 link eth1 type vlan id 1000
ip link set dev eth1.1000 master TenantA
ip link set dev eth1.1000 up

# TenantB inside leg
ip link add TenantB type vrf table 200
ip link set dev TenantB up
ip link add name eth1.2000 link eth1 type vlan id 2000
ip link set dev eth1.2000 master TenantB
ip link set dev eth1.2000 up

# ---------------------------------------------------------------------------
# eth2 — direct routed link to pe1 (the Internet provider). Previously this
# leg went to dc01border01's Outside VRF; it now connects straight to pe1,
# so the Outside VRF's only physical member is this one link plus the
# tenant VRFs it imports from. No border leaf sits in the Internet path
# anymore for either direction of that traffic.
# ---------------------------------------------------------------------------

# Outside leg
ip link add Outside type vrf table 300
ip link set dev Outside up
ip link set dev eth2 master Outside

# ---------------------------------------------------------------------------
# eth3 — trunked toward dc01border02, second independent path for
# TenantA/TenantB traffic. Same VRFs as eth1, not new ones.
# ---------------------------------------------------------------------------

# TenantA inside leg (second path, via dc01border02)
ip link add name eth3.1000 link eth3 type vlan id 1000
ip link set dev eth3.1000 master TenantA
ip link set dev eth3.1000 up

# TenantB inside leg (second path, via dc01border02)
ip link add name eth3.2000 link eth3 type vlan id 2000
ip link set dev eth3.2000 master TenantB
ip link set dev eth3.2000 up
