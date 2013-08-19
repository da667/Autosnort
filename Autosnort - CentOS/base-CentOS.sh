#!/bin/bash
#BASE shell script 'module'
#Sets up BASE for for Autosnort

########################################
#logging setup: Stack Exchange made this.

base_logfile=/var/log/base_install.log
mkfifo ${base_logfile}.pipe
tee < ${base_logfile}.pipe $base_logfile &
exec &> ${base_logfile}.pipe
rm ${base_logfile}.pipe

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
#grab packages for BASE. Most of the other required packages are pulled by the main AS script.

print_status "Grabbing packages required for BASE."

yum -y install php php-common php-gd php-cli php-mysql php-pear.noarch php-adodb.noarch perl-libwww-perl openssl-devel mod_ssl &>> $base_logfile
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
	print_good "Successfully configured php and acquired packages via php pear."
fi

#Have to adjust PHP logging otherwise BASE will barf on startup.

print_status "Reconfiguring php error reporting for BASE."
sed -i 's#error_reporting \= E_ALL \& ~E_DEPRECATED#error_reporting \= E_ALL \& ~E_NOTICE#' /etc/php.ini

########################################

#Move to DocumentRoot, grab base, untar it and rename the directory to just 'base' for simplicity sake.

print_status "Installing BASE."

cd /var/www/html

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
	print_good "Successfully installed base to /var/www/html/base."
fi

rm base-1.4.5.tar.gz
mv base-* base

########################################

#Other configuration Errata specific to CentOS to get this to work: 
#Resetting DocumentRoot
#Setting ownership of all Base's stuff to be owned by apache 
#Aand of course, SELinux permission changes found that BASE needs httpd_sys_rw_content_t perms to work with the database.

print_status "Resetting default site DocumentRoot to /var/www/html/base."

#making a copy of httpd.conf before we reset DocumentRoot, in case the script explodes in a fit of rage, the user has a backup httpd.conf.
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.orig
print_status "Resetting default site DocumentRoot and Directory to /var/www/html/base."
sed -i 's#/var/www/html#/var/www/html/base#g' /etc/httpd/conf/httpd.conf &>> $base_logfile


#BASE requires the /var/www/html directory to be owned by apache
print_status "Granting ownership of /var/www/html/base recursively to apache user and group."
chown -R apache:apache base/ &>> $base_logfile

print_status "Configuring SELinux permissions for the httpd_sys_rw_content_t context recursively under /var/www/html/base."
chcon -R -t httpd_sys_rw_content_t base/ &>> $base_logfile

print_notification "The log file for this interface installation is located at: $base_logfile"

exit 0

