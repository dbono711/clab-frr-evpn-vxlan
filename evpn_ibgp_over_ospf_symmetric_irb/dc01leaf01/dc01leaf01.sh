#!/bin/bash

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
mkdir -p /etc/frr/logs
chown -R frr:frr /etc/frr/logs
chmod 775 /etc/frr/logs

# Start by disabling IPv6 for the node as a whole, which will
# suppress IPv6 address generation for the devices
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1

# ---------------------------------------------------------------------------
# VTEP source interface (loopback lo1 — VXLAN local IP 172.30.1.3)
# ---------------------------------------------------------------------------
ip link add name lo1 type dummy
ip link set dev lo1 up

# ---------------------------------------------------------------------------
# EVPN Multi-Homing — bond interface for client1 (eth3)
# client1 is dual-homed: eth3 on dc01leaf01 and the equivalent port on
# dc01leaf02 are both members of the same Ethernet Segment.
# Bonding eth3 into mhbond1 here is the kernel side of that; FRR advertises
# the ES via BGP EVPN type-4 routes to coordinate Designated Forwarder (DF)
# election between the two leaves.
# ---------------------------------------------------------------------------
ip link add dev mhbond1 type bond
ip link set dev eth3 down                           # Prepare eth3 (client1 connection) for bonding
ip link set dev mhbond1 down                        # Prepare bond interface for configuration
ip link set dev eth3 master mhbond1
ip link set dev eth3 up
ip link set dev mhbond1 up

# ---------------------------------------------------------------------------
# L2VNI — VLAN 10 / VNI 10 (TenantA, pure L2 bridging)
# In this mode the VTEP is a transparent L2 bridge. client1 frames tagged
# VLAN 10 arrive on mhbond1.10 and are bridged into VNI 10 for delivery to
# remote VTEPs via VXLAN. No IP routing occurs on the VTEP; the default
# gateway for 10.10.1.0/24 must be an external device.
# ---------------------------------------------------------------------------
ip link add name br10 type bridge                                                   # Bridge domain for VNI 10
ip link add name vni10 type vxlan id 10 local 172.30.1.3 dstport 4789 nolearning    # VXLAN tunnel (BGP EVPN drives FDB, hence nolearning)
ip link add name mhbond1.10 link mhbond1 type vlan id 10                            # VLAN 10 sub-interface toward client1
ip link set dev vni10 master br10                                                   # Add VXLAN to bridge
ip link set dev mhbond1.10 master br10                                              # Add client1 VLAN interface to bridge
ip link set dev br10 up
ip link set dev vni10 up
ip link set dev mhbond1.10 up

# ---------------------------------------------------------------------------
# Anycast Gateway — Symmetric IRB (L3VNI)
# Every VTEP that hosts VLAN 10 / VNI 10 also acts as the L3 default gateway
# for that segment. The defining characteristic of an anycast gateway is that
# ALL VTEPs use the SAME gateway MAC and IP. When client1 ARPs for
# 10.10.1.1 it always receives the same MAC regardless of which VTEP it is
# attached to, so its ARP cache entry remains valid across moves.
#
# For inter-VNI (inter-subnet) routing across the fabric, Symmetric IRB uses
# a dedicated L3VNI tunnel (VNI 1000 for TenantA):
#   ingress VTEP: route packet into TenantA VRF → encapsulate into L3VNI
#   egress VTEP:  decapsulate from L3VNI → route into destination L2VNI
# This eliminates traffic hair-pinning through a central router.

# Suppress ARP flooding on the VXLAN bridge port.
# FRR populates the bridge neighbor table from EVPN type-2 (MAC+IP) routes,
# so ARP queries for known remote hosts are answered locally without flooding
# the query across the VXLAN fabric.
ip link set dev vni10 type bridge_slave neigh_suppress on

# Promote br10 from a pure L2 bridge to an SVI by assigning the anycast
# gateway MAC and IP (IP is assigned in FRR). Every VTEP hosting VLAN 10 must use these exact values.
ip link set dev br10 address aa:bb:cc:dd:00:01  # Anycast MAC — must be identical on every VTEP for VLAN 10

# Create the TenantA VRF (Linux routing table 100).
# Enslaving an interface to a VRF moves its routes into that separate table,
# providing L3 isolation between tenants without separate physical hardware.
ip link add TenantA type vrf table 100
ip link set dev TenantA up
ip link set dev br10 master TenantA             # SVI (10.10.1.1/24) routes go into TenantA table, not global table

# L3VNI — dedicated VXLAN tunnel for TenantA inter-VTEP routed traffic.
# br1000 is a shim bridge required by Linux: a VXLAN must be enslaved to a
# bridge before the bridge can be enslaved to a VRF. FRR reads the
# br1000 → TenantA binding and wires up Symmetric IRB in the dataplane.
ip link add vni1000 type vxlan id 1000 local 172.30.1.3 dstport 4789 nolearning      # L3VNI VXLAN tunnel for TenantA
ip link add br1000 type bridge                                                       # L3VNI bridge (VRF binding shim)
ip link set dev vni1000 master br1000                                                # Attach L3VNI VXLAN to bridge
ip link set dev br1000 master TenantA                                                # Bind L3VNI bridge to TenantA VRF
ip link set dev vni1000 up
ip link set dev br1000 up

# delete default route
# ip route del default
