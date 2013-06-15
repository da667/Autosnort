#!/bin/bash
#Aanval shell script 'module'
#Sets up snort report for Autosnort

########################################
#logging setup: Stack Exchange made this.

sreport_logfile=/var/log/sr_install.log
mkfifo ${sreport_logfile}.pipe
tee < ${sreport_logfile}.pipe $sreport_logfile &
exec &> ${sreport_logfile}.pipe
rm ${sreport_logfile}.pipe

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

print_status "Installing packages for Snortreport."

apt-get install -y php5 php5-mysql php5-gd nmap nbtscan &>> $sreport_logfile
if [ $? != 0 ];then
	print_error "Failed to acquire required packages for Snortreport. See $sreport_logfile for details."
	exit 1
else
	print_good "Successfully acquired packages."
fi

########################################

#Grab jpgraph and throw it in /var/www
#Required to display graphs in snort report UI

print_status "Downloading and installing jpgraph."

cd /var/www

wget http://hem.bredband.net/jpgraph/jpgraph-1.27.1.tar.gz &>> $sreport_logfile
if [ $? != 0 ];then
	print_error "Attempt to pull down jpgraph failed. See $sreport_logfile for details."
	exit 1
else
	print_good "Successfully downloaded jpgraph."
fi

print_status "Installing jpgraph."

tar -xzvf jpgraph-1.27.1.tar.gz &>> $sreport_logfile
if [ $? != 0 ];then
	print_error "Attempt to install jpgraph failed. See $sreport_logfile for details."
	exit 1
else
	print_good "Successfully installed jpgraph."
fi

rm -rf jpgraph-1.27.1.tar.gz
mv jpgraph-1.27.1 jpgraph

########################################

#now to install snort report.

print_status "downloading and installing Snortreport."


wget http://www.symmetrixtech.com/ids/snortreport-1.3.3.tar.gz &>> $sreport_logfile
if [ $? != 0 ];then
	print_error "Attempt to pull down Snortreport failed. See $sreport_logfile for details."
	exit 1
else
	print_good "Successfully downloaded Snortreport."
fi

tar -xzvf snortreport-1.3.3.tar.gz &>> $sreport_logfile
if [ $? != 0 ];then
	print_error "Attempt to install Snort Report failed. See $sreport_logfile for details."
	exit 1
else
	print_good "Successfully installed Snort Report."
fi

rm -rf snortreport-1.3.3.tar.gz
mv /var/www/snortreport-1.3.3 /var/www/snortreport

########################################

print_status "Pointing Snortreport to the mysql database."

sed -i 's/YOURPASS/'$MYSQL_PASS_1'/' /var/www/snortreport/srconf.php

print_good "Snortreport successfully configured to talk to mysql database."

########################################

print_status "Resetting default site DocumentRoot to /var/www/snortreport"
sed -i 's/DocumentRoot \/var\/www/DocumentRoot \/var\/www\/snortreport/' /etc/apache2/sites-available/default

print_notification "The log file for this interface installation is located at: $sreport_logfile"

exit 0
