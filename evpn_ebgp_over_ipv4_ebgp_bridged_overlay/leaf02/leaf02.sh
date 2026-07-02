#!/bin/bash
# create logs directory
mkdir -p /etc/frr/logs
chown -R frr:frr /etc/frr/logs
chmod 775 /etc/frr/logs

# create VTEP source interface
ip link add name lo1 type dummy
ip link set dev lo1 up

# EVPN Multi-Homing Configuration
# Configure bond interface for client1 dual-homing (eth3 connects to client1)
# NOTE: no "mode" is passed, so this is Linux's default balance-rr bond, not
# 802.3ad/LACP; the EVPN Ethernet Segment config below is what drives actual
# multi-homing/DF-election with leaf01, independent of the local bond mode
ip link add dev mhbond1 type bond                    # Create bond for client1 multi-homing
ip link set dev eth3 down                           # Prepare eth3 (client1 connection) for bonding
ip link set dev mhbond1 down                        # Prepare bond interface for configuration
ip link set dev eth3 master mhbond1                 # Add eth3 to bond (dual-homed with leaf01)
ip link set dev eth3 up                             # Activate eth3 interface
ip link set dev mhbond1 up                          # Activate multi-homed bond interface

# Tenant10 (VNI 10) - Multi-homed and Single-homed Client Configuration
# This tenant serves client1 (dual-homed) and client3 (single-homed via eth4)
ip link add name br10 type bridge                   # Create bridge (SVI) for Tenant10 L2 domain
ip link add name vni10 type vxlan id 10 local 172.30.1.4 dstport 4789 nolearning  # VXLAN tunnel for VNI 10
ip link add name eth4.10 link eth4 type vlan id 10  # VLAN interface for client3 Tenant10 traffic
ip link add name mhbond1.10 link mhbond1 type vlan id 10  # VLAN interface for client1 Tenant10 traffic
ip link set dev vni10 master br10 addrgenmode none  # Add VXLAN to bridge (disable IPv6 addr gen)
ip link set dev eth4.10 master br10                 # Add client3 VLAN interface to bridge
ip link set dev mhbond1.10 master br10              # Add client1 VLAN interface to bridge
ip link set dev br10 up                             # Activate Tenant10 bridge
ip link set dev vni10 up                            # Activate VXLAN tunnel
ip link set dev eth4.10 up                          # Activate client3 Tenant10 interface
ip link set dev mhbond1.10 up                       # Activate client1 Tenant10 interface
