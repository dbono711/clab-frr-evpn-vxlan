#!/bin/bash
# VLAN 20 Service Configuration
ip link add name eth1.20 link eth1 type vlan id 20      # Create Tenant A, VLAN 20 sub-interface (VLAN 20/VNI 20)
ip addr add 10.10.2.2/24 dev eth1.20                    # Assign IP address within VLAN 20
ip link set dev eth1.20 up                              # Activate VLAN 10 sub-interface
# ip route add 10.10.1.0/24 via 10.10.2.1                 # Add route for Tenant A, VLAN 10
# ip route add 10.10.3.0/24 via 10.10.2.1                 # Add route for Tenant B, VLAN 30

# delete default route and add new default route via VLAN 10 anycast gateway
ip route del default
ip route add default via 10.10.2.1
