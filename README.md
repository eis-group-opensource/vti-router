# Project Title

VTI IPSEC router with AWS and AZURE compatibility

## Getting Started
This is linux router, compatible with Azure and AWS IPSEC VPN's. 

See DOCS directory, 'Introduction' document. In short, this is Virtual Appliance 
(but we post scripts separately so you can recreate it) which works as a router,
is compatible with IPSEC variant used in both, AWS (Amazon Web Services cloud) and Azure (Microsoft cloud service, for Route based VPN), and called VTI (Virtual Tunnel
Interface) in Cisco world. System can be imported from ovf template, or build manually from CentOS7. Once done, it can run as a router (with OSPF, BGP, static,
and if necessary extra quagga supported routing protocols) and keep IPSEC connections with AWS ior AZURE using BGP (or other) routing.
It is tested with AWS and AZURE in production environment and (with all these scripts and changes we did on standard CentOS7) is very stable (counted as production ready in our environments).
System allows automated parsing of AWS VPN descriptions, or manual VTI descriptioni, and knows AZURE specifics. 

Documentation sources are held on Google Drive to allow easy collaboration 
- https://drive.google.com/drive/u/0/folders/0B4R1SzsWIJVfWm5icWtVTjNJX2s

Ready to use application (CentOS7 with all installed software) is available for download here (root pwd GitHub.2016, change it ASAP once deployed):
- https://drive.google.com/drive/u/0/folders/0B4R1SzsWIJVfLW9ZNzY1clJfTnM

### Prerequisites

See Introduction in DOCS section. In short, you need 2 networks, one DMZ (or INSIDE) and one OUTSIDE, and need private (Vmware) cloud with access to both, OR 
you need Hardware / Virtual Linux CentOS 7, connected to both DMZ (or INSIDE) and OUTSIDE networks. Router do not use OUTSIDE for default routing so it is relatively safe against scans and attacks 
(and do not create a hole into the network, and in addition we recommend using DMZ and not INSIDE network for internal connection).

You need static IP in both networks (maybe, can use DHCP inside). For serious usage, you may need OSPF or BGP (or any quagga compatible) routing protocol inside your DMZ network.

### Ready to run appliance

This project contains 2 parts - scripts and files (here), and Virtual Appliance, ready to run. Appliance moved out of the project file structure to simplify
management.



Future versions can me moved to GigHub using Large Files support, but wil be held in different project (vti-router-images)

### Installing

See installation example in DOCS section in 'Introduction', and see detailed description of the system components in DOCS section in 'Implementation'. 

There are 2 ways to install it:

(1) Import appliance from ovf file into Vmware (or compatible) cloud. Login as a root using password provided with appliance (GitHub.2016 for now). 
Change password. cd to ~/scripts; run initial setup as

  ./INITIAL_SETUP.sh
  
(2) Install Linux CentOS 7 64 bit, with normal set of packages (see RPM-LIST.txt to compare). Extract 'scripts' from this project into /usr/local/scripts 
(you can extract them into other place but, then, you must run INITIAL_SETUP.sh and refresh_scripts.sh from this directory, the very first time). Make sure that 
system has access to Internet, then run
   
   ./update_kernel.sh
   
   (Modify it as required, as something may change in time).
  
  Create symlink ln -s /usr/local/scripts ~/scripts .
  
  Restart, cd /usr/local/scripts; run ./INITIAL_SETUP.sh and select Reinstall option. 
  
  it will reinstall required packages.
  
  
  
 Then follow instructions (Introduction, first of all) - configure quagga according to your network, 
 parse AWS configuration or create tunnel manually, then VTI -add, then VTI -enable, VTI -status, etc...

## Directories
  scripts - VTI system scripts; can be copied as is to /usr/local/scripts
  
  DOCS - local copy of documentation
    

See 'Implementation' document for extra details.

## Contributing

Project includes both, Appliance and Scripts (which are used inside it). I expect that appliance will not change too often (when changed, v01 will be changed to v02 and so on),
but scripts can be keept 'updated' all the time. We can add apliances for different platforms, if they are posted.

Any fixes for the bugs, parsing for the new VPN providers (I added only parser for AWS VPN), compatibility fixes for other cloud providers will be welcome.

Ubuntu version can be interesting (through we do not support Ubuntu in our Linux zoo). Ansible playbook for system set up (up to the scripts deployment) can be useful.


## Versioning

Major.Minor numbers will be used, with extra tags for specific (Ubuntu for example) versions.
We will keep major versions for appliance, and minor for scripts (so scripts 1.20 for example can be always applied on appliance 1.0).


## Authors

* **Alexei Roudnev** - *Initial work* - aprudnev@gmail.com
* **EIS Group open source group** - open-source@eisgroup.com


## License

This project is licensed under the GPL license, and is donated by EIS Group (http://eisgroup.com) to the open source community (as it is based on mostly open source products, 
but contains our code and was carefully tested in different conditions). 


## Acknowledgments

I used this (https://gist.github.com/heri16/2f59d22d1d5980796bfb) document as initial startig point; it was a huge help for us (even if it has only basic changes required for the production support).

## UPDATE - restart_vti.sh adapted for AZURE
We can not ping remote VTI end in azure, so health script restarted good vti tunnels. To fix it,
it now check inbound traffic on interface, and if it exists, do not restart,  even
if it can not ping.

One more update - I find out, that it can freeze in ETSBLISHED (but not INSTALLED) state, so
script now do not try to find out connection state - if it is active, then it test pings and
inbound traffic, and if no any exists for 20 seconds, then reset tunnel.

Ideally it should remember previous state and if no RX apckets come for 10 minutes, ONLY then
restart.

PINGS did not work, because you must explicitly add route to our end of VTI into Azure VNET.

## UPDATE - AZURE connectivity.


Updated VTI_ADD.sh has now AZURE mode (just answer AZURE when it ask about provider), which adds necessary options for VTI (and propose options for BGP). 
It is tested and works with Azure pretty well, aside of azure gateway restart time, which can be up to 1 hour (so be patient when testing).

On positive side, azure BGP reconnection time is about few seconds (compared with 5 minutes in AWS); on negative, they support multihop EBGP only and
routing must be planned carefully, plus their gateway has so long restarting time, that it looks as failure sometimes. 
BGP with their multihop BGP need careful planning, of course.

For azure, use your own local IP with /32 mask, and set up remote IP (on interface) as IP of
their BGP gateway, configure your local IP on AZURE as IP of the tunnel (one you set up here).

This way ping will work for far end of tunnel (as this end is BGP router and for them, your IP is tunnel IP).

AZURE specific options are now:
(They are added as VTI_O1 - VTI_O5):

        ike=aes256-sha1-modp1024

        esp=aes128-sha1,aes256-sha1!

        keyexchange=ike

        ikelifetime=10800s

        keyingtries=%forever

We add bgp multihop and route-map from_azure in, into BGP, too.
You can modify them manually (in propperties file) or when running VTI_ADD.sh
)

restart_vti.sh script improved now - it first kills all frozen swanctl 
as they have a tendency to freeze when something go wrong.

In addition, we added monitoring for /tmp/vtitrace.log 

VTI_OPS.sh (the same as VTI) fixed to use proper method of configuration updates.

## IMAGES
Image version 2 uploaded. You can find images here (in subfolder) - https://drive.google.com/drive/folders/0B4R1SzsWIJVfWm5icWtVTjNJX2s?usp=sharing

## KNOWN BUGS.

1. FIXED - we must use strongswan update instead of reload. Usig reload caused creating a few more CHILD_SA (IPSEC SA) and confuze AZURE

2. FIXED. We now set up rp_filter option = 0 for all vti interfaces and for eth0, 
It is 1 for eth1. So assymmetrical traffic allowed everywhere
except eth1 (to protect against attacks).
IT is done in both ipsec-vti.sh script and by sysctl.d configs (see FILES.d subdirectories)

NOTICE - CentOS7 sort sysctl files by file name, so names started with 01 - 049 run 
before system defaults (which has number 50). So we renamed our configs into 8N .

