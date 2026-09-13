# EVPN iBGP over OSPF — Symmetric IRB

Part of [**clab-frr-evpn-vxlan**](https://github.com/dbono711/clab-frr-evpn-vxlan), a collection of [CONTAINERlab](https://containerlab.dev/) topologies for [FRR](https://docs.frrouting.org/en/latest/index.html) labs related to EVPN and VXLAN.

This lab builds a multi-tenant **EVPN/VXLAN datacenter fabric** using FRRouting nodes, attached to a provider edge for Internet egress. The fabric demonstrates an L3 leaf/spine (Clos) design with an **OSPF underlay**, an **iBGP EVPN overlay** reflected off the spines, **symmetric IRB** with **distributed anycast gateways**, **EVPN multi-homing**, dual **border leaves**, and a **firewall** modeling per-tenant security zones (the "VRF sandwich").

> **Design documentation:** see **[DATACENTER-DESIGN.md](./DATACENTER-DESIGN.md)** for the full as-built design — scope, requirements, addressing, underlay/overlay, VXLAN, tenants, EVPN multi-homing, border-leaf egress, and the firewall zone model. This README covers deployment and validation only; the lab is too large to fold its design into the README, unlike the [bridged-overlay](../evpn_ebgp_over_ipv4_ebgp_bridged_overlay) lab.

## Requirements

- [CONTAINERlab](https://containerlab.dev/install/)
  - _The [CONTAINERlab](https://containerlab.dev/install/) installation guide outlines various installation methods. This lab assumes all [pre-requisites](https://containerlab.dev/install/#pre-requisites) (including Docker) are met and CONTAINERlab is installed via the [install script](https://containerlab.dev/install/#install-script)._
- Python 3

## Deploying the lab

```shell
git clone git@github.com:dbono711/clab-frr-evpn-vxlan.git
cd clab-frr-evpn-vxlan/evpn_ibgp_over_ospf_symmetric_irb
make all
```

**_NOTE: CONTAINERlab requires SUDO privileges in order to execute_**

- Initializes the `setup.log` file
- Creates the CONTAINERlab [network](lab.yml) based on the [topology definition](https://containerlab.dev/manual/topo-def-file/)
  - FRR configuration (`frr.conf`, `daemons`, `vtysh.conf`) is bound to every FRR node (`dc01spine01`/`dc01spine02`, `dc01leaf01`–`dc01leaf03`, `dc01border01`/`dc01border02`, `dc01fw01`, `pe1`) at startup
  - Each node also has a shell script bound and executed at startup, which configures the Linux-level Ethernet, bond, VXLAN, bridge, and VRF interfaces — IP addressing on FRR nodes is left to `frr.conf`; IP addressing on the multitool client nodes is done in the shell script itself
- Nodes are managed on `192.168.1.0/24`; the FRR image is `quay.io/frrouting/frr:10.7.0`

### Accessing the container CLI (SHELL)

```shell
docker exec -it <container> bash
```

For example, to access the CLI on the `client1` container:

```shell
$ docker exec -it clab-frr-evpn-vxlan-client1 bash
bash-5.1#
```

Or use the equivalent `Makefile` shortcut:

```shell
make client1
```

### Accessing the container FRR CLI (VTYSH)

```shell
docker exec -it <container> vtysh
```

For example, to access the FRR CLI on the `dc01leaf01` container:

```shell
$ docker exec -it clab-frr-evpn-vxlan-dc01leaf01 vtysh

Hello, this is FRRouting (version 10.7.0).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

dc01leaf01#
```

Or use the equivalent `Makefile` shortcut:

```shell
make dc01leaf01
```

The same shortcut pattern exists for every FRR node (`make dc01spine01`, `make dc01spine02`, `make dc01leaf02`, `make dc01leaf03`, `make dc01border01`, `make dc01border02`, `make dc01fw01`, `make pe1`) and every client (`make client1`, `make client2`, `make client3`, `make client4`).

### Validating routing & switching operation on FRR nodes

**_NOTE: All subsequent commands assume you can access the FRR CLI (VTYSH) per the section above_**

#### Displaying the OSPF underlay

OSPF provides loopback-to-loopback IPv4 reachability for the overlay's iBGP sessions and the VXLAN tunnels to ride on.

```
show ip ospf neighbor
```

You should see a `Full` adjacency to each directly-connected spine/leaf/border neighbor over the point-to-point `172.16.1.0/24` links.

#### Displaying the iBGP EVPN overlay

The overlay is a single-AS iBGP fabric (AS 65000), route-reflected off `dc01spine01`/`dc01spine02`, carrying only the `l2vpn evpn` address family.

```
show bgp l2vpn evpn
```

You should see EVPN Type-2 (MAC/IP), Type-3 (IMET), Type-4 (ES), and Type-5 (IP Prefix) routes for every remote host/VNI/prefix — e.g. on `dc01leaf01` you'd see the Type-3 route for `172.30.1.5` (`dc01leaf03`'s VTEP) and the Type-2 route for `client3`'s MAC/IP.

#### Displaying EVPN MAC/VNI information

```
show evpn mac vni 10
```

```shell
dc01leaf01# show evpn mac vni 10
Number of MACs (local and remote) known for this VNI: 3
Flags: N=sync-neighs, I=local-inactive, P=peer-active, X=peer-proxy
MAC               Type   Flags Intf/Remote ES/VTEP            VLAN  Seq #'s
aa:c1:ab:d5:0e:c9 remote       172.30.1.5                           0/0
aa:bb:cc:dd:00:01 local        br10                                 0/0
```

#### Displaying symmetric-IRB routing in a tenant VRF

Each tenant is its own VRF/L3VNI (`TenantA` → table 100 / L3VNI 1000, `TenantB` → table 200 / L3VNI 2000). Per-host `/32` routes installed via EVPN Type-2, plus the border leaves' EVPN Type-5 default, both land here.

```
show ip route vrf TenantA
```

You should see `10.10.1.0/24` and `10.10.2.0/24` as connected/local on any leaf hosting those VLANs, remote hosts as `/32`s learned via `zebra` (EVPN), and two equal-cost `0.0.0.0/0` routes via `dc01border01`/`dc01border02`.

### Data Plane Validation

Ping between clients to confirm the anycast gateway and symmetric-IRB routing paths actually forward traffic — e.g. from `client1` (`10.10.1.2`, TenantA/VLAN 10, multi-homed to `dc01leaf01`/`dc01leaf02`) to `client2` (`10.10.2.2`, TenantA/VLAN 20, on `dc01leaf03`):

```shell
make client1
ping -c 3 10.10.2.2
```

And to the anycast gateway itself, to confirm it answers identically regardless of which leaf `client1` is currently attached to:

```shell
ping -c 3 10.10.1.1
```

### Cleanup

```shell
make clean
```

### Logging

All Makefile activity is logged to `setup.log` at the root of this directory; per-node FRR logs are written to `logs/<hostname>.log`.

## Authors

- Darren Bono - [darren.bono@att.net](mailto://darren.bono@att.net)

## License

This project is licensed under the MIT License. See [LICENSE](../LICENSE) for details.
