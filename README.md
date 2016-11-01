# Project Title

VTI IPSEC router with AWS and AZURE compatibility

## Getting Started

See DOCS directory, 'Introduction' document. In short, this is Virtual Appliance 
(but we post scripts separately so you can recreate it) which works as a router,
is compatible with IPSEC variant used in both, AWS (Amazon Web Services cloud) and Azure (Microsoft cloud service, for Route based VPN), and called VTI (Virtual Tunnel
Interface) in Cisco world. System can be imported from ovf template, or build manually from CentOS7. Once done, it can run as a router (with OSPF, BGP, static,
and if necessary extra quagga supported routing protocols) and keep IPSEC connections with AWS (and possible Azure, not tested in this time yet) using BGP (or other) routing.
It is tested with AWS in production environment and (with all these scripts and changes we did on standard CentOS7) is very stable (counted as production ready in our environments).
System allows automated parsing of AWS VPN descriptions, or manual VTI description. 

Documentation sources are held on Google Drive to allow easy collaboration - https://drive.google.com/drive/u/0/folders/0B4R1SzsWIJVfLW9ZNzY1clJfTnM .

### Prerequisites

See Introduction in DOCS section,. In short, you need 2 networks, one DMZ (or INSIDE) and one OUTSIDE, and need private (Vmware) cloud with access to both, OR 
you need Hardware / Virtual Linux CentOS 7, connected to both DMZ (or INSIDE) and OUTSIDE networks. Router do not use OUTSIDE for default routing so it is relatively safe against scans and attacks 
(and do not create a hole into the network, and in addition we recommend using DMZ and not INSIDE network for internal connection).

You need static IP in both networks (maybe, can use DHCP inside). For serious usage, you may need OSPF or BGP (or any quagga compatible) routing protocol inside your DMZ network.

### Ready to run appliance

This project contains 2 parts - scripts and files (here), and Virtual Appliance, ready to run. Appliance moved out of the project file structure to simplify
management.

First appliance version is kept on google drive under this url:

https://drive.google.com/drive/u/0/folders/0B4R1SzsWIJVfLW9ZNzY1clJfTnM

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
  
  Restart, cd /usr/local/scripts; run ./INITIAL_SETUP.sh and select Reinstall option. 
  
  it will reinstall required packages.
  
  
  
 Then follow instructions (Introduction, first of all) - configure quagga according to your network, 
 parse AWS configuration or create tunnel manually, then VTI -add, then VTI -enable, VTI -status, etc...

## Directories
  scripts - VTI system scripts; can be copied as is to /usr/local/scripts
  DOCS - local copy of documentation, sources at https://drive.google.com/drive/u/0/folders/0B4R1SzsWIJVfWm5icWtVTjNJX2s
  OVF files can be downloaded from https://drive.google.com/drive/u/0/folders/0B4R1SzsWIJVfWm5icWtVTjNJX2s (see VTI-ROUTER-V01 folder).

## Contributing

Project includes both, Appliance and Scripts (which are used inside it). I expect that appliance will not change too often (when changed, v01 will be changed to v02 and so on),
but scripts can be keept 'updated' all the time. We can add apliances for different platforms, if they are posted.

Any fixes for the bugs, parsing for the new VPN providers (I added only parser for AWS VPN), compatibility fixes for other cloud providers will be welcome.

Ubuntu version can be interesting (through we do not support Ubuntu in our Linux zoo). Ansible playbook for system set up (up to the scripts deployment) can be useful.


## Versioning

<Major>.<Minor> numbers to be used, with extra tags for specific (Ubuntu for example) versions.
We will keep major versions for appliance, and minor for scripts (so scripts 1.20 for example can be always applied on appliance 1.0).


## Authors

* **Alexei Roudnev** - *Initial work* - aprudnev@gmail.com
* **EIS Group open source group** - open-source@eisgroup.com

I used this (https://gist.github.com/heri16/2f59d22d1d5980796bfb) document as initial startig point; it was a huge help for us (even if it has only basic changes required for the production support).


## License

This project is licensed under the GPL license, and is donated by EIS Group (http://eisgroup.com) to the open source community (as it is based on mostly open source products, 
but contains our code and was carefully tested in different conditions). 


## Acknowledgments


