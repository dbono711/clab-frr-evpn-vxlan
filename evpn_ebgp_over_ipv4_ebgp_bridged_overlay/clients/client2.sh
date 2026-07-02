#!/bin/bash
# Single-Homed Client2 Configuration
# Single-homed to leaf01:eth4 (VNI 20 / Tenant20); no bonding/multi-homing

# create VLAN interface for Tenant 20 service
ip link add name eth1.20 link eth1 type vlan id 20
# assign an IPv4 address to the VLAN interface
ip addr add 10.20.1.2/24 dev eth1.20
# add a route to Tenant10 via the external gateway (no default route in this lab)
ip route add 10.10.1.0/24 via 10.20.1.1
# add a route to Internet via the external gateway
ip route add 99.99.99.0/30 via 10.20.1.1
# bring up the VLAN interface
ip link set dev eth1.20 up
