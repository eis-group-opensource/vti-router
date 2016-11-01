# AWS VPC Hardware VPN Strongswan updown Script
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

LOG=/tmp/vti-`echo ${PLUTO_CONNECTION} | sed 's/\..*$//'`.log
(
echo "*** `date` $0 $*"
set -x
#
# We use only part before . in CONN name to find out init file
#
NAME=`echo ${PLUTO_CONNECTION} | sed 's/\..*$//'`
if [[ -f /etc/strongswan/vti.d/${NAME}.init ]]
then
	exist=1
	. /etc/strongswan/vti.d/${NAME}.init 
else
	exist=0
	VTI_INTERFACE=$NAME
fi
if [ "$VTI_INTERFACE" == "" ]
then
	echo "No $VTI_INTERFACE defined"
	exit 1
fi
#    VTI_INTERFACE
#    VTI_LOCALADDR
#    VTI_REMOTEADDR
#    VTI_MTU 
#    VTI_UP= 
#    VTI_DOWN=
#    AWS_ID= 
if [ "$VTI_MTU" = "" ]
then
    VTI_MTU=1420
fi

if [ "$VTI_UP" = "" ]
then
	VTI_UP="/etc/quagga/reset_vti.sh $NAME"
fi

if [ "$VTI_DOWN" = "" ]
then
	VTI_DOWN=""
fi

#
# Usage Instructions:
# Add "install_routes = no" to /etc/strongswan/strongswan.d/charon.conf or /etc/strongswan.d/charon.conf
# Add "install_virtual_ip = no" to /etc/strongswan/strongswan.d/charon.conf or /etc/strongswan.d/charon.conf
# For Ubuntu: Add "leftupdown=/etc/strongswan.d/ipsec-vti.sh" to /etc/ipsec.conf
# For RHEL/Centos: Add "leftupdown=/etc/strongswan/ipsec-vti.sh" to /etc/strongswan/ipsec.conf
# For RHEL/Centos 6 and below: git clone git://git.kernel.org/pub/scm/linux/kernel/git/shemminger/iproute2.git && cd iproute2 && make && cp ./ip/ip /usr/local/sbin/ip
IP=$(which ip)
IPTABLES=$(which iptables)

PLUTO_MARK_OUT_ARR=(${PLUTO_MARK_OUT//// })
PLUTO_MARK_IN_ARR=(${PLUTO_MARK_IN//// })
echo "`date` ${PLUTO_VERB} $VTI_INTERFACE" >> /tmp/vtitrace.log

case "${PLUTO_VERB}" in
    up-client)
       	$IP tunnel add ${VTI_INTERFACE} mode vti local ${PLUTO_ME} remote ${PLUTO_PEER} okey ${PLUTO_MARK_OUT_ARR[0]} ikey ${PLUTO_MARK_IN_ARR[0]}
        sysctl -w net.ipv4.conf.${VTI_INTERFACE}.disable_policy=1
        sysctl -w net.ipv4.conf.${VTI_INTERFACE}.rp_filter=2 || sysctl -w net.ipv4.conf.${VTI_INTERFACE}.rp_filter=0
        $IP addr add ${VTI_LOCALADDR} remote ${VTI_REMOTEADDR} dev ${VTI_INTERFACE}
        $IP link set ${VTI_INTERFACE} up mtu $VTI_MTU
        $IPTABLES -t mangle -I FORWARD -o ${VTI_INTERFACE} -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
        $IPTABLES -t mangle -I INPUT -p esp -s ${PLUTO_PEER} -d ${PLUTO_ME} -j MARK --set-xmark ${PLUTO_MARK_IN}
        $IP route flush table 220
        #
        eval $VTI_UP
        ;;
    down-client)
	if [[ $exist == 0 ]]
	then
        	$IP tunnel del ${VTI_INTERFACE}
	else
		echo $IP link set ${VTI_INTERFACE} down mtu $VTI_MTU	
	fi       
 	$IPTABLES -t mangle -D FORWARD -o ${VTI_INTERFACE} -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
        $IPTABLES -t mangle -D INPUT -p esp -s ${PLUTO_PEER} -d ${PLUTO_ME} -j MARK --set-xmark ${PLUTO_MARK_IN}
	#$IP route flush table 220
	eval $VTI_DOWN
        ;;
esac

# Enable IPv4 forwarding
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.eth0.disable_xfrm=1
sysctl -w net.ipv4.conf.eth0.disable_policy=1
date
) > $LOG 2>& 1
