#!/bin/bash
# Load the bonding module
# modprobe bonding miimon=100 mode=802.3ad lacp_rate=slow

# Multi-Homing Configuration for Client1
# This client is dual-homed to both leaf01 and leaf02 for redundancy
# The bond interface provides active-active connectivity with EVPN multi-homing

# Create bond interface for multi-homing (LACP 802.3ad)
ip link add dev bond0 type bond

# Prepare interfaces for bonding
ip link set dev eth1 down    # Connection to leaf01
ip link set dev eth2 down    # Connection to leaf02
ip link set dev bond0 down

# Add physical interfaces to the bond
ip link set dev eth1 master bond0
ip link set dev eth2 master bond0

# Activate the multi-homed bond interface
ip link set dev eth1 up
ip link set dev eth2 up
ip link set dev bond0 up

# Tenant10 Service Configuration
# Create VLAN interface for Tenant10 (VNI 10) isolation
ip link add name bond0.10 link bond0 type vlan id 10
# Assign IP address within Tenant10 subnet
ip addr add 10.10.1.2/24 dev bond0.10
# Add route to Tenant20
ip route add 10.20.1.0/24 via 10.10.1.1
# Activate Tenant10 service interface
ip link set dev bond0.10 up
