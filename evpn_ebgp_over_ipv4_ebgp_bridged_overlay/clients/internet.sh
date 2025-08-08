#!/bin/bash
ip addr add 99.99.99.2/30 dev eth1
# add a route to Tenant10
ip route add 10.10.1.0/24 via 99.99.99.1
# add a route to Tenant20
ip route add 10.20.1.0/24 via 99.99.99.1