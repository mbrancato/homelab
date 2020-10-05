# Bootstrapping

This is the baremetal host deployment and OS configuration for my setup. This mainly consists of an Ansible playbook that builds and deploys a preseeded Debian installer to the lab servers with HP iLO remote management. This could be used to generate the preseeded ISO only for non-HP setups and for testing. There is also a playbook to setup the OS and deploy the Proxmox cluster.

## Baremetal Installation

- Playbook: `baremetal_install.yml`

This playbook will **FORCE BOOT** the hosts in the inventory to the Debian Linux OS installation ISO. To achieve this, the playbook will build an ISO locally, and it will host the ISO images locally as well. You must manually kill the docker container hosting the ISOs when complete.

The field `ilo_address` is used by the playbook to connect to each host in the inventory.

This playbook and preseeded configuration is very specific to my [hardware](../README.md#Hardware). If you are attempting to reuse this, have a look at the device path for the disk you wish to you use and the network interfaces as these will likely be different.

## Memtest

- Playbook: `memtest.yml`

This playbook will **FORCE BOOT** the hosts in the inventory to run [memtest86](https://www.memtest86.com/download.htm) (the old, easy version in my case). This playbook will also host the ISO images locally.You must manually kill the docker container hosting the ISOs when complete.

The field `ilo_address` is used by the playbook to connect to each host in the inventory.

## Driver Update

- Playbook: `update.yml`

This playbook will **FORCE BOOT** the hosts in the inventory to an HP or other driver update CD named `update.iso` in [images/](./images/).

The field `ilo_address` is used by the playbook to connect to each host in the inventory.

# OS Setup

- Playbook: `os_setup.yml`

This playbook will install the major components of the lab including Proxmox. It will also setup all the networking bridges, LACP, etc. Again, the hardware here is very specific to my [hardware](../README.md#Hardware) when it comes to networking.

The preseed configuration can be found in the [preseed.cfg](./files/preseed.cfg) file.

## Proxmox

The Ansible script stops short of completing everything. This is mainly due to Proxmox's reliance on an `stdin` input for SSH to add new nodes. Hopefully in the future they will document a manual setup for corosync or provide a different way. I started down a way of generating a random password for root (also required for adding nodes to Proxmox 🤷‍) and using that temporarily. With enough time, doing it manually by inspecting the `pvecm` script is doable, but wasn't worth the initial effort for one setup.

## Ceph

Ceph is also left unconfigured by the Ansible script. It is initialized, but has no monitors, OSDs, etc. Basically, the following is needed to setup on each node:

**Setup the Ceph monitor**

Note: This is already complete on the first node from the Ansible playbook.

```
$ sudo pveceph createmon
```

**Wipe the disk in bay 1**

This is only needed if you want to wipe the disk and is specific the the [hardware](../README.md#Hardware) in my setup.

```
$ sudo dd if=/dev/zero of=/dev/disk/by-path/pci-0000\:00\:1f.2-ata-1 bs=1M count=200
$ sudo ceph-disk zap /dev/disk/by-path/pci-0000\:00\:1f.2-ata-1
```

**Create the OSD for the disk in bay 1**

```
$ sudo pveceph osd create /dev/disk/by-path/pci-0000\:00\:1f.2-ata-1
```

At this point the Ceph pools and metadata server daemon (mds) are created using the Proxmox web GUI.


## Networking Issues

The final networking expects an LACP trunk. Depending on the switch, it may not be compatible with non-LACP interfaces. The installer is not configured for LACP so it may need to be used on a standard access port.

The Proxmox cluster using corosync can have issues with multicast networks. The configuration included disables IGMP snooping on the bridge devices which solved some issues with cluster splitting. Normal Proxmox troubleshooting for multicast issues apply here.
