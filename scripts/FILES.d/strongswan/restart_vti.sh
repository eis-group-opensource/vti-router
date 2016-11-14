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

# This script check conenctions which gave up
# and restarts them
#
(
flock -n 200 || exit 1

for i in /etc/strongswan/vti.d/vti*.conf
do
 # set -x
 conn=`grep '^conn ' $i | awk '{print $2}'`
 if ! swanctl -list-sas | grep -q $conn 
 then
    swanctl -i -c $conn  >> /tmp/restarts.log &
    echo "Restartig - $conn"
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
    		echo $conn OK
    	else
		echo -n $conn OK but no vti, resetting... see /tmp/${vti}_up.log
                strongswan down $conn > /tmp/${vti}_up.log 2>& 1
		strongswan up $conn   > /tmp/${vti}_up.log 2>& 1
		echo DONE
	fi
    else
	echo $conn IN PROGRESS
    fi
 fi
done

) 200>/tmp/restart_vti.lock
