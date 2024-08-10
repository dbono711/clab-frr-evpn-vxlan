#!/bin/bash
echo "8021q" >> /etc/modules

cat > /etc/network/interfaces << EOF
auto eth1.10
iface eth1.10 inet static
  pre-up ip link add name eth1.10 link eth1 type vlan id 10
  up ip link set dev eth1.10 up
  address 10.10.1.2
  netmask 255.255.255.0

EOF

ifup eth1.10