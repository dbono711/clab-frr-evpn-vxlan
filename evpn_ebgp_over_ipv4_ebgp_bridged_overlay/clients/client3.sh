#!/bin/bash
# Single-Homed Client3 Configuration
# Single-homed to leaf02:eth4 (VNI 10 / Tenant10, same VNI as client1)

# Create a VLAN interface for Tenant 10
ip link add name eth1.10 link eth1 type vlan id 10
# Add an IPv4 address to the VLAN interface
ip addr add 10.10.1.3/24 dev eth1.10
# Add a route to Tenant 20 via the external gateway (no default route in this lab)
ip route add 10.20.1.0/24 via 10.10.1.1
# Add route to Internet via the external gateway
ip route add 99.99.99.0/30 via 10.10.1.1
# Bring up the VLAN interface
ip link set dev eth1.10 up
