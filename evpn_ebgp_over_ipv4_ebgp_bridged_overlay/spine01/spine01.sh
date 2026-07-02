#!/bin/bash
# create logs directory
mkdir -p /etc/frr/logs
chown -R frr:frr /etc/frr/logs
chmod 775 /etc/frr/logs

# spine01 is underlay transit + EVPN peer only: no VTEP (lo1), no VXLAN/bridge
# interfaces, no client attachment -- all of that is configured in frr.conf
