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
for i in /etc/strongswan/vti.d/vti*.conf
do
 # set -x
 conn=`grep '^conn ' $i | awk '{print $2}'`
 if ! swanctl -list-sas | grep -q $conn 
 then
    swanctl -i -c $conn  >> /tmp/restarts.log &
    echo "Restartig - $conn"
 else
    if swanctl -list-sas | grep $conn | grep -q INSTALLED
    then
    	vti=`echo $conn | sed 's/\..*$//'`
	ip=`ifconfig $vti | sed -n "s/^.*destination //p"`
	n=0
	if [[ "$ip" != "" ]]
	then
		n=`ping -r -n -c 4 -q $ip | grep received | awk '{print $4;}'`
	fi
    	if [[ $n != "0" && $n != "" ]]
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


