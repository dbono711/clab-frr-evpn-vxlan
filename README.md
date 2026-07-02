# clab-frr-evpn-vxlan

## Overview

This repository contains a collection of [CONTAINERlab](https://containerlab.dev/) topologies for [FRR](https://docs.frrouting.org/en/latest/index.html) labs related to EVPN and VXLAN.

## Topologies

- [evpn_ebgp_over_ipv4_ebgp_bridged_overlay](evpn_ebgp_over_ipv4_ebgp_bridged_overlay) — 2-spine/3-leaf EVPN fabric using eBGP for both the underlay and the `l2vpn evpn` overlay, in a **Bridged Overlay** (L2VNI-only, no IRB/L3VNI) design. Routing between tenants and to the Internet happens on a dedicated external gateway hung off the border leaf, not in the fabric. See its [README](evpn_ebgp_over_ipv4_ebgp_bridged_overlay/README.md) for the full as-built design.
