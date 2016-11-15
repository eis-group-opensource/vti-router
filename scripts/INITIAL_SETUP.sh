#!/bin/bash
###################################################
# (c) EIS Group LTD, 2016                         #
# (License) GPL                                   #
# Donated to OpenSource by EIS Group, 2016.       #
# Authors: Alexei Roudnev , Andrey Saveliev       #
#                                                 #
#       open-source@eisgroup.com                  #
#  or   aprudnev@gmail.com                        #
#  URL; http://eisgroup.com                       #
###################################################

#
# Basic setup for EIS VPC/AWS gateway, configures:
# - /etc/sysconfig/network
# - /etc/sysconfig/network-scripts/ifcfg-eth0
# - /etc/sysconfig/network-scripts/ifcfg-eth1
# - /etc/resolv.conf
# - install strongswan and quagga
# - install scripts to parse aws files and add/remove VTI tunnels
# 

script_name="$(readlink -f $0)"
if [[ ! -d FILES.d ]]
then
	echo "Run script from it's directory so it can see FILES.d. ABORTED"
	exit 1
fi

# default values,
domain='net.exigengroup.com'
dnsservers='10.25.168.31 10.23.5.31 192.168.8.24 '
#
LIST="LIST"
# ASK VAR default COMMENT 
ask() {
        var=$1
	LIST="$LIST $var"
	default=$2
	echo "$3"
	echo -n "$1= [$2]_"
	eval read X
	if [ "$X" = "" ]
	then
		eval $var='"$default"'
	else
		eval $var='"$X"'
	fi
}
ask host "`hostname -s`" "Enter short hostname"
if [[ -f /etc/sysconfig/$host.properties ]]
then
   echo "### SAVED PROPERTIES FOUND ***"
   cat /etc/sysconfig/$host.properties
   echo -n "Do you want to reuse them? (y|n) [n]_ "
   read x
   if [[ "$x" = "y" ]]
   then
   echo "Reusing..."
   . /etc/sysconfig/$host.properties
   reuse=1
   fi
fi
if [[ "$reuse" != "1" ]]
then
ask host "$host" "Enter short hostname"
ask domain "net.exigengroup.com" "Enter domain name"
ask IP "" "Enter my INSIDE IP address"
NETMASK=255.255.255.0
GATEWAY=`echo $IP | sed 's/\.[0-9]*$/.1/'`
ask NETMASK "$NETMASK" "Enter netmask for $IP"
ask GATEWAY "$GATEWAY" "Enter gateway for $IP"
ask dnsservers "$dnsservers" "Enter list of DNS servers (IP, space delimited)"
#
ask EXT_IP "" "Enter OUTSIDE IP address"
ask EXT_NETMASK "255.255.255.0" "Enter OUTSIDE IP netmask"
EXT_GW=`echo $EXT_IP | sed 's/[^.]*$/1/'`
ask EXT_GW "$EXT_GW" "Enter OUTSIDE IP Gateway"
ask LOCAL_AS "" "Enter LOCAL AS number, no BGP if empty"
ask OSPF_NETWORKS "" "Enter list of OSPF networks in N.N.N.N/prefix format delimited by spaces"
ask SNMP_COMM "" "SNMP v1/v2 communities (no SNMP if empty)"
fi
ask REINSTALL "n" "Reinstall or install software and system variables? 
(require INTERNET connection)"
ask RESET "y" "Reset IPSEC and quagga configuration files?"
#
if [[ "$RESET" = "y" && ! -d FILES.d/strongswan ]]
then
   echo "RESET not allowed as it required FILES.d/strongswan directory which is absent"
   RESET="n"
fi

#
echo "
*** VERIFY:
HOST $host.$domain
IP: $IP
NETMASK: $NETMASK
GATEWAY: $GATEWAY
EXT_IP:  $EXT_IP
EXT_NETMASK: $EXT_NETMASK
EXT_GW:  $EXT_GW
LOCAL_AS: $LOCAL_AS
OSPF_NETWORKS: $OSPF_NETWORKS
RESET: $RESET
REINSTALL: $REINSTALL
SNMP_COMM: $SNMP_COMM
"
echo -n "^C to abort, ENTER to proceed_"
read x
if [[ "$x" != "" && "$x" != "yes" ]]
then
	echo "ABORTED , try again"
	exit 1
fi
echo -e "WILL PROCEED\n"


#
# update network configuration
#

# centos7 configuration stores hostname in /etc/hostname
echo "$host.$domain" > /etc/hostname
grep NOZEROCONF -q /etc/sysconfig/network || echo NOZEROCONF=yes >> /etc/sysconfig/network

#
cat > /etc/resolv.conf <<EOF
# /etc/resolv.conf
# configured by $script_name script
search $domain net.exigengroup.com exigengroup.com
EOF

for dns in $dnsservers ; do
	echo "nameserver $dns" >> /etc/resolv.conf
done

cat > /etc/sysconfig/network-scripts/ifcfg-eth0 <<EOF
#
# Run $script_name to reconfigure 
#

DEVICE="eth0"
TYPE="Ethernet"
ONBOOT="yes"

IPV6INIT="no"
NM_CONTROLLED="no"
USERCTL="no"

BOOTPROTO="none"
PEERDNS="no"

IPADDR=$IP
NETMASK=$NETMASK
GATEWAY=$GATEWAY
EOF

cat > /etc/sysconfig/network-scripts/ifcfg-eth1 <<EOF
#
# Run $script_name to reconfigure 
#

DEVICE="eth1"
TYPE="Ethernet"
ONBOOT="yes"

IPV6INIT="no"
NM_CONTROLLED="no"
USERCTL="no"

BOOTPROTO="none"
PEERDNS="no"

IPADDR=$EXT_IP
NETMASK=$EXT_NETMASK
EOF


# apply updated network configuration
echo -e '\n*** Applying network coniguration, please update VLAN connection for VM accordingly ***\n'
service network restart

hostname $HOSTNAME
#
if [[ "$reuse" != "1" ]]
then
    echo "Saving /etc/sysconfig/$host.properties"
    cat > /etc/sysconfig/$host.properties <<EOF
# Created `date`
EOF
    for i in $LIST
    do
        eval 'echo '$i'=\"$'$i'\"' >> /etc/sysconfig/$host.properties
    done
fi

if [[ "$REINSTALL" != "n" ]]
then
    yum -y remove libreswan
    yum -y remove firewalld
    yum -y remove monit
    yum -y install net-snmp
    yum -y install --enablerepo=epel strongswan quagga system-config-firewall monit 

    rm -rf /etc/ipsec.d
    rm -f /etc/ipsec.conf
    rm -f /etc/ipsec.secrets
    if [[ `pwd -P` != `cd ~/scripts && pwd -P` ]]
    then
    	rsync -a README* *.sh VTI* FILES.d ~/scripts/
        mkdir -p ~/scripts/WORK
	rsync -a WORK/`hostname -s`.d ~/scripts/WORK/.
        cat > /usr/sbin/VTI <<EOF
#!/bin/bash
cd ~/scripts && . ./VTI_OPS.sh \$*
EOF
	chmod a+rx /usr/sbin/VTI
        grep -q VTI /etc/motd || echo "To manage VTI use VTI command, scripts at ~/scripts" >> /etc/motd
    fi
    #
fi

if [[ "$RESET" = "y" ]]
then
    #
echo " "
echo "Resetting configuration..."
    #
    echo "3.Removing /etc/strongswan/vti.d/*.{conf,init,secrets} /etc/quagga/*.conf"
    rm -rf /etc/strongswan/vti.d /etc/quagga
    echo "4. Copyying files from FILES.d to /etc"
    service zebra stop  
    (cd FILES.d && tar cf - * ) | (cd /etc && tar xf -) 
    chown -R quagga:quagga /etc/quagga
    for i in zebra ospfd bgpd
    do
      systemctl enable $i
      systemctl start $i
      systemctl status $i
    done
    chmod 600 /etc/strongswan/ipsec.secrets
    chmod +x /etc/strongswan/ipsec-vti.sh 
echo "5. Recreating /etc/sysconfig/network-scripts/route-eth1"
cat > /etc/sysconfig/network-scripts/route-eth1 <<EOF
# Created by $0 script `date`
EOF

echo "6. Recreating /etc/sysconfig/iptables"
cat > /etc/sysconfig/iptables <<EOF
# Generated by iptables-save v1.4.21 on Mon Jun 20 20:07:34 2016
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [1738:245262]
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -i eth0 -j ACCEPT
-A INPUT -i tun+ -j ACCEPT
-A INPUT -i vti+ -j ACCEPT
-A INPUT -p ah -j ACCEPT
-A INPUT -p esp -j ACCEPT
-A INPUT -p udp -m state --state NEW -m udp --dport 500 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -p icmp -j ACCEPT
-A FORWARD -i lo -j ACCEPT
-A FORWARD -i eth0 -j ACCEPT
-A FORWARD -i tun+ -j ACCEPT
-A FORWARD -i vti+ -j ACCEPT
-A FORWARD -j REJECT --reject-with icmp-host-prohibited
COMMIT
EOF
echo "7. Enabling iptables, zebra, monit  and strongswan"
systemctl enable iptables
systemctl enable strongswan
systemctl enable zebra
#BLOCKED# systemctl enable monit

fi

if [[ "$OSPF_NETWORKS" != "" ]]
then
echo "8a. Creating /etc/quagga/ospfd.conf"
cat > /tmp/conf.$$ <<EOF
!
conf t
router ospf
EOF
for i in $OSPF_NETWORKS
do
  echo "network $i area 0" >> /tmp/conf.$$
done
cat >> /tmp/conf.$$ <<EOF
exit
exit
wr mem
EOF
echo "Applying: `cat /tmp/conf.$$`"
vtysh < /tmp/conf.$$
rm -f /tmp/conf.$$
echo "8b. Enabling ospfd"
systemctl enable ospfd
fi

if [[ $LOCAL_AS != "" && ! -f /etc/quagga/bgpd.conf ]]
then 
	echo "9a. Creating /etc/quagga/bgpd.conf"
cat > /tmp/conf.$$ <<EOF
conf t
router bgp $LOCAL_AS
  bgp router-id $EXT_IP
exit
wr mem
EOF
echo "Applying: `cat /tmp/conf.$$`"
vtysh < /tmp/conf.$$

         echo "9b. Enabling bgpd"
         systemctl enable bgpd
fi

echo "10. Setting monit"
sed -i 's/set daemon  30/set daemon  5/g' /etc/monitrc
if [[ "$SNMP_COMM" != "" ]]
then
echo 'OPTIONS="-LS0-6d -p /var/run/net-snmp/snmpd.pid"' >> /etc/sysconfig/snmpd
cat > /etc/snmp/snmpd.conf <<EOF
rocommunity $SNMP_COMM
EOF
systemctl enable snmpd
else
systemctl disable snmpd
fi

echo "Now restart router to test that we did it correct way
You MUST have few important adjustments in strongswan, verify them
Must be no - `grep install_virtual_ip /etc/strongswan/strongswan.d/charon.conf | grep -v '#'`
Must be no - `grep install_routes /etc/strongswan/strongswan.d/charon.conf | grep -v '#'`
Must be no - `grep load /etc/strongswan/strongswan.d/charon/farp.conf | grep -v '#'`
"


