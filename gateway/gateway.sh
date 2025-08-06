#!/bin/bash
# create logs directory
mkdir -p /etc/frr/logs
chown -R frr:frr /etc/frr/logs
chmod 775 /etc/frr/logs

# Create a VLAN interface for Tenant 10
ip link add name eth1.10 link eth1 type vlan id 10
# Bring up the VLAN interface
ip link set dev eth1.10 up

# Create a VLAN interface for Tenant 20
ip link add name eth1.20 link eth1 type vlan id 20
# Bring up the VLAN interface
ip link set dev eth1.20 up