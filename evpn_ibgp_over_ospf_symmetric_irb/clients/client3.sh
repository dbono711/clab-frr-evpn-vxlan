#!/bin/bash
# VLAN 10 Service Configuration
ip link add name eth1.10 link eth1 type vlan id 10      # Create Tenant A, VLAN 10 sub-interface (VLAN 10/VNI 10)
ip addr add 10.10.1.3/24 dev eth1.10                    # Assign IP address within VLAN 10
ip link set dev eth1.10 up                              # Activate VLAN 10 sub-interface
# ip route add 10.10.2.0/24 via 10.10.1.1                 # Add route for Tenant A, VLAN 20
# ip route add 10.10.3.0/24 via 10.10.1.1                 # Add route for Tenant B, VLAN 30

# delete default route and add new default route via VLAN 10 anycast gateway
ip route del default
ip route add default via 10.10.1.1
