#!/usr/bin/env python
# -*- coding: utf-8 -*-

import subprocess


def ping(ip_address: str, container) -> str:
    """
    Pings an ip address in a container.

    Args:
        ip_address (str): Target ip address

    Returns:
        str: Status.
    """
    reply = subprocess.run(
        [
            "docker",
            "exec",
            "-it",
            f"{container}",
            "bash",
            "-c",
            f"ping -c 3 -n {ip_address}",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        encoding="utf-8",
    )

    if reply.returncode == 0:
        print("SUCCESS!")
    else:
        print("FAILURE! Initiating network validation")
        pass  # add custom validation testing here


if __name__ == "__main__":
    print("Pinging gateway 10.10.1.1 from client1 over VNI 10...", end="")
    ping("10.10.1.1", "clab-frr-evpn-vxlan-client1")

    print("Pinging client3 10.10.1.3 from client1 over VNI 10...", end="")
    ping("10.10.1.3", "clab-frr-evpn-vxlan-client1")

    print("Pinging gateway 10.20.1.1 from client2 over VNI 20...", end="")
    ping("10.20.1.1", "clab-frr-evpn-vxlan-client2")
