#!/bin/bash
#rsyslog module
#configures barnyard2 to use syslog full logging format over udp/514

########################################
#Metasploit-like print statements: status, good, bad and notification. Gratouitiously copied from Darkoperator's metasploit install script.

function print_status ()
{
    echo -e "\x1B[01;34m[*]\x1B[0m $1"
}

function print_good ()
{
    echo -e "\x1B[01;32m[*]\x1B[0m $1"
}

function print_error ()
{
    echo -e "\x1B[01;31m[*]\x1B[0m $1"
}

function print_notification ()
{
	echo -e "\x1B[01;33m[*]\x1B[0m $1"
}

########################################
#The config file should be in the same directory that snorby script is exec'd from. This shouldn't fail, but if it does..

execdir=`pwd`
if [ ! -f $execdir/full_autosnort.conf ]; then
	print_error "full_autosnort.conf was NOT found in $execdir. This script relies HEAVILY on this config file. The main autosnort script, full_autosnort.conf and this file should be located in the SAME directory."
	exit 1
else
	source $execdir/full_autosnort.conf
	print_good "Found config file."
fi

########################################
#We take the copy barnyard2.conf and use grep -v to disable mysql by removing that line. We then ask the user what name the want the sensor appear as, and the ip address of the syslog server.

print_status "Reconfiguring barnyard2.conf output plugin to syslog_full.."


grep -v mysql $snort_basedir/etc/barnyard2.conf > /root/barnyard2.conf.tmp
sensor_iface=`grep interface /root/barnyard2.conf.tmp | cut -d" " -f3`

echo "output log_syslog_full: sensor_name $sensor_name-$snort_iface, server $syslog_server, protocol udp, port 514, operation_mode complete" >> /root/barnyard2.conf.tmp

cp /root/barnyard2.conf.tmp $snort_basedir/etc/barnyard2.conf

print_good "Successfully modified /usr/local/snort/etc/barnyard2.conf to output to syslog_full."

exit 0