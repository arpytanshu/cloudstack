#!/bin/bash

# Script to setup cloudstack management node.
# Tested version Cloudstack __version__ and Centos __version__
#
# Copyright @ Arpitanshu <arpytanshu@gmail.com>


# TODO:
# 3. Make a funtion to check if all the cloudstack dependencies are installed.
# 4. Make a function to check if a status of a running service

# VARIABLES [machine IP & Hostname must be changed]
centos_version=6.8          #centos release
cs_version=4.9              #cloudstack version
machine_ip=192.168.0.101    #IP of the machine running this script
machine_hostname=host1      #hostname of the machine running thi script
domain_name=cloud.priv
gateway=192.168.0.1


##########################
# check internet connectivity
##########################
if ping -q -c 1 -W 1 8.8.8.8 >/dev/null; then
  echo "[OK] Internet connectivity is OK";
else
  echo "[WARNING] ***** Check Internet connectivity ***** The script will now exit.";
  exit;
fi

##########################
# set FQDN hostname
##########################

if [ -f /etc/sysconfig/network ]; then
  cp /etc/sysconfig/network /etc/sysconfig/network.backup
  sed -i '/HOSTNAME/d' /etc/sysconfig/network
  echo HOSTNAME=$machine_hostname.$domain_name >> /etc/sysconfig/network
fi

if [ -f /etc/hosts ]; then
    cp /etc/hosts /etc/hosts.backup
    sed -i '/192.168/d' /etc/hosts
    echo $machine_ip    $machine_hostname.$domain_name $machine_hostname >> /etc/hosts
fi

echo "[INFO] FDQN Hostname has been set."

#############################
# add cloudstack repositories
#############################

if [ ! -f /etc/yum.repos.d/cloudstack.repo ]; then
touch /etc/yum.repos.d/cloudstack.repo
echo "[cloudstack]
name=cloudstack
baseurl=http://cloudstack.apt-get.eu/centos/6/$cs_version/
enabled=1
gpgcheck=0" > /etc/yum.repos.d/cloudstack.repo
fi

echo "[INFO] Added cloudstack repo."

##########################
#install dependencies and packages
##########################

yum -y install ntp cloudstack-agent


###########################
# set selinux to be permissive
##########################

setenforce 0
sed -i.backup -e 's/enforcing/permissive/g' /etc/selinux/config
setenforce permissive

echo "[INFO] Selinux policy changed to permissive."


###########################
# Startup NTP at boot
##########################


chkconfig ntpd on
if chkconfig --list | grep -w ntpd > /dev/null;
  then echo "[OK] ntpd present in chkconfig --list";
else echo "[DEBUG] ntpd NOT present in chkconfig --list."
fi
echo "[INFO] service NTPD set to startup at boot."


#########################
# Configure Libvirt
#########################
if [ ! -f /etc/libvirt/libvirtd.conf.backup ]; then
cp /etc/libvirt/libvirtd.conf /etc/libvirt/libvirtd.conf.backup
fi
echo "listen_tls = 0
listen_tcp = 1
tcp_port = \"16509\"
auth_tcp = \"none\"
mdns_adv = 0" >> /etc/libvirt/libvirtd.conf

if [ ! -f /etc/sysconfig/libvirtd.backup ]; then
  cp /etc/sysconfig/libvirtd /etc/sysconfig/libvirtd.backup
fi
sed -i "/LIBVIRTD_ARGS/c\LIBVIRTD_ARGS=\"--listen\"" /etc/sysconfig/libvirtd

#restart libvirt for changes to take effect
service libvirtd restart


#########################
# Configure network bridges
#########################

if [ ! -f /etc/sysconfig/network-scripts/ifcfg-eth0.100 ]; then
  touch /etc/sysconfig/network-scripts/ifcfg-eth0.100
  echo "DEVICE=eth0.100
ONBOOT=yes
HOTPLUG=no
BOOTPROTO=none
TYPE=Ethernet
VLAN=yes
IPADDR=$machine_ip
GATEWAY=$gateway
NETMASK=255.255.255.0" > /etc/sysconfig/network-scripts/ifcfg-eth0.100
echo "[INFO] Added VLAN eth0.100"
fi

if [ ! -f /etc/sysconfig/network-scripts/ifcfg-eth0.200 ]; then
  touch /etc/sysconfig/network-scripts/ifcfg-eth0.200
  echo "DEVICE=eth0.200
ONBOOT=yes
HOTPLUG=no
BOOTPROTO=none
TYPE=Ethernet
VLAN=yes
BRIDGE=cloudbr0" > /etc/sysconfig/network-scripts/ifcfg-eth0.200
echo "[INFO] Added VLAN eth0.200"
fi


if [ ! -f /etc/sysconfig/network-scripts/ifcfg-eth0.300 ]; then
  touch /etc/sysconfig/network-scripts/ifcfg-eth0.300
  echo "DEVICE=eth0.300
ONBOOT=yes
HOTPLUG=no
BOOTPROTO=none
TYPE=Ethernet
VLAN=yes
BRIDGE=cloudbr1" > /etc/sysconfig/network-scripts/ifcfg-eth0.300
echo "[INFO] Added VLAN eth0.300"
fi


if [ ! -f /etc/sysconfig/network-scripts/ifcfg-cloudbr0 ]; then
  touch /etc/sysconfig/network-scripts/ifcfg-cloudbr0
  echo "DEVICE=cloudbr0
TYPE=Bridge
ONBOOT=yes
BOOTPROTO=none
IPV6INIT=no
IPV6_AUTOCONF=no
DELAY=5
STP=yes" > /etc/sysconfig/network-scripts/ifcfg-cloudbr0
echo "[INFO] Added BRIDGE cloudbr0"
fi

if [ ! -f /etc/sysconfig/network-scripts/ifcfg-cloudbr1 ]; then
  touch /etc/sysconfig/network-scripts/ifcfg-cloudbr1
  echo "DEVICE=cloudbr1
TYPE=Bridge
ONBOOT=yes
BOOTPROTO=none
IPV6INIT=no
IPV6_AUTOCONF=no
DELAY=5
STP=yes" > /etc/sysconfig/network-scripts/ifcfg-cloudbr1
echo "[INFO] Added BRIDGE cloudbr1"
fi
