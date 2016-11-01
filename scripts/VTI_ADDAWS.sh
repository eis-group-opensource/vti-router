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
# Call this from current directory 
#
# IT wil create property files in WORK/<HOST.d/vti<N>.properties or in $DIR/vti<N>.properties
#  Default is WORK/<hostname>.d (will be /etc/sysconfig later)
#

exec 2>&1

error() {
    echo "$@" >&2
    exit 1
}

HOST=`hostname -s`
opt=1
enforce=0
DIR=WORK/$HOST.d
while [[ "$opt" != "0" ]]
do
case $1 in
-d) 
	shift
	DIR=$1
	shift
	;;
-f)
	enforce=1
	shift
	;;
*)	opt=0
	;;
esac
done

echo "Using directory $DIR - you can change it by -d <dir> option"
[ -z "$1" ] && error "Usage: $0 [-d directory] [-f] <generic-config-file-from-amazon.txt> [vti1 [vti2]]"
[ -r "$1" ] || error "Could not read VPN config file $1."

#
# Options after and including ID are optional (but must exist in aws file).
#
VTI1_LIST="VTI1 VTI1_MTU VTI1_OIP_LOCAL VTI1_OIP_REMOTE LOCAL_GW VTI1_IIP_LOCAL VTI1_IIP_REMOTE VTI1_PSK VTI1_MARK ID AWS_ID VTI1_BGP_LOCAL_AS VTI1_BGP_REMOTE_AS VTI1_BGP_LOCAL_IP VTI1_BGP_REMOTE_IP"

VTI2_LIST="VTI2 VTI2_MTU VTI2_OIP_LOCAL VTI2_OIP_REMOTE LOCAL_GW VTI2_IIP_LOCAL VTI2_IIP_REMOTE VTI2_PSK VTI2_MARK ID AWS_ID VTI2_BGP_LOCAL_AS VTI2_BGP_REMOTE_AS VTI2_BGP_LOCAL_IP VTI2_BGP_REMOTE_IP"
VAR_LIST="$VTI1_LIST $VTI2_LIST"


# Local WAN interface
LAN_INT="eth0"
WAN_INT="eth1"

# 
ID=`basename $1 .txt`
 
VTI1="vti1"
VTI2="vti2"
	
# VTI2 can be empty, it means that we do not generate it at all.
if [ "$2" != "" ]
then
VTI1=$2
VTI2=$3
fi

#
# PARSER of AWS config file
#
VTI1_OIP_LOCAL=$(cat $1 |grep -m 1 "\- Customer Gateway" | tail -1 | awk '{print $5}')
VTI1_OIP_REMOTE=$(cat $1 |grep -m 1 "\- Virtual Private Gateway" | tail -1 | awk '{print $6}')
VTI1_IIP_LOCAL=$(cat $1 |grep -m 2 "\- Customer Gateway" | tail -1 | awk '{print $5}')
VTI1_IIP_REMOTE=$(cat $1 |grep -m 2 "\- Virtual Private Gateway" | tail -1 | awk '{print $6}')
VTI2_OIP_LOCAL=$(cat $1 |grep -m 4 "\- Customer Gateway" | tail -1  | awk '{print $5}')
VTI2_OIP_REMOTE=$(cat $1 |grep -m 3 "\- Virtual Private Gateway" | tail -1 | awk '{print $6}')
VTI2_IIP_LOCAL=$(cat $1 |grep -m 5 "\- Customer Gateway" | tail -1 | awk '{print $5}')
VTI2_IIP_REMOTE=$(cat $1 |grep -m 4 "\- Virtual Private Gateway" | tail -1 | awk '{print $6}')
VTI1_PSK=$(cat $1 | grep  -m 1 "\- Pre-Shared Key" | tail -1 | awk '{print $5}')
VTI2_PSK=$(cat $1 | grep  -m 2 "\- Pre-Shared Key" | tail -1 | awk '{print $5}')
VTI1_BGP_LOCAL_AS=$(cat $1 | grep -m 1 'Customer Gateway ASN' | tail -1 |  awk '{print $6}')
VTI1_BGP_REMOTE_AS=$(cat $1 | grep -m 1 'Virtual Private  Gateway ASN' | tail -1 |  awk '{print $7}')
VTI2_BGP_LOCAL_AS=$(cat $1 | grep -m 2 'Customer Gateway ASN' | tail -1 |  awk '{print $6}')
VTI2_BGP_REMOTE_AS=$(cat $1 | grep -m 2 'Virtual Private  Gateway ASN' | tail -1 |  awk '{print $7}')
VTI1_BGP_REMOTE_IP=$(cat $1 | grep -m 1 "Neighbor IP Address" | tail -1 | awk '{print $6}')
VTI2_BGP_REMOTE_IP=$(cat $1 | grep -m 2 "Neighbor IP Address" | tail -1 | awk '{print $6}')
# For easier reverse BGP configuration just in case
VTI1_BGP_LOCAL_IP=$VTI1_IIP_LOCAL
VTI2_BGP_LOCAL_IP=$VTI2_IIP_LOCAL

AWS_ID=$(cat $1 | grep 'Your VPN Connection ID' | awk '{print $6}')
LOCAL_GW=`echo $VTI1_OIP_LOCAL | sed 's/[^.]*$/1/'`
VTI1_MTU=1420
VTI2_MTU=1420
#VTI1_MARK=`echo $VTI1 | sed 's/^vti//;s/$/00/'`
#VTI2_MARK=`echo $VTI2 | sed 's/^vti//;s/$/00/'`
VTI1_MARK_DEC=`echo $VTI1 | sed 's/^vti//;s/$/0/'`
VTI2_MARK_DEC=`echo $VTI2 | sed 's/^vti//;s/$/0/'`
VTI1_MARK=`bc <<< "obase=8; $VTI1_MARK_DEC"`
VTI2_MARK=`bc <<< "obase=8; $VTI2_MARK_DEC"`

# Check weather we got all the values
if [ "$VTI2" != "" ]
then
	list="$VAR_LIST $VTI2_LIST"
else
	list=$VTI1_LIST
fi
#
for i in $list
do
eval "[ -z \"\$$i\" ]		&& error \"Could not extract $i from \$1.\""
done

mkdir -p $DIR
if [[ -f $DIR/$VTI1.properties && ! "$enforce" = "1" ]]
then
    echo "$VTI1 already exists in $DIR, 
    rm $DIR/$VTI1.properties , use -f option,  or specify another vti"
    echo "Aborted"
    exit 1
fi
if grep '"'$VTI1_IIP_LOCAL'"' $DIR/*.properties
then
	if [[ "$enforce" != "1" ]]
	then
		echo "Duplicated IP address $VTI1_IIP_LOCAL found, aborted. You can use -f to override it"
		exit 1
	else
		echo "Warning: $VTI1_IIP_LOCAL address duplicated.. we continue on your own risk..."
		sleep 2
	fi
fi
if grep '"'$VTI2_IIP_LOCAL'"' $DIR/*.properties
then
	if [[ "$enforce" != "1" ]]
	then
		echo "Duplicated IP address $VTI2_IIP_LOCAL found, aborted. You can use -f to override it"
		exit 1
	else
		echo "Warning: $VTI2_IIP_LOCAL address duplicated.. we continue on your own risk..."
		sleep 2
	fi
fi


id=$ID
#
ID="${id}_GW1"
echo "### Generated `date`" > $DIR/$VTI1.properties
for i in $VTI1_LIST
do
if [ "$i" = "ID" ]
then
 echo "#### OPTIONAL " >> $DIR/$VTI1.properties
fi
j=`echo $i | sed 's/VTI[12]/VTI/'`
eval 'echo '$j'=\"$'$i'\"' >> $DIR/$VTI1.properties
done
echo "Created $DIR/$VTI1.properties"

if [ "$VTI2" == "" ]
then
	echo "no vti2 requested, skipping second VPN"
	exit 0
fi
if [[ -f $DIR/$VTI2.properties && ! "$enforce" = "1" ]]
then
  	echo "$VTI2 alredy exists in $DIR, 
        rm $DIR/$VTI2.properties , add -f option, or specify another vti"
   	echo "Aborted"
 	exit 1
fi

ID="${id}_GW2"
echo "### Generated `date`" > $DIR/$VTI2.properties

for i in $VTI2_LIST
do
if [ "$i" = "ID" ]
then
 echo "#### OPTIONAL " >> $DIR/$VTI2.properties
fi
j=`echo $i | sed 's/^VTI[12]/VTI/'`
eval 'echo '$j'=\"$'$i'\"' >> $DIR/$VTI2.properties
done
echo "Created $DIR/$VTI2.properties"



