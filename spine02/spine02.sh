#!/bin/bash
echo "8021q" >> /etc/modules

cat > /etc/network/interfaces << EOF
auto lo1
iface lo1 inet manual
    pre-up ip link add name lo1 type dummy
    up ip link set dev lo1 up

EOF

ifup lo1