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
# Call this from current directory 
#
# IT wil create property files in WORK/<HOST.d/vti<N>.properties
# Options:
# -d <work directory>
# -r <work directory for reverse tunnel>
#

# Remove property files# 
LIST=
ask() {
	var=$1
	LIST="$LIST $var"
	default=$2
	echo "Enter $3"
	echo -n "$1= [$2]_"
	eval read X
	if [ "$X" = "" ]
	then
		eval $var='"$default"'
	else
		eval $var='"$X"'
	fi
}
HOST=`hostname -s`
opt=1
DIR=WORK/$HOST.d
while [[ "$opt" != "0" ]]
do
case $1 in
-d) 
	shift
	DIR=$1
	shift
	;;
-r)
	shift
	RDIR=$1
	shift
	;;
*)	opt=0
	;;
esac
done
echo "WORK DIRECTORY is$DIR"
if [[ "$RDIR" != "" ]]
then
	echo "REVERSE WORK DIRECTORY is $RDIR"
fi

for v in $*
do
 if [[ -f $DIR/$v.properties ]]
 then
    rm -f $DIR/$v.properties
    echo "Removed $DIR/$v.properties"
 fi
 if [[ "$RDIR" != "" && -f $RDIR/$v.properties ]]
 then
    rm -f $RDIR/$v.properties
    echo "Removed $RDIR/$v.properties"
 fi
done




	
	




