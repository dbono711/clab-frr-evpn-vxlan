#!/bin/bash
# create VLAN interface for Tenant 20 service
ip link add name eth1.20 link eth1 type vlan id 20
# assign an IPv4 address to the VLAN interface
ip addr add 10.20.1.2/24 dev eth1.20
# add a route to Tenant10
ip route add 10.10.1.0/24 via 10.20.1.1
# bring up the VLAN interface
ip link set dev eth1.20 up
