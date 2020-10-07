# Homelab

![status](https://img.shields.io/static/v1?label=status&message=work%20in%20progress&color=ORANGE)
![version](https://img.shields.io/badge/version-5.0.0-green)

This repo holds the description and code used to build my home lab.

* [Summary](#summary)
  * [Energy Usage](#energy-usage)
* [Hardware](#hardware)
* [Network](#network)
* [Software](#software)
* [Installation](#installation)
* [Previous Lab Setup](#previous-lab-setup)

## Summary

The current setup uses 3 HP DL360e Gen8 servers, a UniFI Security Gateway, and a container doing DNS over HTTPS using [cloudflared](https://github.com/cloudflare/cloudflared). Additionally, I have a number of VMs for testing and internal services.

My previous setup was using almost 770W of energy in an idle state. The operating costs were high and I wanted to reduce this while also improving my existing setup. The main goals were:

- Reduce energy usage
- Maintain local data redundancy (disk or block mirroring)
- Enable high-availability by reducing single points of failure

For more information, see my [previous setup](#previous-setup).

This repo and implementation was originally inspired by [Brad's Homelab](https://github.com/bradfitz/homelab). Eventually, I dropped Proxmox and switched to Kubernetes in an apparent attempt to drive myself crazy.

### Energy Usage

|   | Previous | Current | Savings |
|---|---|---|---|
| Avg. Power | 770 W | 550 W | 220 W |
| Annual Energy | 6745 kWh | 4818 kWh | 1927 kWh |
| Annual Cost | $613.80 | $438.44 | **$175.36** |

I have high hopes that my operating cost reductions can pay for the new hardware in about 3 years. My current energy rate is very low at 9.1 cents per kWh making recouping expenses in new hardware a challenge.


Approximate device power consumption:

| Device | Quantity | Power | Total |
|---|:---:|---|---|
| ProCurve J9021A | 1 | 40 W | 40 W |
| UniFI UAP-AC-PRO-US | 2 | 5 W | 10 W |
| Supermicro 2U server | 1 | 247 W | 247 W |
| HP DL360e Gen8 | 3 | 85 W | 255 W |

These were measured with a Kill-A-Watt (accurate) and by monitoring the UPS power output display (approximate).

## Hardware

**Servers**

- 3x HP DL360e Gen8
  - 2x Intel Xeon E5-2407 (8 cores @ 2.2GHz)
  - 2x 750 W power supplies
  - 40GB of memory
  - 4x gigabit NICs
  - Emulex / HP NC552SFP 8x PCIe 10Gb 2-port SFP+ adapter
  - Crucial MX500 250GB M.2 SSD SATA drive
  - 1x Dual M.2 to PCIe adapter - NVMe and SATA (power only)

The operating system is installed on the M.2 SATA SSD. Originally I had this configured on the HP Smart Array B120i controller, but I noticed that after some time, the disk would be lost during reboots. It was simply fixed by recreating the single-drive RAID-0 "array". All credit goes to [this post](https://community.hpe.com/t5/proliant-servers-netservers/dynamic-smart-array-loses-logical-drives-g8-b120i/m-p/7048172/highlight/true#M22095) where I learned that I could use legacy mode and swap to the second controller to boot directly from the M.2 SATA disk. It is hooked up to a SATA port that is normally designed to run the CDROM drive in the DL360e.

**Network**

- HP ProCurve J9021A 2810-24G
  - Version N.11.78
  - 24 gigabit ports
- 2x Ubiquiti Networks UniFI UAP-AC-PRO-US
  - 802.11 a/b/g/n/ac 2.4Ghz / 5GHz
  - 3x3 MIMO
  - PoE Powered (802.3af / 803.2at)

In lieu of an expensive 10Gb switch, my plan was to create a small mesh network. It's actually a small ring topology network, but it's so small that it is also a mesh. If this were extended to include a fourth server, it would be a ring.

![](images/network_layout.png)

The 4x 1Gb network interfaces on each server are bonded using  [LACP (802.3ad)](https://en.wikipedia.org/wiki/Link_aggregation) with the switch. There are software bridges configured on each node that is also VLAN-aware, making all the links between the switch-node, and node-node VLAN trunks. Spanning Tree is enabled, which causes two of the 4Gb LACP trunks to be shutdown in normal operation.

The two APs cover my 2-story house with a basement well with one unit mounted on the ceiling of the second floor, and another mounted on the ceiling in the basement.

**Network Attached Storage**

- Supermicro 2U server
  - FreeNAS 11.1
  - SC826 2U chassis
  - X8DTN+ motherboard
  - SAS-826A backplane
  - 2x 800 W power supplies
  - 2x Intel Xeon L5620 CPUs (8 cores @ 2.13GHz)
  - 24GB of memory
  - 32GB M.2 SATA SSD (boot drive)
  - 2x Seagate ST6000NM0034 6TB 7200 RPM SAS drives in ZFS mirror

This system is my home NAS and previously hosted all VM images and an SMB file share used to store photos and documents. It is still used for SMB but will be transitioned away at some point.

**UPS**

- CyberPower OR2200PFCRT2U
  - 2000 VA
  - 1540 W
  - Active power factor correction
  - 2× NEMA 5-20R
  - 6× NEMA 5-15R

## Network

The network is made up of several VLANs.

- VLAN 1 - HOME - Unused / management
- VLAN 4 - GUESTS - Wireless guests
- VLAN 10 - GENERAL - General purpose LAN
- VLAN 20 - STORAGE - SAN / Ceph traffic (unused)
- VLAN 30 - PVECLUSTER - Proxmox VE / corosync (unused)
- VLAN 60 - CAMERAS - IP cameras (unused)
- VLAN 70 - EDGE - Internet edge (unused)
- VLAN 90 - DEVICES - Devices / IoT

Initially I had setup a dedicated storage network for my previous setup with Proxmox. However, with Kubernetes, I've flattened the network and joined my 10Gb host network interfaces into the spanning tree. This allows them to communicate over the 10Gb links without needing multiple host bridges for dedicated inter-node VLANs.

## Software

This new setup is [hyper-converged](https://en.wikipedia.org/wiki/Hyper-converged_infrastructure) with storage, networking, and compute all managed and deployed on Kubernetes.

- Debian 10 Buster
  - [Kubernetes](https://kubernetes.io/) 1.18
    - [Rook Ceph](https://rook.io/)
    - [KubeVirt](https://kubevirt.io/)
    - [MetalLB](https://metallb.universe.tf/)
    - [Multus CNI](https://github.com/intel/multus-cni)
    - [Calico](https://www.projectcalico.org/)
    - [FluxCD](https://fluxcd.io/)


## Installation

Initial deployment of the bare metal servers and underlying software is done using various [Ansible playbooks](./playbooks/). Bootstraping of the main cluster is performed using the HP iLO card to boot and automate the installation of Debian GNU/Linux. Once the cluster is up and running, the deployment onto the cluster can *mostly* happen via continuous deployment (CD). For CD, Flux will install the manifests and charts as declarative cluster configuration under [clusters/homelab/](./clusters/homelab/).

MetalLB and Flux both require some extra steps for the initial installation.

## Previous Lab Setup

The current revamp of my lab is my fourth major revision to my home lab. My previous setup (version 3.x) consisted the following hardware and software:

**Virtual Machine Server**

- Dell PowerEdge R900
  - XenServer 6.x
  - 4x Intel Xeon E7330 CPUs (16 cores @ 2.4GHz)
  - 24GB of memory
  - 2x 73GB 10k RPM SAS drives in RAID 1

This was a natural migration for me as I was using Xen in my previous lab. Using XenServer came with some drawbacks including the need to run the XenCenter management application on a Windows VM. This system had multiple gigabit NICs, but only one was used.

**Network Attached Storage**

- Supermicro SC826 2U chassis with SAS-826A backplane
  - FreeNAS 11.1
  - 2x Intel Xeon L5620 CPUs (8 cores @ 2.13GHz)
  - 24GB of memory
  - 32GB M.2 SATA SSD (boot drive)
  - SAS-826A backplane
  - 2x Seagate ST6000NM0034 6TB 7200 RPM SAS drives in ZFS mirror

**Network Gateway**

- INFOBLOX-550-A
  - Sophos UTM 9.6
  - Intel Celeron @ 2.93GHz
  - 2GB of memory
  - SanDisk SDSSDA120G 120GB SSD SATA drive

I picked this up for $25 on eBay a few years ago and decided to use it as my gateway. It is just a small Supermicro motherboard, but it lacks things like a video-out port making it difficult to use. There was a password on the BIOS that is built into the ROM and can't be reset. The SSD drive was mounted with double-sided tape inside the chassis.

**Network Switch**

- HP ProCurve J9021A 2810-24G
  - 24 gigabit ports

This switch supports VLAN assignments, SSH, and some other features. It might stick around in the new lab for a while.

**Wireless Access Points**

- 2x Ubiquiti Networks UniFI UAP
  - 802.11 b/g/n 2.4GHz
  - 2x2 MIMO
  - PoE Powered (UniFi 24V)
