#!/bin/bash

# create logs directory
mkdir -p /etc/frr/logs
chown -R frr:frr /etc/frr/logs
chmod 775 /etc/frr/logs

# create internet interface
ip link add internet type dummy
ip link set internet up
