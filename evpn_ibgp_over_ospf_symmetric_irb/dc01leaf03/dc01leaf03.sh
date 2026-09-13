#!/bin/bash

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
mkdir -p /etc/frr/logs
chown -R frr:frr /etc/frr/logs
chmod 775 /etc/frr/logs

# ---------------------------------------------------------------------------
# VTEP source interface (loopback lo1 — VXLAN local IP 172.30.1.5)
# ---------------------------------------------------------------------------
ip link add name lo1 type dummy
ip link set dev lo1 up

# Start by disabling IPv6 for the node as a whole, which will
# suppress IPv6 address generation for the devices
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1

# ---------------------------------------------------------------------------
# L2VNI — VLAN 10 / VNI 10 (TenantA, pure L2 bridging)
# In this mode the VTEP is a transparent L2 bridge. client3 frames tagged
# VLAN 10 arrive on eth3.10 and are bridged into VNI 10 for delivery to
# remote VTEPs via VXLAN. No IP routing occurs on the VTEP; the default
# gateway for 10.10.1.0/24 must be an external device.
#
# client3 is single-homed: eth3 connects directly to client3. A simple VLAN
# sub-interface is sufficient.
# ---------------------------------------------------------------------------
ip link add name br10 type bridge                                                   # Bridge domain for VNI 10
ip link add name vni10 type vxlan id 10 local 172.30.1.5 dstport 4789 nolearning    # VXLAN tunnel (BGP EVPN drives FDB, hence nolearning)
ip link add name eth3.10 link eth3 type vlan id 10                                  # VLAN 10 sub-interface toward client3
ip link set dev vni10 master br10                                                   # Add VXLAN to bridge; suppress IPv6 addr gen
ip link set dev eth3.10 master br10                                                 # Add client3 VLAN interface to bridge
ip link set dev br10 up
ip link set dev vni10 up
ip link set dev eth3.10 up

# ---------------------------------------------------------------------------
# L2VNI — VLAN 20 / VNI 20 (TenantA, pure L2 bridging)
# In this mode the VTEP is a transparent L2 bridge. client3 frames tagged
# VLAN 10 arrive on eth4.20 and are bridged into VNI 20 for delivery to
# remote VTEPs via VXLAN. No IP routing occurs on the VTEP; the default
# gateway for 10.10.2.0/24 must be an external device.
#
# client2 is single-homed: eth4 connects directly to client2. A simple VLAN
# sub-interface is sufficient.
# ---------------------------------------------------------------------------
ip link add name br20 type bridge                                                   # Bridge domain for VNI 20
ip link add name vni20 type vxlan id 20 local 172.30.1.5 dstport 4789 nolearning    # VXLAN tunnel (BGP EVPN drives FDB, hence nolearning)
ip link add name eth4.20 link eth4 type vlan id 20                                  # VLAN 20 sub-interface toward client2
ip link set dev vni20 master br20                                                   # Add VXLAN to bridge; suppress IPv6 addr gen
ip link set dev eth4.20 master br20                                                 # Add client2 VLAN interface to bridge
ip link set dev br20 up
ip link set dev vni20 up
ip link set dev eth4.20 up

# ---------------------------------------------------------------------------
# Anycast Gateway — Symmetric IRB (L3VNI)
# Every VTEP that hosts VLAN 10 / VNI 10 also acts as the L3 default gateway
# for that segment. The defining characteristic of an anycast gateway is that
# ALL VTEPs use the SAME gateway MAC and IP. When client3 ARPs for
# 10.10.1.1 it always receives the same MAC regardless of which VTEP it is
# attached to, so its ARP cache entry remains valid across moves.

# Suppress ARP flooding on the VXLAN bridge port.
# FRR populates the bridge neighbor table from EVPN type-2 (MAC+IP) routes,
# so ARP queries for known remote hosts are answered locally without flooding
# the query across the VXLAN fabric.
ip link set dev vni10 type bridge_slave neigh_suppress on
ip link set dev vni20 type bridge_slave neigh_suppress on

# Promote br10 from a pure L2 bridge to an SVI by assigning the anycast
# gateway MAC and IP. Every VTEP hosting VLAN 10 must use these exact values.
ip link set dev br10 address aa:bb:cc:dd:00:01  # Anycast MAC — must be identical on every VTEP for VLAN 10

# Promote br20 from a pure L2 bridge to an SVI by assigning the anycast
# gateway MAC and IP. Every VTEP hosting VLAN 20 must use these exact values.
ip link set dev br20 address aa:bb:cc:dd:00:02  # Anycast MAC — must be identical on every VTEP for VLAN 20

# Create the TenantA VRF (Linux routing table 100).
# Enslaving an interface to a VRF moves its routes into that separate table,
# providing L3 isolation between tenants without separate physical hardware.
ip link add TenantA type vrf table 100
ip link set dev TenantA up
ip link set dev br10 master TenantA              # SVI (10.10.1.1/24) routes go into TenantA table, not global table
ip link set dev br20 master TenantA              # SVI (10.10.2.1/24) routes go into TenantA table, not global table

# L3VNI — dedicated VXLAN tunnel for TenantA inter-VTEP routed traffic.
# br1000 is a shim bridge required by Linux: a VXLAN must be enslaved to a
# bridge before the bridge can be enslaved to a VRF. FRR reads the
# br1000 → TenantA binding and wires up Symmetric IRB in the dataplane.
ip link add vni1000 type vxlan id 1000 local 172.30.1.5 dstport 4789 nolearning    # L3VNI VXLAN tunnel for TenantA
ip link add br1000 type bridge                                                     # L3VNI bridge (VRF binding shim)
ip link set dev vni1000 master br1000                                              # Attach L3VNI VXLAN to bridge; suppress IPv6 addr gen
ip link set dev br1000 master TenantA                                              # Bind L3VNI bridge to TenantA VRF
ip link set dev vni1000 up
ip link set dev br1000 up
