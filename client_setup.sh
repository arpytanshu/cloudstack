#!/bin/bash

# Script to setup cloudstack management node.
# Tested version Cloudstack __version__ and Centos __version__
#
# Copyright @ Alok Anand <alok4nand@gmail.com>
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
