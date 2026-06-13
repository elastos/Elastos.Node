# Requirements

Generally, a new Linux operation system is required to run an Elastos node.

## User Requirements

This guide is mainly intended for the user who:

* Feels **comfortable with Linux** or similar **POSIX shell environment**
* Has the budget to access a **cloud computing service**: [Amazon EC2](https://aws.amazon.com/ec2/), [Google Cloud Compute Engine](https://cloud.google.com/compute/), [Microsoft Azure VM](https://azure.microsoft.com/en-us/services/virtual-machines/)
* or has space to place a real server

## Public Network Requirements

* Use the **non-metered connection** to prevent a high usage billing
* A Public IP

## Server Hardware Requirements

If you are a **CRC supernode** or install all the components of the Elastos blockchain:

* **CPU**: **8 cores** or more
* **RAM**: **32 GB** or more
* **HDD**: **300 GB** or more
  * A solid-state drive (SSD) is a plus but not a must. A hard drive (HDD) should be OK.
  * Disk usage will always increase because blockchains are growing. You should monitor your disk to ensure it is big enough to hold all the programs.

A single chain may require fewer resources. For example, you only install the mainchain as a verification node.

If you are a **BPoS supernode** or have only ELA nodes installed:

* **CPU**: **4 cores** or more
* **RAM**: **16 GB** or more
* **HDD**: **200 GB** or more

## Server Software Requirements

* **OS**: **Ubuntu 20.04 LTS** 64 Bit (Intel x86\_64) or newer
  * Use **Ubuntu** because the Elastos blockchain developers use macOS and Ubuntu to develop and test. But it is your freedom of choice of other distributions.
  * **LTS** is better because LTS has a longer product life than the **non-LTS** version. (See [Ubuntu Releases](https://wiki.ubuntu.com/Releases))
  * The script prefers a **freshly installed** OS because it reduces conflicts with the old setup. It is time-consuming to debug such conflicts and do the related support work.

## Server Security Rules

Only the peer-to-peer and consensus ports need to be publicly accessible. The RPC, WebSocket, oracle, and arbiter RPC ports bind to `127.0.0.1` (or are firewall-closed) and must stay private. This differs from the upstream runner, which exposed RPC on `0.0.0.0`. See [SECURITY.md](../../SECURITY.md) for the full security model and port table.

The `firewall` command opens the peer/consensus group for the active profile, and `harden` closes the private group. For a cloud server, mirror the same posture in the provider's inbound rules. If you do not need all the chains, find a required subset by the chain name.

Ports to open (peer-to-peer and consensus):

| Chain or Program Name | Protocol and Port Range | Purpose       |
| --------------------- | ----------------------- | ------------- |
| ELA                   | TCP 20338               | ELA P2P       |
| ELA                   | TCP 20339               | ELA BPoS      |
| ESC                   | TCP+UDP 20638           | ESC P2P       |
| ESC                   | TCP 20639               | ESC BPoS      |
| EID                   | TCP+UDP 20648           | EID P2P       |
| EID                   | TCP 20649               | EID BPoS      |
| PG                    | TCP+UDP 20678           | PG P2P        |
| PG                    | TCP 20679               | PG BPoS       |
| Arbiter               | TCP 20538               | Arbiter P2P   |

Ports to keep private (bound to `127.0.0.1` or firewall-closed, never exposed):

| Chain or Program Name | Protocol and Port Range | Purpose       |
| --------------------- | ----------------------- | ------------- |
| ELA                   | TCP 20336               | ELA rpc       |
| ESC-oracle            | TCP 20632               | ESC oracle    |
| ESC                   | TCP 20636               | ESC rpc       |
| EID-oracle            | TCP 20642               | EID oracle    |
| EID                   | TCP 20646               | EID rpc       |
| PG-oracle             | TCP 20672               | PG oracle     |
| PG                    | TCP 20676               | PG rpc        |
| Arbiter               | TCP 20536               | Arbiter rpc   |
