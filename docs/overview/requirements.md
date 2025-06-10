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

The following ports need to be publicly accessible from anywhere (0.0.0.0/0). For a cloud server, please modify the inbound rules.

If you do not need all the chains, please find a required subset by the chain name.

| Chain or Program Name | Protocol and Port Range | Purpose           |
| --------------------- | ----------------------- | ----------------- |
| ELA                   | TCP 20336               | ELA rpc           |
| ELA                   | TCP 20338               | ELA P2P           |
| ELA                   | TCP 20339               | ELA BPoS          |
| ESC-bootnode          | UDP 20630               | ESC bootnode      |    
| ESC-oracle            | TCP 20632               | ESC oracle        |
| ESC                   | TCP 20636               | ESC rpc           |
| ESC                   | TCP+UDP 20638           | ESC P2P           |
| ESC                   | TCP 20639               | ESC BPoS          |
| EID-bootnode          | UDP 20640               | EID bootnode      |
| EID-oracle            | TCP 20642               | EID oracle        |
| EID                   | TCP 20646               | EID rpc           |
| EID                   | TCP+UDP 20648           | EID P2P           |
| EID                   | TCP 20649               | EID BPoS          |
| ECO-bootnode          | UDP 20650               | ECO bootnode      |
| ECO-oracle            | TCP 20652               | ECO oracle        |
| ECO                   | TCP 20656               | ECO rpc           |
| ECO                   | TCP+UDP 20658           | ECO P2P           |
| ECO                   | TCP 20659               | ECO BPoS          |
| Arbiter               | TCP 20536               | Arbiter rpc       |
| Arbiter               | TCP 20538               | Arbiter P2P       |
| Carrier               | UDP 3478                | Carrier P2P       |
| Carrier               | TCP 33445               | Carrier TCP Relay |
| Carrier               | UDP 33445               | Carrier P2P       |
