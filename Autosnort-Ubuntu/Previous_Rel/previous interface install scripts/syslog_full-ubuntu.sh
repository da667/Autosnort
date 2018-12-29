#!/bin/bash
#rsyslog module
#configures barnyard2 to use syslog full logging format over udp/514

#We take the copy barnyard2.conf and use grep -v to disable mysql by removing that line. We then ask the user what name the want the sensor appear as, and the ip address of the syslog server.

cat /usr/local/snort/etc/barnyard2.conf | grep -v mysql > /root/barnyard2.conf.tmp
sensor_iface=`cat /root/barnyard2.conf.tmp | grep interface | cut -d" " -f3`

read -p "What would you like the sensor's name to appear as?" sensor_name
read -p "What is the ip address of the syslog server? (in x.x.x.x format; e.g. 192.168.1.254)" syslog_server

echo "output log_syslog_full: sensor_name $sensor_name-$sensor_iface, server $syslog_server, protocol udp, port 514, operation_mode complete" >> /root/barnyard2.conf.tmp

cp /root/barnyard2.conf.tmp /usr/local/snort/etc/barnyard2.conf

exit 0