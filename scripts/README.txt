#
# (c) EIS Group LTD, 2016
# (License) GPL
# Donated to OpenSource by EIS Group, 2016.
# Authors: Alexei Roudnev , Sergey Saveliev
# 	
#       open-source@eisgroup.com
#  or   aprudnev@gmail.com
#
# This is quick description of VTI management scripts.
#
This is VTI VPN router, compatible with AWS.

Layouts:

   WORK - work directory

   WORK/<host>.d/vtiN.properties - properti files for Available VTI
   /etc/strongswan - main IPSEC system
   /etc/sysconfig/<host>.properties - host properties

SYSTEM USAGE:

1) SET UP system after cloning or initial setting by running

   ./INITIAL_SETUP.sh
      (You wil have an option to install packages and/or to reset configuration of IPSEC
        and router).

You may want, then, to manually edit /etc/quagga files.

2) Prepare VTI. You have 2 ways
   2.1. Parse AWS file. To do it
    - copy AWS file into WORK directory, better with some meaning name like aws-lab20-1.txt
    - parse it by running ./VTI_ADDAWS.sh [-d work-dir] <aws-file> [vti1 vti2]
     (By default it will make available vti1 and vti2 but if they are used, you can specify
     different names)
   2.2. Manually, by running
       ./VTI_ADD.sh [-d <work directory> [-r <directory for reverse tunnel>]

   (Both commands have options allowing to change work directory

3) Review files (they wil be created in work directory as vtiN.properties)

4) Then you can use VTI_OPS.sh to add|delete disable|enable tunnels and to check status.
   ./VTI_OPS.sh [-e </etc>] [-d <DIR>] [-reload] [-nobgp] {-add|-delete|-enable|-disable} vti1 ...
   ./VTI_OPS.sh [-e </etc>] p-d <dir>] -status|-list

 -e allows to specify differnt /etc
 -reload enable automatic strongswan reload
 -nobgp blocks changes in bgpd.conf even if bgp specified in properties
 

You can enter VTI instedas of '(cd /usr/local/src; ./VTI_OPS.sh).

Normal procedure is:

- copy aws file into /usr/local/scripts/WORK, for example, lab20-aws-1.txt
- Prepare vti
   cd /usr/local/scripts && ./VTI_ADDAWS.sh WORK/lab20-aws-1.txt
- Check files
   cat WORK/`hostname -s`.d/vti*.properties
- Add vti-s
   VTI -list
   VTI -add vti1
   VTI -add vti2
   VTI -list

- Enable this tunnels
   VTI -enable vti1 vti2

- check results
  VTI -status

You can disable tunnel
  VTI -disable vti1

and enable it later
  VTI -enable vti1

Normally, you do not need to restart strongswan and quagga (system reload them smoothly).

VTI is just alias for

 (cd /usr/local/scripts && ./VTI_OPS.sh)

refresh_scripts.sh allows to refresh system scripts from this copy in different place.
update_kernel.sh should update old standard kernel into the strongswan-compatible version.

if you make parsing on teh different place (not /usr/local/scripts), then SYNC_AVAIL.sh script required to make parsed properties to be available for the VTI command.




      

