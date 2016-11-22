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
# Options - -
# 1. Protection against frozen script
# 
list=`ps aux | grep swanctl | grep -v grep | awk '{print $2}'`
if [[ "$list" != "" ]]
then
	echo "Some swanctl processes running, we wait 20 seci then kill them"
	sleep 20
	kill -9 $list  > /dev/null 2>& 1
	sleep 1
fi

# This script check connections which gave up
# and restarts them
# Additionally it restarts dead vti interfaces (it MAY happen sometimes)
#
for i in /etc/strongswan/vti.d/vti*.conf
do
 # set -x
 conn=`grep '^conn ' $i | awk '{print $2}'`
 echo -n "$conn... "
 if ! swanctl -list-sas | grep -q $conn 
 then
    swanctl -i -c $conn  >> /tmp/restarts.log &
    echo "Restarting"
 else
    if swanctl -list-sas | grep -q $conn
    then
    	vti=`echo $conn | sed 's/\..*$//'`
	ip=`ifconfig $vti | sed -n "s/^.*destination //p"`
	#
	# In case of AZURE, remote IP can be not pingable
	# So we compare RX stats in 10 seconds (or while ping try to send pings)
	# If RX is different == there is inbound traffic in interface == it is healthy
	# Else, if no RX traffic and no pings, restart
	before=`ifconfig $vti | grep RX`
	n=0
	if [[ "$ip" != "" ]]
	then
		n=`ping -r -n -c 5 -q $ip | grep received | awk '{print $4;}'`
	        if [[ "$n" = "" ]]
		then
			sleep 10
		fi
	else
		sleep 10
	fi
	after=`ifconfig $vti | grep RX`
    	if [[ "$before" != "$after" ||  $n != "0" && $n != "" ]]
    	then
    		echo OK
    	else
	(
		echo " OK but no vti, resetting... see /tmp/${vti}_up.log"
                echo `date` resetting $conn > /tmp/${vti}_up.log
		strongswan down $conn >> /tmp/${vti}_up.log 2>& 1
		sleep 2
		strongswan up $conn   >> /tmp/${vti}_up.log 2>& 1
		echo DONE $conn
	) &
	fi
    else
	echo IN PROGRESS
    fi
 fi
done
wait


