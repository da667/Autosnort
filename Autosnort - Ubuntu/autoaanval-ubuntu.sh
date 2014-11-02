#!/bin/bash
#Aanval shell script 'module'
#Sets up Aanval for for Autosnort
#WARNING: DO NOT TRY TO USE AANVAL TO MANAGE THE SENSOR!
#GETTING THIS TO ACTUALLY WORK IS GOING TO TAKE A LOT OF TIME AND EFFORT
#TO FIGURE OUT WHERE AANVAL IS TRYING TO LOOK FOR THINGS, NOT TO MENTION
#SOME RE-WORKING OF AUTOSNORT ITSELF...THIS IS STRICTLY TO GET THE IDS 
#EVENT VIEW FUNCTIONALITY WORKING.

########################################
#logging setup: Stack Exchange made this.

aanval_logfile=/var/log/aanval_install.log
mkfifo ${aanval_logfile}.pipe
tee < ${aanval_logfile}.pipe $aanval_logfile &
exec &> ${aanval_logfile}.pipe
rm ${aanval_logfile}.pipe

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
#Pre-setup. First, if the aanval directory exists, delete it. It causes more problems than it resolves, and usually only exists if the install failed in some way. Wipe it away, start with a clean slate.
if [ -d /var/www/aanval ]; then
	print_notification "Snorby directory exists. Deleting to prevent issues.."
	rm -rf /var/www/aanval
fi

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

print_status "Grabbing packages for aanval.."
#grab packages for aanval most of the primary required packages are pulled by  the main AS script. Also suppressing the message for libphp-adodb
echo libphp-adodb  libphp-adodb/pathmove note | debconf-set-selections
apt-get install -y zlib1g-dev libmysqld-dev byacc libxml2-dev zlib1g php5 php5-mysql php5-gd nmap libssl-dev libcrypt-ssleay-perl libphp-adodb php-pear &>> $aanval_logfile
error_check 'Package installation'

########################################

#Make the aanval directory under /var/www, and cd into it
mkdir /var/www/aanval
cd /var/www/aanval



# We need to grab aanval from the aanval.com site. If this fails, we exit the script with a status of 1
# A check needs to be built into the main script to verify this script exits cleanly. If it doesn't,
# The user should be informed and brought back to the main interface selection menu.
print_status "Grabbing Aanval.."
wget https://www.aanval.com/download/pickup -O aanval.tar.gz --no-check-certificate &>> $aanval_logfile
error_check 'Aanval download'

print_status "Installing Aanval.."

tar -xzvf aanval.tar.gz &>> $aanval_logfile
error_check 'Aanval file install'
rm -rf aanval.tar.gz

########################################

#Creating the database infrastructure for Aanval -- We make the database aanvaldb and give the snort user the ability to do work on it.
#This database is totally separate from the snort database, BOTH must be present.

print_status "Configuring mysql to work with Aanval.."

mysql -u root -p$root_mysql_pass -e "create database aanvaldb;" &>> $aanval_logfile
error_check 'Aanval database creation'

#granting the snort user the ability to maintain the snort database so Aanval doesn't need root dba creds.

print_status "Granting snort database user permissions to operate on aanval's database.."
mysql -u root -p$root_mysql_pass -e "grant create, insert, select, delete, update on aanvaldb.* to snort@localhost identified by '$snort_mysql_pass';" &>> $aanval_logfile
error_check 'Grant permissions to aanval database'

########################################

print_status "Granting ownership of /var/www/aanval to www-data.."

chown -R www-data:www-data /var/www/aanval
error_check 'aanval file ownership modification'

########################################

#These are virtual host settings. The default virtual host forces redirect of all traffic to https (SSL, port 443) to ensure console traffic is encrypted and secure. We then enable the new SSL site we made, and restart apache to start serving it.


print_status "Configuring Virtual Host Settings for Aanval.."

echo "#This is an SSL VHOST added by autosnort. Simply remove the file if you no longer wish to serve the web interface." > /etc/apache2/sites-available/aanval-ssl.conf
echo "<VirtualHost *:443>" >> /etc/apache2/sites-available/aanval-ssl.conf
echo "	#Turn on SSL. Most of the relevant settings are set in /etc/apache2/mods-available/ssl.conf" >> /etc/apache2/sites-available/aanval-ssl.conf
echo "	SSLEngine on" >> /etc/apache2/sites-available/aanval-ssl.conf
echo "" >> /etc/apache2/sites-available/aanval-ssl.conf
echo "	#Mod_Rewrite Settings. Force everything to go over SSL." >> /etc/apache2/sites-available/aanval-ssl.conf
echo "	RewriteEngine On" >> /etc/apache2/sites-available/aanval-ssl.conf
echo "	RewriteCond %{HTTPS} off" >> /etc/apache2/sites-available/aanval-ssl.conf
echo "	RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI}" >> /etc/apache2/sites-available/aanval-ssl.conf
echo "" >> /etc/apache2/sites-available/aanval-ssl.conf
echo "	#Now, we finally get to configuring our VHOST." >> /etc/apache2/sites-available/aanval-ssl.conf
echo "	ServerName aanval.localhost" >> /etc/apache2/sites-available/aanval-ssl.conf
echo "	DocumentRoot /var/www/aanval" >> /etc/apache2/sites-available/aanval-ssl.conf
echo "</VirtualHost>" >> /etc/apache2/sites-available/aanval-ssl.conf

########################################

#We start the background processors for the Aanval web interface, drop an init script to start aanval BPUs on boot. If the script is already there, we do not do this action.


print_status "Starting background processors for Aanval web interface.."
cd /var/www/aanval/apps
perl idsBackground.pl -start &>> $aanval_logfile
error_check 'Execution of background processors'

cd $execdir
if [ -f /etc/init.d/aanvalbpu ]; then
	print_notification "aanvalbpu init script already installed."
else
	if [ ! -f $execdir/aanvalbpu ]; then
		print_error "The aanvalbpu file was not found in $execdir. Please make sure the file is there and try again."
		exit 1
	else
		print_good "Found aanvalbpu init script."
	fi
	cp aanvalbpu /etc/init.d/aanvalbpu &>> $aanval_logfile
	chown root:root /etc/init.d/aanvalbpu &>> $aanval_logfile
	chmod 700 /etc/init.d/aanvalbpu &>> $aanval_logfile
	update-rc.d aanvalbpu defaults &>> $aanval_logfile
	error_check 'Init Script creation'
	print_notification "aanvalbpu init script located in /etc/init.d/aanvalbpu"
fi

########################################

#enable the base-ssl vhost we made, and restart apache to serve it.

a2ensite aanval-ssl.conf &>> $aanval_logfile
error_check 'Enable aanval vhost'

service apache2 restart &>> $aanval_logfile
error_check 'Apache restart'


print_notification "The log file for this interface installation is located at: $aanval_logfile"

exit 0