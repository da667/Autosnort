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
#Error Checking function. Checks for exist status of last command ran. If non-zero assumes something went wrong and bails script.

function error_check
{

if [ $? -eq 0 ]; then
	print_good "$1 successfully completed."
else
	print_error "$1 failed. Please check $logfile for more details, or contact deusexmachina667 at gmail dot com for more assistance."
exit 1
fi

}

########################################
#Pre-setup. First, if the base directory exists, delete it. It causes more problems than it resolves, and usually only exists if the install failed in some way. Wipe it away, start with a clean slate.
if [ -d /var/www/html/base ]; then
	print_notification "base directory exists. Deleting to prevent issues.."
	rm -rf /var/www/html/base
fi

########################################

execdir=`pwd`
if [ ! -f $execdir/full_autosnort.conf ]; then
	print_error "full_autosnort.conf was NOT found in $execdir. This script relies HEAVILY on this config file. The main autosnort script, full_autosnort.conf and this file should be located in the SAME directory."
	exit 1
else
	source $execdir/full_autosnort.conf
	print_good "Found config file."
fi

########################################
#grab packages for BASE. CentOS 7 for some reason doesn't have an ADODB package in EPEL, so we have to improvise. If the version of CentOS is 7 or greater, we have to go download and install it manually. Otherwise we assume that php-adodb.noarch is available.

print_status "Grabbing packages required for BASE.."
release=`grep -oP '(?<!\.)[67]\.[0-9]+(\.[0-9]+)?' /etc/redhat-release | cut -d"." -f1`

if [[ "$release" -ge "7" ]]; then
	yum -y install php php-common php-gd php-cli php-mysql php-pear.noarch perl-libwww-perl openssl-devel
	cd /usr/share/php
	wget http://sourceforge.net/projects/adodb/files/adodb-php5-only/adodb-519-for-php5/adodb519.tar.gz/download -O adodb.tar.gz
	error_check 'Download of adodb from sourceforge'
	tar -xzvf adodb.tar.gz
	mv adodb5 adodb
	chmod 755 adodb
	chown -R root:root adodb
	error_check 'Installation of adodb'
	rm -rf adodb.tar.gz
else
	yum -y install php php-common php-gd php-cli php-mysql php-pear.noarch perl-libwww-perl openssl-devel &>> $base_logfile
	error_check 'BASE package installation'
fi

########################################

#These are php-pear config commands Seen in the 2.9.4.0 install guide for Debian.

print_status "Configuring php via php-pear.."

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

print_status "Reconfiguring php error reporting for BASE.."
sed -i 's#error_reporting \= E_ALL \& ~E_DEPRECATED#error_reporting \= E_ALL \& ~E_NOTICE#' /etc/php.ini

########################################

#Move to DocumentRoot, grab base, untar it and rename the directory to just 'base' for simplicity sake.

print_status "Installing BASE.."

cd /var/www/html

# We need to grab BASE from sourceforge. If this fails, we exit the script with a status of 1
# A check is built into the main script to verify this script exits cleanly. If it doesn't,
# The user should be informed and brought back to the main interface selection menu.

print_status "Grabbing BASE via Sourceforge.."

wget http://sourceforge.net/projects/secureideas/files/BASE/base-1.4.5/base-1.4.5.tar.gz -O base-1.4.5.tar.gz &>> $base_logfile
error_check 'BASE download'

tar -xzvf base-1.4.5.tar.gz &>> $base_logfile
error_check 'Untar of BASE'

rm base-1.4.5.tar.gz
mv base-* base

########################################

#Here we are creating some Virtual Host settings in /etc/httpd/conf/httpd.conf to support SSL

print_status "Adding Virtual Host settings and reconfiguring httpd to use SSL.."

echo "" >> /etc/httpd/conf/httpd.conf
echo "<IfModule mod_ssl.c>" >> /etc/httpd/conf/httpd.conf
echo "	<VirtualHost *:443>" >> /etc/httpd/conf/httpd.conf
echo "		#SSL Settings, including support for PFS." >> /etc/httpd/conf/httpd.conf
echo "		SSLEngine on" >> /etc/httpd/conf/httpd.conf
echo "		SSLCertificateFile /etc/httpd/ssl/ids.cert" >> /etc/httpd/conf/httpd.conf
echo "		SSLCertificateKeyFile /etc/httpd/ssl/ids.key" >> /etc/httpd/conf/httpd.conf
echo "		SSLProtocol all -SSLv2 -SSLv3" >> /etc/httpd/conf/httpd.conf
echo "		SSLHonorCipherOrder on" >> /etc/httpd/conf/httpd.conf
echo "		SSLCipherSuite \"EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+aRSA+RC4 EECDH EDH+aRSA RC4 !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS\"" >> /etc/httpd/conf/httpd.conf
echo "" >> /etc/httpd/conf/httpd.conf
echo "		#Mod_Rewrite Settings. Force everything to go over SSL." >> /etc/httpd/conf/httpd.conf
echo "		RewriteEngine On" >> /etc/httpd/conf/httpd.conf
echo "		RewriteCond %{HTTPS} off" >> /etc/httpd/conf/httpd.conf
echo "		RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI}" >> /etc/httpd/conf/httpd.conf
echo "" >> /etc/httpd/conf/httpd.conf
echo "		#Now, we finally get to configuring our VHOST." >> /etc/httpd/conf/httpd.conf
echo "		ServerName base.localhost" >> /etc/httpd/conf/httpd.conf
echo "		DocumentRoot /var/www/html/base" >> /etc/httpd/conf/httpd.conf
echo "	</VirtualHost>" >> /etc/httpd/conf/httpd.conf
echo "</IfModule>" >> /etc/httpd/conf/httpd.conf

print_good "httpd reconfigured."

#BASE requires the /var/www/html directory to be owned by apache
print_status "Granting ownership of /var/www/html/base recursively to apache user and group.."
chown -R apache:apache base/ &>> $base_logfile
error_check 'BASE file ownership reset'

#Base also requires specific SELinux permissions to access its files.
print_status "Configuring SELinux permissions for the httpd_sys_rw_content_t context recursively under /var/www/html/base.."
chcon -R -t httpd_sys_rw_content_t base/ &>> $base_logfile
error_check 'SELinux permission reset'

#This restart is to make sure the configuration changes to httpd were performed succesfully and do not cause any problems starting/stopping the service.
print_status "Restarting httpd.."
service httpd restart &>> $base_logfile
error_check 'httpd restart'

print_notification "The log file for this interface installation is located at: $base_logfile"

exit 0

