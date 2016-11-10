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
# IT wil create property files in WORK/<HOST.d/vti<N>.properties
# Options:
# -d <work directory>
# -r <work directory for reverse tunnel>
#

# Manually enter parameters
# 
LIST=
ask() {
	var=$1
	LIST="$LIST $var"
	default=$2
	echo "Enter $3"
	echo -n "$1= [$2]_"
	eval read X
	if [ "$X" = "" ]
	then
		eval $var='"$default"'
	else if [ "$X" = "#" ]
	     then
	     	eval $var='""'
	     else
		eval $var='"$X"'
	     fi
	fi
}
HOST=`hostname -s`
opt=1
DIR=WORK/$HOST.d
while [[ "$opt" != "0" ]]
do
case $1 in
-d) 
	shift
	DIR=$1
	shift
	;;
-r)
	shift
	RDIR=$1
	shift
	;;
"")	opt=0
	;;
*)
	echo "Usage: $0 [-d directory] [-r reverse-directory]"
	exit 1
	;;
esac
done
echo "Results will be in $DIR"
if [[ "$RDIR" != "" ]]
then
	echo "Results for other end in $RDIR"
fi


# Let's find free vti
i=0

while (( ++i ))
do
   if [ ! -f $DIR/vti$i.properties ]
   then
       break
   fi
done

ask ID "" "Connection name, will be added to connection name in IPSEC
Recommended format: local-gw_remote-gw"
ask N $i "Interface number (1 - 99)"
VTI="vti$N"
# RESET var list as we do not need N here
LIST="ID VTI"

ask VTI_MTU 1420 "MTU of this VTI"
# Find local IPADDR
IP=`sed -n 's/^IPADDR=//p' /etc/sysconfig/network-scripts/ifcfg-eth1`
ask VTI_OIP_LOCAL "$IP" "OUTSIDE IP of tunnel, local"

#
ask VTI_OIP_REMOTE "" "OUTSIDE IP of tunnel, remote (no default)"
#
GW=`echo $VTI_OIP_LOCAL | sed 's/[^.]*$/1/'`
ask LOCAL_GW $GW "Default gateway for $VTI_OIP_REMOTE on local gateway"

if [[ "$RDIR" != "" ]]
then
GW=`echo $VTI_OIP_REMOTE | sed 's/[^.]*$/1/'`
ask REMOTE_GW $GW "Default gateway for $VTI_OIP_LOCAL on remote gateway"
fi

ask VTI_IIP_LOCAL "" "Inside IP of tunnel, local, without /"
VTI_IIP_LOCAL="$VTI_IIP_LOCAL"

ask VTI_IIP_REMOTE "" "Inside IP of tunnel, remote, without /"
VTI_IIP_REMOTE="$VTI_IIP_REMOTE"

ask VTI_IIP_PREFIX "/30" "Netmask prefix with / (/30 means 255.255.255.252, and so on)"
#
ask VTI_PSK "" "Shared Secret"
#
VTI_MARK=`echo $VTI | sed 's/^vti//;s/$/0/'`
VTI_MARK=`bc <<< "obase=8; $VTI_MARK"`
ask VTI_MARK "$VTI_MARK" "MARK for this VTI, must be different on different VTI"

#
ask VTI_PROVIDER ""                     "Enter provider - AZURE, AWS - for pre-configured settings. Enter to use defaults"
case "$VTI_PROVIDER" in 
AZURE)	
	VTI_O1="ike=aes256-sha1-modp1024"
        VTI_O2="esp=aes128-sha1,aes256-sha1!"
        VTI_O3="keyexchange=ike"
        VTI_O4="ikelifetime=10800s"
        VTI_O5="keylife=3600s"
 	VTI_O6="keyingtries=%forever"


	VTI_BGP1="route-map from_azure in"
	VTI_BGP2="ebgp-multihop"
	echo " Added
	VTI_O1=$VTI_O1
	VTI_O2=$VTI_O2
	VTI_O3=$VTI_O3
	VTI_O4=$VTI_O4
	VTI_O5=$VTI_O5
	VTI_O6=$VTI_O6
	VTI_BGP1=$VTI_BGP1
	VTI_BGP2=$VTI_BGP2
	
	You can change them later or ADD extra options."
	;;
AWS)    VTI_BGP1="route-map from_aws in"
	VTI_O1="keyingtries=%forever"
		echo " Added
		VTI_O1=$VTI_O1
		VTI_BGP1=$VTI_BGP1
		
		You can change them later"

	;;
"")	VTI_O1="keyingtries=%forever"
	;;
*)	echo "Unknown provider $VTI_PROVIDER, skipped"
	;;
esac
#
echo "You can add up to 5 connection options in format key=value . No syntax check here."
#
ask VTI_O1 "$VTI_O1" 	 		 "Option 1. Enter # to skip"
ask VTI_O2 "$VTI_O2"                     "Option 2. Enter # to skip"
ask VTI_O3 "$VTI_O3"                     "Option 3. Enter # to skip"
ask VTI_O4 "$VTI_O4"                     "Option 4. Enter # to skip"
ask VTI_O5 "$VTI_O5"                     "Option 5. Enter # to skip"
ask VTI_O5 "$VTI_O6"                     "Option 6. Enter # to skip"


echo "Now enter BGP information if we use it"
ask VTI_BGP_REMOTE_AS "" "Enter AS of remote neighbor (ENTER if no BGP)"
if [ "$VTI_BGP_REMOTE_AS" != "" ]
then
	ask VTI_BGP_LOCAL_AS  "" "Enter AS of our system"
	ask VTI_BGP_REMOTE_IP "$VTI_IIP_REMOTE" "Enter IP of neighbor"
	ask VTI_BGP_LOCAL_IP  "$VTI_IIP_LOCAL" "Enter local IP for BGP"
	#
	#
	#
	echo "You can add up to 5 bgp options  here (they added with neighbor $VTI_BGP_REMOTE_IP). No syntax check here."
	#
	ask VTI_BGP1 "$VTI_BGP1" 	 	     "neighbor $VTI_BGP_REMOTE_IP Option 1. Enter # to skip"
	ask VTI_BGP2 "$VTI_BGP2"                     "neighbor $VTI_BGP_REMOTE_IP Option 2. Enter # to skip"
	ask VTI_BGP3 "$VTI_BGP3"                     "neighbor $VTI_BGP_REMOTE_IP Option 3. Enter # to skip"
	ask VTI_BGP4 "$VTI_BGP4"                     "neighbor $VTI_BGP_REMOTE_IP Option 4. Enter # to skip"
	ask VTI_BGP5 "$VTI_BGP5"                     "neighbor $VTI_BGP_REMOTE_IP Option 5. Enter # to skip"
fi

#
# Now add netmasks
#
VTI_IIP_LOCAL="$VTI_IIP_LOCAL$VTI_IIP_PREFIX"
VTI_IIP_REMOTE="$VTI_IIP_REMOTE$VTI_IIP_PREFIX"
echo "We adjusted addresses as VTI_IIP_LOCAL=$VTI_IIP_LOCAL and VTI_IIP_REMOTE=$VTI_IIP_REMOTE"
#
#
# Create REVERSE properties if requested, first, so we can abort if number is used
#
if [[ "$RDIR" != "" ]]
then
	mkdir -p $RDIR
	if [[ -f $RDIR/$VTI.properties ]]
	then
		echo "File $RDIR/$VTI.properties already exists, can not rewrite it. Aborting"
		exit 1
	fi
	echo "### MANUALLY CREATED `date`" > $RDIR/$VTI.properties
	for i in $LIST
	do
		j=`echo $i | sed 's/LOCAL/LCL/;s/REMOTE/LOCAL/;s/LCL/REMOTE/'`
		eval 'echo '$j'=\"$'$i'\"' >> $RDIR/$VTI.properties
	done
	echo "Created REVERSE properties $RDIR/$VTI.properties"
	cat $RDIR/$VTI.properties
fi

mkdir -p $DIR
echo "### MANUALLY CREATED `date`" > $DIR/$VTI.properties
for i in $LIST
do
eval 'echo '$i'=\"$'$i'\"' >> $DIR/$VTI.properties
done
echo "Created $DIR/$VTI.properties"
cat $DIR/$VTI.properties

	
	




