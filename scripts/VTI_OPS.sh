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
# Add / delete / enable / disablei VTI
#
# usage - $0 [-e etc] [-d directory] [-reload] {-status|-list|-add|-delete|-enable|-disable} LIST 
#
# ENABLE | DISABLE - we move vtiN.conf from/to /etc/strongswan/vti.d/.DISABLED
# ADD|DELETE - we create or update config files.
# -e - where /etc is (default /etc)
# -d - where directory with properties is (default WORK/<hostname>.d
# -reload - reload strongswan after operation
# -nobgp - do not generate record in bgpd.conf
#
error() {
	echo "$*"
	echo "Usage: $0 [-e </etc>] [-d <DIR>] [-noreload] [-nobgp] {-add|-delete|-enable|-disable} vti1 ...
   $0 [-e </etc>] p-d <dir>] -status|-list [vtiN]"
	exit 1
}

ETC=/etc
HOST=`hostname -s`
DIR=WORK/$HOST.d
OP=
QUIET=
#
nosrv=0
nobgp=0

while [[ "$OP" == "" ]]
do
case $1 in
-e) 
	shift
	ETC=$1
	shift
	;;
-d)
	shift
	DIR=$1
	shift
	;;
-noreload)	
	nosrv=1
	shift
	;;
-nobgp)
	nobgp=1
	shift
	;;
-add|-delete|-enable|-disable|-list|-status)
	OP=$1
	shift
	;;
*)
	error "Unknown option $1"
	;;
esac
done
VDIR=$ETC/strongswan/vti.d

#
# Verify directories
#
test -d $ETC/quagga || error "Error: No $ETC/quagga directory"
test -d $ETC/strongswan/vti.d || error "No $ETC/strongswan/vti.d directory"
test -d $DIR || mkdir -p $DIR
#
if [[ -f $ETC/sysconfig/$HOST.properties ]]
then
	. $ETC/sysconfig/$HOST.properties
else
	echo "Warning: no $ETC/sysconfig/$HOST.properties file"
	echo "It is created when you run INITIAL_SETUP.sh script"
	echo "Not a problem but we can not verify some information"
fi
#
cnt=0
case $OP in
-list)
	echo "Active: `cd $VDIR && echo *.conf | sed 's/.conf//g'`" 
	echo "Disabled: `cd $VDIR/.DISABLED && echo *.conf | sed 's/.conf//g'`" 
	echo "Available: `cd $DIR && echo *.properties | sed 's/.properties//g'`"
	exit 0
	;;
-status)
	if [ "$1" != "" ]
	then
		for v in $*
		do
		(
	        swanctl -list-sas;
        	ifconfig | grep vti
        	netstat -rn | grep vti
		) | grep $v
		done
	else
		swanctl -list-sas;
		ifconfig | grep vti
		netstat -rn | grep vti
	fi
	exit 0
	;;
-disable)
	for i in $*
	do
		if [[ -f $VDIR/$i.conf ]]
		then
			conn=`grep '^conn' $VDIR/$i.conf | awk '{print $2}'`
			mkdir -p $VDIR/.DISABLED
			mv -f $VDIR/$i.conf $VDIR/.DISABLED
			strongswan reload
			sleep 5
			strongswan down $conn
			ifconfig $i down
			echo $i disabled
			(( cnt++ ))
		else
			echo "$i not active so can not disable"
		fi
	done
	;;
-enable)
	for i in $*
	do
		if [[ -f $VDIR/.DISABLED/$i.conf ]]
		then
			mv -f $VDIR/.DISABLED/$i.conf $VDIR/
			echo $i enabled
			strongswan reload
			sleep 5
			conn=`grep '^conn' $VDIR/$i.conf | awk '{print $2}'`
			strongswan up $conn
			(( cnt++ ))
		else
			echo "$i not disabled so can not enable"
		fi	
	done
	;;
-add)
	#
	# Check all interfaces. We do not want to run partial operations
	#
	for v in $*
	do
   	    test -r $DIR/$v.properties || error "Error: no $DIR/$v.properties; use VTI_ADD.sh or VTI_ADDAWS.sh to create it"
	    test -f $VDIR/$v.conf && error "$VDIR/$v.conf exists, delete $v first"
	    test -f $VDIR/.DISABLED/$v.conf && error "$VDIR/.DISABLED/$v.conf exists, delete $v first"
	done
	for v in $*
	do
	(
	    . $DIR/$v.properties || error "Can not read properties $DIR/$v.properties"
	    rsync -a $DIR/$v.properties ~/scripts/WORK/`hostname -s`.d/.
	    if [[ "$LOCAL_GW" == "" && "$EXT_GW" != "" ]]
	    then
		LOCAL_GW=$EXT_GW
	        echo "Used $EXT_GW as LOCAL_GW"
	    fi
	    for i in VTI_OIP_LOCAL VTI_OIP_REMOTE VTI_PSK VTI_IIP_LOCAL VTI_IIP_REMOTE LOCAL_GW
	    do
		eval "[ -z \"\$$i\" ]		&& error \"Could not extract $i from \$DIR/$v.properties.\""
	    done
	    conn=$v
	    if [[ "$ID" != "" ]]
	    then
                conn=$v.$ID
            fi
	    echo "1. Creating $VDIR/$v.init, $v.secret, $v.conf"
	    cat > $VDIR/$v.init <<EOF
# Created `date`
# $ID
# $AWS_ID
VTI_INTERFACE=$v
VTI_LOCALADDR=$VTI_IIP_LOCAL
VTI_REMOTEADDR=$VTI_IIP_REMOTE
VTI_MTU=$VTI_MTU
VTI_UP="/etc/quagga/reset_vti.sh $v"
VTI_DOWN="/etc/quagga/reset_vti.sh $v"
EOF
	echo "$VTI_OIP_LOCAL $VTI_OIP_REMOTE : PSK $VTI_PSK" > $VDIR/$v.secrets
	cat > $VDIR/.DISABLED/$v.conf <<EOF
#BEGIN:$v
conn $conn
        left=$VTI_OIP_LOCAL
        right=$VTI_OIP_REMOTE
        auto=start
        mark=$VTI_MARK
	forceencaps=yes
	$VTI_O1
        $VTI_O2
	$VTI_O3
	$VTI_O4
	$VTI_O5
	$VTI_O6
#END:$v
EOF
	
	#
	# 2. Add external routing
        #
	echo "quagga: Adding ip route $VTI_OIP_REMOTE/32 $LOCAL_GW"
        vtysh <<EOF
	conf t
		ip route $VTI_OIP_REMOTE/32 $LOCAL_GW
		exit
	write mem
EOF
	#
	# Adding record into bgpd.conf IF BGP is specified.
	#
	if [[ "$VTI_BGP_REMOTE_AS" != "" && "$nobgp" != "1" ]]
	then
		bgp=`grep -i 'router bgp' $ETC/quagga/bgpd.conf | head -1 | awk '{print $3}'`
		if [[ "$bgp" != "" && "$bgp" != "$VTI_BGP_LOCAL_AS" ]]
		then
			echo "Attention - different BGP as numbers, $bgp != $VTI_BGP_LOCAL_AS"
                fi
                bo=""
		echo "quagga: Adding neighbor $VTI_BGP_REMOTE_IP remote-as $VTI_BGP_REMOTE_AS route map from_aws"
		( cat <<EOF
		conf t
			router bgp $bgp
				neighbor $VTI_BGP_REMOTE_IP remote-as $VTI_BGP_REMOTE_AS
				neighbor $VTI_BGP_REMOTE_IP local-as $VTI_BGP_LOCAL_AS
EOF
		for bo in "$VTI_BGP1" "$VTI_BGP2" "$VTI_BGP3" "$VTI_BGP4" "$VTI_BGP5"
		do
			if [[ "$bo" != "" ]]
			then
				echo "	neighbor $VTI_BGP_REMOTE_IP $bo"
			fi
		done
		cat <<EOF
				exit
			exit
		write mem
EOF
		) | vtysh
	fi
	# end BGP
	strongswan rereadall
	echo "***INFO: $v created as DISABLED, run $0 -enable $v to activate"
	echo "***INFO: You may wish to edit $VDIR/$v.init and $VDIR/.DISABLED/$v.conf first"
    )
    done
    ;;
-delete)
	for v in $*
	do
	(
	    if [[ -f $VDIR/$v.conf ]]
            then
	        echo "***ERROR: $v active. DISABLE IT FIRST."
		continue
	    fi
	    . $DIR/$v.properties
	    rm -f  $VDIR/$v.secrets $VDIR/$v.conf $VDIR/.DISABLED/$v.conf $VDIR/$v.conf
	    vtysh <<EOF
	    conf t
	    	no ip route $VTI_OIP_REMOTE/32 $LOCAL_GW
	    	exit
	    write mem
EOF
	    if [[ "$VTI_BGP_REMOTE_AS" != "" && "$nobgp" != "1"  ]]
	    then
         	bgp=`grep -i 'router bgp' $ETC/quagga/bgpd.conf | head -1 | awk '{print $3}'`
	        vtysh <<EOF
		conf t
			router bgp $bgp
				no neighbor $VTI_BGP_REMOTE_IP remote-as $VTI_BGP_REMOTE_AS
				no neighbor $VTI_BGP_REMOTE_IP local-as $VTI_BGP_LOCAL_AS
				exit
                	exit
		write mem
EOF
	    ip tunnel del $v
	    fi
	)
        done
        cnt=1
	;;
*)
	error "Unknown command $OP"
	;;
esac
if [[ $cnt != 0 ]]
then
    if [[ $nosrv != 1 ]]
    then
	strongswan rereadsecrets
	sleep 4
        strongswan reload
	#systemctl force-reload strongswan
    else
	echo "Check new config and run 
	strongswan rereadall
	strongswan reload
	# systemctl force-reload strongswan"
    fi
else
    echo "No changes"
fi




