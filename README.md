# Introduction

This Vagrant project creates a VM with single node setup of big data cluster.

# Version Information
The versions of the above components that the VM is provisioned with are defined in the file `scripts/versions.sh`

The version information is as follows:

* Hadoop 2.7.7
* Hive 2.3.4
* Hbase 1.4.8
* Spark 2.0.2
* Scala 2.11.12
* Zookeeper 3.5.7
* Phoenix 4.14.0
* Kafka 2.4.1

# Getting Started

## Vagrant Install

1. [Download and install VirtualBox](https://www.virtualbox.org/wiki/Downloads)
2. [Download and install Vagrant](http://www.vagrantup.com/downloads.html).
3. Git clone this project, and change directory (cd) into this project (directory).
4. Run ```vagrant up``` to create the VM.
5. Run ```vagrant ssh``` to get into your VM.
6. Run ```vagrant destroy``` when you want to destroy and get rid of the VM.

## Vagrant boxes
A list of available Vagrant boxes is shown at http://www.vagrantbox.es.

## Vagrant box location
The Vagrant box is downloaded to the ~/.vagrant.d/boxes directory. On Windows, this is C:/Users/{your-username}/.vagrant.d/boxes.

## Managment of Vagrant VM

To stop the VM and preserve all setup/data within the VM: 

```
vagrant halt
```

or

```
vagrant suspend
```

Issue a `vagrant up` command again to restart the VM from where you left off.

To completely **wipe** the VM so that `vagrant up` command gives you a fresh machine: -

```
vagrant destroy
```

Then issue `vagrant up` command as usual.

# Web UI

Here are some useful links to navigate to various UI's:

* [YARN resource manager](http://hadoop:8088)
* [HBase](http://hadoop:16010)
* [Job history](http://hadoop:19888/jobhistory/)
* [HDFS](http://hadoop:50070/dfshealth.html)
* [Spark history server](http://hadoop:18080)
* [Spark context UI (if a Spark context is running)](http://hadoop:4040)

Substitute the ip address of the container or virtualbox VM for `hadoop` if necessary.

