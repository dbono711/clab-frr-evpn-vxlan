#!/bin/bash
# Create a VLAN interface for Tenant 10
ip link add name eth1.10 link eth1 type vlan id 10
# Add an IPv4 address to the VLAN interface
ip addr add 10.10.1.3/24 dev eth1.10
# Add a default route to Tenant 20
ip route add 10.20.1.0/24 via 10.10.1.1
# Bring up the VLAN interface
ip link set dev eth1.10 up
