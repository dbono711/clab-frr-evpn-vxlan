#!/bin/bash
# VLAN 30 Service Configuration
ip link add name eth1.30 link eth1 type vlan id 30      # Create Tenant B, VLAN 30 sub-interface (VLAN 30/VNI 30)
ip addr add 10.10.3.2/24 dev eth1.30                    # Assign IP address within VLAN 30
ip link set dev eth1.30 up                              # Activate VLAN 30 sub-interface
# ip route add 10.10.1.0/24 via 10.10.3.1                 # Add route for Tenant A, VLAN 10
# ip route add 10.10.2.0/24 via 10.10.3.1                 # Add route for Tenant A, VLAN 20

# delete default route and add new default route via VLAN 10 anycast gateway
ip route del default
ip route add default via 10.10.3.1
