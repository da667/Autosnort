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

#BASE requires the /var/www/ directory to be owned by www-data
print_status "Granting ownership of /var/www to www-data user and group."
chown -R www-data:www-data /var/www

########################################

#These are virtual host settings. The default virtual host forces redirect of all traffic to https (SSL, port 443) to ensure console traffic is encrypted and secure. We then enable the new SSL site we made, and restart apache to start serving it.


print_status "Configuring Virtual Host Settings for Base.."
echo "#This default vhost config geneated by autosnort. To remove, run cp /etc/apache2/defaultsiteconfbak /etc/apache2/sites-available/default" > /etc/apache2/sites-available/default
echo "#This VHOST exists as a catch, to redirect any requests made via HTTP to HTTPS." >> /etc/apache2/sites-available/default
echo "<VirtualHost *:80>" >> /etc/apache2/sites-available/default
echo "        DocumentRoot /var/www/base" >> /etc/apache2/sites-available/default
echo "        #Mod_Rewrite Settings. Force everything to go over SSL." >> /etc/apache2/sites-available/default
echo "        RewriteEngine On" >> /etc/apache2/sites-available/default
echo "        RewriteCond %{HTTPS} off" >> /etc/apache2/sites-available/default
echo "        RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI}" >> /etc/apache2/sites-available/default
echo "</VirtualHost>" >> /etc/apache2/sites-available/default

echo "#This is an SSL VHOST added by autosnort. Simply remove the file if you no longer wish to serve the web interface." > /etc/apache2/sites-available/base-ssl
echo "<VirtualHost *:443>" >> /etc/apache2/sites-available/base-ssl
echo "	#Turn on SSL. Most of the relevant settings are set in /etc/apache2/mods-available/ssl.conf" >> /etc/apache2/sites-available/base-ssl
echo "	SSLEngine on" >> /etc/apache2/sites-available/base-ssl
echo "" >> /etc/apache2/sites-available/base-ssl
echo "	#Mod_Rewrite Settings. Force everything to go over SSL." >> /etc/apache2/sites-available/base-ssl
echo "	RewriteEngine On" >> /etc/apache2/sites-available/base-ssl
echo "	RewriteCond %{HTTPS} off" >> /etc/apache2/sites-available/base-ssl
echo "	RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI}" >> /etc/apache2/sites-available/base-ssl
echo "" >> /etc/apache2/sites-available/base-ssl
echo "	#Now, we finally get to configuring our VHOST." >> /etc/apache2/sites-available/base-ssl
echo "	ServerName base.localhost" >> /etc/apache2/sites-available/base-ssl
echo "	DocumentRoot /var/www/base" >> /etc/apache2/sites-available/base-ssl
echo "</VirtualHost>" >> /etc/apache2/sites-available/base-ssl

a2ensite base-ssl &>> $base_logfile
if [ $? -ne 0 ]; then
    print_error "Failed to enable base-ssl virtual host. See $base_logfile for details."
	exit 1	
else
    print_good "Successfully made virtual host changes."
fi

service apache2 restart &>> $base_logfile
if [ $? -ne 0 ]; then
    print_error "Failed to restart apache2. See $base_logfile for details."
	exit 1	
else
    print_good "Successfully restarted apache2."
fi

print_notification "The log file for this interface installation is located at: $base_logfile"

exit 0