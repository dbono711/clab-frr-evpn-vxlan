#!/bin/bash

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
mkdir -p /etc/frr/logs
chown -R frr:frr /etc/frr/logs
chmod 775 /etc/frr/logs

# ---------------------------------------------------------------------------
# VTEP source interface (loopback lo1 — VXLAN local IP 172.30.1.6)
# ---------------------------------------------------------------------------
ip link add name lo1 type dummy
ip link set dev lo1 up

# ---------------------------------------------------------------------------
# Disable IPv6 node-wide
# ---------------------------------------------------------------------------
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1

# ---------------------------------------------------------------------------
# Anycast Gateway — Symmetric IRB (L3VNI) for TenantA
# ---------------------------------------------------------------------------
ip link add TenantA type vrf table 100
ip link set dev TenantA up

ip link add vni1000 type vxlan id 1000 local 172.30.1.6 dstport 4789 nolearning     # L3VNI VXLAN tunnel for TenantA
ip link add br1000 type bridge                                                      # L3VNI bridge (VRF binding shim)
ip link set dev vni1000 master br1000
ip link set dev br1000 master TenantA
ip link set dev vni1000 up
ip link set dev br1000 up

# ---------------------------------------------------------------------------
# Anycast Gateway — Symmetric IRB (L3VNI) for TenantB
# ---------------------------------------------------------------------------
ip link add TenantB type vrf table 200
ip link set dev TenantB up

ip link add vni2000 type vxlan id 2000 local 172.30.1.6 dstport 4789 nolearning     # L3VNI VXLAN tunnel for TenantB
ip link add br2000 type bridge                                                      # L3VNI bridge (VRF binding shim)
ip link set dev vni2000 master br2000
ip link set dev br2000 master TenantB
ip link set dev vni2000 up
ip link set dev br2000 up

# ---------------------------------------------------------------------------
# Firewall attachment — eth5 (tenant-facing, trunked)
#
# TenantA/TenantB inside legs only. This node no longer carries an Outside
# VRF at all: Internet egress now connects dc01fw01 directly to pe1, so
# dc01border01 (like dc01border02) is a pure TenantA/TenantB transit VTEP —
# no eth3/eth6, no local-only Outside table.
# ---------------------------------------------------------------------------

# TenantA inside leg
ip link add name eth5.1000 link eth5 type vlan id 1000
ip link set dev eth5.1000 master TenantA
ip link set dev eth5.1000 up

# TenantB inside leg
ip link add name eth5.2000 link eth5 type vlan id 2000
ip link set dev eth5.2000 master TenantB
ip link set dev eth5.2000 up
