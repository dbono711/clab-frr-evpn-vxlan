#!/bin/bash
echo "8021q" >> /etc/modules

# create VTEP source interface
ip link add name lo1 type dummy

# create bridge
ip link add name br10 type bridge

# create vni
ip link add name vni110 type vxlan id 110 local 172.30.1.3 dstport 4789 nolearning

# create vlan sub-interface facing host
ip link add name eth3.10 link eth3 type vlan id 10

# add interfaces to bridge
ip link set dev vni110 master br10 addrgenmode none
ip link set dev eth3.10 master br10

# enable devices
ip link set dev lo1 up
ip link set dev br10 up
ip link set dev vni110 up
ip link set dev eth3.10 up