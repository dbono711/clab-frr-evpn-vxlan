#!/bin/bash

# Multi-Homing Configuration for Client1
# This client is dual-homed to both dc01leaf01 and dc01leaf02 for redundancy
# The bond interface provides active-active connectivity with EVPN multi-homing

# Create bond interface for multi-homing (LACP 802.3ad)
ip link add dev bond0 type bond

# Prepare interfaces for bonding
ip link set dev eth1 down    # Connection to dc01leaf01
ip link set dev eth2 down    # Connection to dc01leaf02
ip link set dev bond0 down

# Add physical interfaces to the bond
ip link set dev eth1 master bond0
ip link set dev eth2 master bond0

# Activate the multi-homed bond interface
ip link set dev eth1 up
ip link set dev eth2 up
ip link set dev bond0 up

# VLAN 10 Service Configuration
ip link add name bond0.10 link bond0 type vlan id 10    # Create Tenant A, VLAN 10 sub-interface (VLAN 10/VNI 10)
ip addr add 10.10.1.2/24 dev bond0.10                   # Assign IP address within VLAN 10
ip link set dev bond0.10 up                             # Activate VLAN 10 sub-interface
# ip route add 10.10.2.0/24 via 10.10.1.1                 # Add route for Tenant A, VLAN 20
# ip route add 10.10.3.0/24 via 10.10.1.1                 # Add route for Tenant B, VLAN 30

# delete default route and add new default route via VLAN 10 anycast gateway
ip route del default
ip route add default via 10.10.1.1
