#!/bin/bash
# create logs directory
mkdir -p /etc/frr/logs
chown -R frr:frr /etc/frr/logs
chmod 775 /etc/frr/logs

# create VTEP source interface
ip link add name lo1 type dummy
ip link set dev lo1 up

# Border Leaf Gateway Configuration
# This leaf provides external connectivity for all tenants via gateway router

# Tenant10 (VNI 10) - Gateway Connectivity
# Provides external gateway access for client1 and client3
ip link add name br10 type bridge                   # Create bridge (SVI) for Tenant10 L2 domain
ip link add name vni10 type vxlan id 10 local 172.30.1.5 dstport 4789 nolearning  # VXLAN tunnel for VNI 10
ip link add name eth3.10 link eth3 type vlan id 10  # VLAN interface to external gateway router
ip link set dev vni10 master br10 addrgenmode none  # Add VXLAN to bridge (disable IPv6 addr gen)
ip link set dev eth3.10 master br10                 # Add gateway VLAN interface to bridge
ip link set dev br10 up                             # Activate Tenant10 bridge
ip link set dev vni10 up                            # Activate VXLAN tunnel
ip link set dev eth3.10 up                          # Activate gateway interface for Tenant10

# Tenant20 (VNI 20) - Gateway Connectivity
# Provides external gateway access for client2
ip link add name br20 type bridge                   # Create bridge (SVI) for Tenant20 L2 domain
ip link add name vni20 type vxlan id 20 local 172.30.1.5 dstport 4789 nolearning  # VXLAN tunnel for VNI 20
ip link add name eth3.20 link eth3 type vlan id 20  # VLAN interface to external gateway router
ip link set dev vni20 master br20 addrgenmode none  # Add VXLAN to bridge (disable IPv6 addr gen)
ip link set dev eth3.20 master br20                 # Add gateway VLAN interface to bridge
ip link set dev br20 up                             # Activate Tenant20 bridge
ip link set dev vni20 up                            # Activate VXLAN tunnel
ip link set dev eth3.20 up                          # Activate gateway interface for Tenant20
