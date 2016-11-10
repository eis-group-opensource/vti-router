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

cp FILES.d/strongswan/*.sh /etc/strongswan/.
cp FILES.d/quagga/*.sh /etc/quagga/.
if [ ! -d /usr/local/scripts ]
then
	(cd ~ && mv scripts /usr/local/. && ln -s /usr/local/scripts .)
fi
cat > /usr/sbin/VTI <<EOF
#!/bin/bash
cd /usr/local/scripts && exec ./VTI_OPS.sh \$*
EOF
rsync -av [A-Z]*.sh FILES.d /usr/local/scripts/.
ln -s /usr/sbin/strongswan /usr/sbin/ipsec
