#!/bin/bash
set -ex
# Script to setup cloudstack management node.
# Tested version Cloudstack __version__ and Centos __version__
#
# Copyright @ Arpitanshu <arpytanshu@gmail.com>


# TODO:
# 2. run run mysql-secure-installation after setup"
# 3. Make a funtion to check if all the cloudstack dependencies are installed.
# 4. Make a function to check if a status of a running service

# VARIABLES [machine IP & Hostname must be changed]
centos_version=6.8          #centos release
cs_version=4.9              #cloudstack version
machine_ip=192.168.0.101    #IP of the machine running this script
machine_hostname=host1      #hostname of the machine running thi script
domain_name=cloud.priv


##This function would check if a package is correctly installed by yum
#Usage: if isinstalled $package; then echo "installed"; else echo "not installed"; fi
function isinstalled {
  if yum list installed "$@" >/dev/null 2>&1; then
    true
  else
    false
  fi
}


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
# add repositories
#1. mysql-connector
#2. cloudstack
#############################

#add mysql-connector repository
if [ ! -f /etc/yum.repos.d/mysql.repo ]; then
    touch /etc/yum.repos.d/mysql.repo
echo "[mysql-connectors-community]
name=MySQL Community connectors
baseurl=http://repo.mysql.com/yum/mysql-connectors-community/el/\$releasever/\$basearch/
enabled=1
gpgcheck=1" > /etc/yum.repos.d/mysql.repo
fi

echo "[INFO] Added mysql-connector repo."

#import gpg keys from MySQL
rpm --import http://repo.mysql.com/RPM-GPG-KEY-mysql

#add cloudstack repository
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

yum -y install ntp mysql-server nfs-utils mysql-connector net-tools cloudstack-management

#check if packages are correctly installed by yum
#if isinstalled "ntp"; then
#    echo "[OK] package successfully installed.";
#else echo "[DEBUG] some error occured. package not successfully installed."
#fi

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

###########################
# Configure mysql for cloudstack
##########################
if [ ! -f /etc/my.cnf.backup ]; then
cp /etc/my.cnf /etc/my.cnf.backup # backup file if not already backup up
fi

sed -i "/\[mysqld\]/a binlog-format = \'ROW\'" /etc/my.cnf
sed -i '/\[mysqld\]/a log-bin=mysql-bin' /etc/my.cnf
sed -i '/\[mysqld\]/a max_connections=350' /etc/my.cnf
sed -i '/\[mysqld\]/a innodb_lock_wait_timeout=600' /etc/my.cnf
sed -i '/\[mysqld\]/a innodb_rollback_on_timeout=1' /etc/my.cnf

echo "[INFO] mysql optiions added to /etc/my.cnf"

service mysqld start
echo "[INFO] mysqld service started"

chkconfig mysqld on
if chkconfig --list | grep -w mysqld > /dev/null;
  then echo "[OK] mysqld present in chkconfig --list";
else echo "[DEBUG] mysqld NOT present in chkconfig --list."
fi

echo "[INFO] *** run mysql-secure-installation after setup ***"
echo "[INFO] All answers maybe answered ‘yes’"






##############################
# setup the databases on management server
##############################
cloudstack-setup-databases cloud:retrolabz@localhost --deploy-as=root:password
echo "[INFO] cloudstack databases set-up."
cloudstack-setup-management
echo "[INFO] cloudstack management setup done."




#############################
# setup nfs server on management
#############################


# make directory for primary and secondary storages on /export/[here]
mkdir -p /export/secondary
mkdir -p /export/primary

echo "/export *(rw,async,no_root_squash,no_subtree_check)" >> /etc/export
exportfs -a

#edit /etc/sysconfig/nfs
if [ -f /etc/sysconfig/nfs ]; then
  echo "LOCKD_TCPPORT=32803
LOCKD_UDPPORT=32769
MOUNTD_PORT=892
RQUOTAD_PORT=875
STATD_PORT=662
STATD_OUTGOING_PORT=2020" >> /etc/sysconfig/nfs
fi

#add entries in iptables for nfs
if [ ! -f /etc/sysconfig/iptables.backup ]; then
cp /etc/sysconfig/iptables /etc/sysconfig/iptables.backup # backup file if not already backup up
fi

if [ -f /etc/sysconfig/iptables ]; then
  sed -i '$ i\-A INPUT -s 192.168.0.0/24 -m state --state NEW -p udp --dport 111 -j ACCEPT' /etc/sysconfig/iptables
  sed -i '$ i\-A INPUT -s 192.168.0.0/24 -m state --state NEW -p tcp --dport 111 -j ACCEPT' /etc/sysconfig/iptables
  sed -i '$ i\-A INPUT -s 192.168.0.0/24 -m state --state NEW -p tcp --dport 2049 -j ACCEPT' /etc/sysconfig/iptables
  sed -i '$ i\-A INPUT -s 192.168.0.0/24 -m state --state NEW -p tcp --dport 32803 -j ACCEPT' /etc/sysconfig/iptables
  sed -i '$ i\-A INPUT -s 192.168.0.0/24 -m state --state NEW -p udp --dport 32769 -j ACCEPT' /etc/sysconfig/iptables
  sed -i '$ i\-A INPUT -s 192.168.0.0/24 -m state --state NEW -p tcp --dport 892 -j ACCEPT' /etc/sysconfig/iptables
  sed -i '$ i\-A INPUT -s 192.168.0.0/24 -m state --state NEW -p udp --dport 892 -j ACCEPT' /etc/sysconfig/iptables
  sed -i '$ i\-A INPUT -s 192.168.0.0/24 -m state --state NEW -p tcp --dport 875 -j ACCEPT' /etc/sysconfig/iptables
  sed -i '$ i\-A INPUT -s 192.168.0.0/24 -m state --state NEW -p udp --dport 875 -j ACCEPT' /etc/sysconfig/iptables
  sed -i '$ i\-A INPUT -s 192.168.0.0/24 -m state --state NEW -p tcp --dport 662 -j ACCEPT' /etc/sysconfig/iptables
  sed -i '$ i\-A INPUT -s 192.168.0.0/24 -m state --state NEW -p udp --dport 662 -j ACCEPT' /etc/sysconfig/iptables
fi

#save and restart iptables services
service iptables restart
service iptables save
echo "[INFO] Iptables entries added & saved for nfs."

if [ ! -f /etc/idmapd.conf.backup ];then
cp /etc/idmapd.conf /etc/idmapd.conf.backup
fi
sed -i "/Domain/c\Domain = $domain_name" /etc/idmapd.conf




###################
# prepare systemvm templates
###################

echo "[INFO] downloading and extracting the systemVM template to /etc/export"
/usr/share/cloudstack-common/scripts/storage/secondary/cloud-install-sys-tmplt \
-m /export/secondary/ \
-u http://cloudstack.apt-get.eu/systemvm/4.6/systemvm64template-4.6.0-kvm.qcow2.bz2 -h kvm

echo "[DONE]"
