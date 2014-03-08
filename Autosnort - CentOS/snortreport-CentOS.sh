#!/bin/bash
#Snortreport shell script 'module'
#Sets up snortreport for Autosnort on CentOS Systems
#modified on 08/15. Not yet tested.

########################################
#logging setup: Stack Exchange made this.

sreport_logfile=/var/log/sr_install.log
mkfifo ${sreport_logfile}.pipe
tee < ${sreport_logfile}.pipe $sreport_logfile &
exec &> ${sreport_logfile}.pipe
rm ${sreport_logfile}.pipe

########################################
#Metasploit-like print statements: status, good, bad and notification. Gratuitously copied from Darkoperator's metasploit install script.

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

print_status "Installing packages for Snort Report.."

yum -y install php php-common php-gd php-cli php-mysql &>> $sreport_logfile
if [ $? != 0 ];then
	print_error "Failed to acquire required packages for Snort Report. See $sreport_logfile for details."
	exit 1
else
	print_good "Successfully acquired packages."
fi

########################################

#Grab jpgraph and throw it in /var/www/html
#Required to display graphs in snort report UI

print_status "Downloading and installing jpgraph.."

cd /var/www/html

wget http://jpgraph.net/download/download.php?p=5 -O jpgraph305.tar.gz &>> $sreport_logfile
if [ $? != 0 ];then
	print_error "Attempt to pull down jpgraph failed. See $sreport_logfile for details."
	exit 1
else
	print_good "Successfully downloaded jpgraph."
fi

print_status "Installing jpgraph.."

tar -xzvf jpgraph305.tar.gz &>> $sreport_logfile
if [ $? != 0 ];then
	print_error "Attempt to install jpgraph failed. See $sreport_logfile for details."
	exit 1
else
	print_good "Successfully installed jpgraph."
fi

rm -rf jpgraph305.tar.gz
mv jpgraph-3* jpgraph

########################################

#now to install snort report.

print_status "downloading and installing Snort Report.."


wget http://www.symmetrixtech.com/ids/snortreport-1.3.4.tar.gz &>> $sreport_logfile
if [ $? != 0 ];then
	print_error "Attempt to pull down Snortreport failed. See $sreport_logfile for details."
	exit 1
else
	print_good "Successfully downloaded Snort Report."
fi

tar -xzvf snortreport-1.3.4.tar.gz &>> $sreport_logfile
if [ $? != 0 ];then
	print_error "Attempt to install Snort Report failed. See $sreport_logfile for details."
	exit 1
else
	print_good "Successfully installed Snort Report."
fi

rm -rf snortreport-1.3.4.tar.gz
mv /var/www/html/snortreport-1.3.4 /var/www/html/snortreport

########################################

print_status "Pointing Snortreport to the mysql database.."

sed -i 's/PASSWORD/'$MYSQL_PASS_1'/' /var/www/html/snortreport/srconf.php

print_good "Snort Report successfully configured to talk to mysql database."

########################################

# Snort Report is littered with short open tags.
# As much as I really want to banish them from all OS versions FOREVER,
# Until CentOS or the EPEL repos have PHP 5.4+, I can't do it and here's why:
# If the programmer uses shortcuts like <?, these are easy to fix with sed.
# If <?= is used, that's not as easy to fix. If you know an easy way to automatically replace these lines, let me know.


print_status "Reconfiguring php.ini..."
sed -i 's/short\_open\_tag \= Off/short\_open\_tag \= On/' /etc/php.ini
if [ $? -eq 0 ]; then
	print_good "php.ini successfully reconfigured."
else
	print_error "failed to modify php.ini. Check $sreport_logfile for details."
	exit 1
fi

########################################
#This is to tighten file permissions on Snort Report files, especially srconf.php; it shouldn't be world-readable.

print_status "Setting file ownership for /var/www/html/snortreport, /var/www/html/jpgraph to apache; making srconf.php read-only by apache user and group.."

chown -R apache:apache /var/www/html/snortreport
chown -R apache:apache /var/www/html/jpgraph

chmod 400 /var/www/html/snortreport/srconf.php

print_good "File permissions reset."

########################################

#make a backup of /etc/httpd/conf/httpd.conf before we begin editing it..

cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.orig
print_status "Resetting default site DocumentRoot and Directory Permissions to /var/www/html/snortreport.."
sed -i 's#/var/www/html#/var/www/html/snortreport#g' /etc/httpd/conf/httpd.conf

print_status "Reconfiguring SELinux Permissions to allow httpd r/w access to the snortreport directory.."
chcon -R -t httpd_sys_rw_content_t snortreport/

print_good "SELinux permissions successfully modified."



print_notification "The log file for this interface installation is located at: $sreport_logfile"

exit 0