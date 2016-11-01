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

if ! grep -q restart_vti.sh /etc/crontab 
then
echo "*/10 * * * * root /etc/strongswan/restart_vti.sh > /tmp/restart_vti.log 2>& 1" >> /etc/crontab
    echo "Restart check every 10 minutes added"
else
    echo "Restarts are already in place"
fi
