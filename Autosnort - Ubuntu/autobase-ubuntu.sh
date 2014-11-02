#!/bin/bash
#BASE shell script 'module'
#Sets up BASE for Autosnort 

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
if [ -d /var/www/base ]; then
	print_notification "base directory exists. Deleting to prevent issues.."
	rm -rf /var/www/base
fi

execdir=`pwd`
if [ ! -f $execdir/full_autosnort.conf ]; then
	print_error "full_autosnort.conf was NOT found in $execdir. This script relies HEAVILY on this config file. The main autosnort script, full_autosnort.conf and this file should be located in the SAME directory."
	exit 1
else
	source $execdir/full_autosnort.conf
	print_good "Found config file."
fi

########################################
#grab packages for BASE.

print_status "Grabbing packages required for BASE.."

echo libphp-adodb  libphp-adodb/pathmove note | debconf-set-selections
apt-get install -y libphp-adodb ca-certificates php-pear libwww-perl php5 php5-mysql php5-gd &>> $base_logfile
error_check 'Package installation'


########################################

#These are php-pear config commands.

print_status "Configuring php via php-pear."

pear config-set preferred_state alpha &>> $base_logfile
pear channel-update pear.php.net &>> $base_logfile
pear install --alldeps Image_Color Image_Canvas Image_Graph &>> $base_logfile
error_check 'PHP-Pear configuration'

print_good "Successfully configured php via php-pear."

########################################
#Have to adjust PHP logging otherwise BASE will barf on startup.

print_status "Reconfiguring php error reporting for BASE.."
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
error_check 'BASE download'

tar -xzvf base-1.4.5.tar.gz &>> $base_logfile
error_check 'Untar of BASE'

rm base-1.4.5.tar.gz
mv base-* base

#BASE requires the /var/www/ directory to be owned by www-data
print_status "Granting ownership of /var/www to www-data user and group."
chown -R www-data:www-data /var/www

########################################

#These are virtual host settings. The default virtual host forces redirect of all traffic to https (SSL, port 443) to ensure console traffic is encrypted and secure. We then enable the new SSL site we made, and restart apache to start serving it.


print_status "Configuring Virtual Host Settings for Base.."

echo "#This is an SSL VHOST added by autosnort. Simply remove the file if you no longer wish to serve the web interface." > /etc/apache2/sites-available/base-ssl.conf
echo "<VirtualHost *:443>" >> /etc/apache2/sites-available/base-ssl.conf
echo "	#Turn on SSL. Most of the relevant settings are set in /etc/apache2/mods-available/ssl.conf" >> /etc/apache2/sites-available/base-ssl.conf
echo "	SSLEngine on" >> /etc/apache2/sites-available/base-ssl.conf
echo "" >> /etc/apache2/sites-available/base-ssl
echo "	#Mod_Rewrite Settings. Force everything to go over SSL." >> /etc/apache2/sites-available/base-ssl
echo "	RewriteEngine On" >> /etc/apache2/sites-available/base-ssl.conf
echo "	RewriteCond %{HTTPS} off" >> /etc/apache2/sites-available/base-ssl.conf
echo "	RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI}" >> /etc/apache2/sites-available/base-ssl.conf
echo "" >> /etc/apache2/sites-available/base-ssl.conf
echo "	#Now, we finally get to configuring our VHOST." >> /etc/apache2/sites-available/base-ssl.conf
echo "	ServerName base.localhost" >> /etc/apache2/sites-available/base-ssl.conf
echo "	DocumentRoot /var/www/base" >> /etc/apache2/sites-available/base-ssl.conf
echo "</VirtualHost>" >> /etc/apache2/sites-available/base-ssl.conf

########################################

a2ensite base-ssl.conf &>> $base_logfile
error_check 'Enable BASE vhost'

service apache2 restart &>> $base_logfile
error_check 'Apache restart'

print_notification "The log file for this interface installation is located at: $base_logfile"

exit 0