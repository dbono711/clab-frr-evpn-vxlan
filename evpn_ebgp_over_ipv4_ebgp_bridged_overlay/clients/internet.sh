#!/bin/bash
# Reference "Internet" node, directly attached to gateway:eth2 (99.99.99.0/30).
# No dynamic routing to the provider -- static routes back to both tenants only.

# assign an IPv4 address on the provider link
ip addr add 99.99.99.2/30 dev eth1
# add a route to Tenant10 via the external gateway
ip route add 10.10.1.0/24 via 99.99.99.1
# add a route to Tenant20 via the external gateway
ip route add 10.20.1.0/24 via 99.99.99.1