#!/bin/bash
#BASE shell script 'module' for Debian.
#Sets up BASE for Autosnort 

########################################
#logging setup: Stack Exchange made this.

base_logfile=/var/log/base_install.log
mkfifo ${base_logfile}.pipe
tee < ${base_logfile}.pipe $base_logfile &
exec &> ${base_logfile}.pipe
rm ${base_logfile}.pipe

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
#grab packages for BASE, and supresses the notification for libphp-adodb. Most of the primary required packages are pulled by  the main AS script.

print_status "Grabbing packages required for BASE."

echo libphp-adodb  libphp-adodb/pathmove note | debconf-set-selections
apt-get install -y libphp-adodb ca-certificates php-pear libwww-perl php5 php5-mysql php5-gd &>> $base_logfile
if [ $? != 0 ];then
	print_error "Failed to acquire required packages for Base. See $base_logfile for details."
	exit 1
else
	print_good "Successfully acquired packages."
fi

########################################

#These are php-pear config commands Seen in the 2.9.4.0 install guide for Debian.

print_status "Configuring php via php-pear."

pear config-set preferred_state alpha &>> $base_logfile
pear channel-update pear.php.net &>> $base_logfile
pear install --alldeps Image_Color Image_Canvas Image_Graph &>> $base_logfile
if [ $? != 0 ];then
	print_error "Failed to acquire required packages for Base. See $base_logfile for details."
	exit 1
else
	print_good "Successfully acquired packages via pear install."
fi

print_good "Successfully configured php via php-pear."

#Have to adjust PHP logging otherwise BASE will barf on startup.

print_status "Reconfiguring php error reporting for BASE."
sed -i 's/error_reporting \= E_ALL \& ~E_DEPRECATED/error_reporting \= E_ALL \& ~E_NOTICE/' /etc/php5/apache2/php.ini

########################################

#The BASE tarball creates a directory for us, all we need to do is move to webroot.

print_status "Installing BASE."

cd /var/www/

# We need to grab BASE from sourceforge. If this fails, we exit the script with a status of 1
# A check is built into the main script to verify this script exits cleanly. If it doesn't,
# The user should be informed and brought back to the main interface selection menu.

print_status "Grabbing BASE via Sourceforge."

wget http://sourceforge.net/projects/secureideas/files/BASE/base-1.4.5/base-1.4.5.tar.gz -O base-1.4.5.tar.gz &>> $base_logfile
 
if [ $? != 0 ];then
	print_error "Attempt to pull down BASE failed. See $base_logfile for details."
	exit 1
else
	print_good "Successfully downloaded the BASE tarball."
fi

tar -xzvf base-1.4.5.tar.gz &>> $base_logfile
if [ $? != 0 ];then
	print_error "Attempt to install BASE has failed. See $base_logfile for details."
	exit 1
else
	print_good "Successfully installed base to /var/www/base."
fi

rm base-1.4.5.tar.gz
mv base-* base

print_status "Resetting default site DocumentRoot to /var/www/base."
sed -i 's/DocumentRoot \/var\/www/DocumentRoot \/var\/www\/base/' /etc/apache2/sites-available/default

#BASE requires the /var/www/ directory to be owned by www-data
print_status "Granting ownership of /var/www to www-data user and group."
chown -R www-data:www-data /var/www

print_notification "The log file for this interface installation is located at: $base_logfile"

exit 0