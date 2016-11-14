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

# This is APPROXIMATELY what we did to update kernel
# Need to adjust and debug it yet (for example I do not know what 'awk' did and what nano did)
#
#
if [[ ! -f /etc/yum.repos.d/elrepo.repo ]]
then
	rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
	yum install http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
	#nano /etc/yum.repos.d/elrepo.repo
	sed -i /kernel/,/extra/s/enabled=0/enabled=1/ /etc/yum.repos.d/elrepo*
	yum --enablerepo=elrepo-kernel install kernel-ml kernel-ml-devel kernel-ml-headers
	awk -F\' '$1=="menuentry " {print $2}' /etc/grub2.cfg
else
       yum --enablerepo=elrepo-kernel update kernel-ml kernel-ml-devel kernel-ml-headers
fi
awk -F\' '$1=="menuentry " {print $2}' /etc/grub2.cfg
echo "Run grub2-set-default N with proper number for the new kernel"
grub2-set-default 0

