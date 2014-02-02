#!/bin/bash
#Aanval shell script 'module'
#Sets up snort report for Autosnort
#Updated on 2/1/2014

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

print_status "Installing packages for Snortreport.."

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

print_status "Downloading and installing jpgraph.."

cd /var/www

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
	print_error "Attempt to pull down Snort Report failed. See $sreport_logfile for details."
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
mv /var/www/snortreport-1.3.4 /var/www/snortreport

########################################

print_status "Pointing Snort Report to the mysql database.."

sed -i 's/PASSWORD/'$MYSQL_PASS_1'/' /var/www/snortreport/srconf.php

print_good "Snort Report successfully configured to talk to mysql database."

########################################

# Snort Report is littered with short open tags.
# sed statement 1 removes all short open tags, but breaks some things.
# sed statement 2 fixes some of the things that sed statement 1 mistakenly replaced
# sed statement 3 fixes all instances of <?= that sed statement 1 mistakenly replaced
# end product: no short open tags, no need to turn on the short open tags directive in php.ini


print_status "Fixing short open tags.."

cd /var/www/snortreport

for s_open_file in `ls -1 *.php`; do 
	sed -i 's/<?/<?php/g' $s_open_file
	sed -i 's/<?phpphp/<?php/g' $s_open_file
	sed -i 's/<?php=/<?=/g' $s_open_file
done

print_good "Short open tags fixed."

########################################

#changing access to srconf.php -- the file is world-readable by default. I don't like that. Also, the files here should probably be owned by www-data.

print_status "Setting file ownership for /var/www/snortreport, /var/www/jpgraph to www-data; making srconf.php read-only by www-data user and group.."

chmod 400 /var/www/snortreport/srconf.php

chown -R www-data:www-data /var/www/snortreport
chown -R www-data:www-data /var/www/jpgraph

print_good "File permissions reset."

print_status "Resetting default site DocumentRoot to /var/www/snortreport.."
sed -i 's/DocumentRoot \/var\/www/DocumentRoot \/var\/www\/snortreport/' /etc/apache2/sites-available/*default*

print_notification "The log file for this interface installation is located at: $sreport_logfile"

exit 0
