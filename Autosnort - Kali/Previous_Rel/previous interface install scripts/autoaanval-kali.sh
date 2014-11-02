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

print_status "Grabbing packages for Aanval.."
#grab packages for aanval most of the primary required packages are pulled by  the main AS script. Also suppressing the message for libphp-adodb
echo libphp-adodb  libphp-adodb/pathmove note | debconf-set-selections
apt-get install -y zlib1g-dev libmysqld-dev byacc libxml2-dev zlib1g php5 php5-mysql php5-gd nmap libssl-dev libcrypt-ssleay-perl libphp-adodb php-pear &>> $aanval_logfile

if [ $? != 0 ];then
	print_error "Failed to acquire required packages for Aanval. See $aanval_logfile for details."
	exit 1
else
	print_good "Successfully acquired packages."
fi

########################################

execdir=`pwd`
source $execdir/full_autosnort.conf

#Make the aanval directory under /var/www, and cd into it
mkdir /var/www/aanval
cd /var/www/aanval



# We need to grab aanval from the aanval.com site. If this fails, we exit the script with a status of 1
# A check needs to be built into the main script to verify this script exits cleanly. If it doesn't,
# The user should be informed and brought back to the main interface selection menu.
print_status "Grabbing Aanval.."
wget https://www.aanval.com/download/pickup -O aanval.tar.gz --no-check-certificate &>> $aanval_logfile
if [ $? != 0 ];then
	print_error "Attempt to pull down aanval console failed. See $aanval_logfile for details."
	exit 1
else
	print_good "Successfully downloaded Aanval."
fi

print_status "Installing Aanval.."

tar -xzvf aanval.tar.gz &>> $aanval_logfile
if [ $? != 0 ];then
	print_error "Attempt to unpack Aanval failed. See $aanval_logfile for details."
	exit 1
else
	print_good "Successfully installed aanval to /var/www/aanval."
fi
rm -rf aanval.tar.gz

########################################

#Creating the database infrastructure for Aanval -- We make the database aanvaldb and give the snort user the ability to do work on it.
#This database is totally separate from the snort database, BOTH must be present.

print_status "Configuring mysql to work with Aanval.."

mysql -u root -p$root_mysql_pass -e "create database aanvaldb;" &>> $aanval_logfile
if [ $? != 0 ]; then
	print_notification "the command did NOT complete successfully. See $aanval_logfile for details."
	exit 1
else
	print_good "aanvaldb database created!"
fi


#granting the snort user the ability to maintain the snort database so Aanval doesn't need root dba creds.

print_status "Granting snort database user permissions to operate on aanval's database.."
mysql -u root -p$root_mysql_pass -e "grant create, insert, select, delete, update on aanvaldb.* to snort@localhost identified by '$snort_mysql_pass';" &>> $aanval_logfile
if [ $? != 0 ]; then
	print_notification "the command did NOT complete successfully. See $aanval_logfile for details."
	exit 1
else
	print_good "database access granted!"
fi


print_status "Granting ownership of /var/www/aanval to www-data.."

chown -R www-data:www-data /var/www/aanval
if [ $? != 0 ]; then
	print_notification "the command did NOT complete successfully. See $aanval_logfile for details."
	exit 1
else
	print_good "Permissions modified!"
fi

########################################

#These are virtual host settings. The default virtual host forces redirect of all traffic to https (SSL, port 443) to ensure console traffic is encrypted and secure. We then enable the new SSL site we made, and restart apache to start serving it.


print_status "Configuring Virtual Host Settings for Aanval.."
echo "#This default vhost config geneated by autosnort. To remove, run cp /etc/apache2/defaultsiteconfbak /etc/apache2/sites-available/default" > /etc/apache2/sites-available/default
echo "#This VHOST exists as a catch, to redirect any requests made via HTTP to HTTPS." >> /etc/apache2/sites-available/default
echo "<VirtualHost *:80>" >> /etc/apache2/sites-available/default
echo "        DocumentRoot /var/www/aanval" >> /etc/apache2/sites-available/default
echo "        #Mod_Rewrite Settings. Force everything to go over SSL." >> /etc/apache2/sites-available/default
echo "        RewriteEngine On" >> /etc/apache2/sites-available/default
echo "        RewriteCond %{HTTPS} off" >> /etc/apache2/sites-available/default
echo "        RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI}" >> /etc/apache2/sites-available/default
echo "</VirtualHost>" >> /etc/apache2/sites-available/default

echo "#This is an SSL VHOST added by autosnort. Simply remove the file if you no longer wish to serve the web interface." > /etc/apache2/sites-available/aanval-ssl
echo "<VirtualHost *:443>" >> /etc/apache2/sites-available/aanval-ssl
echo "	#Turn on SSL. Most of the relevant settings are set in /etc/apache2/mods-available/ssl.conf" >> /etc/apache2/sites-available/aanval-ssl
echo "	SSLEngine on" >> /etc/apache2/sites-available/aanval-ssl
echo "" >> /etc/apache2/sites-available/aanval-ssl
echo "	#Mod_Rewrite Settings. Force everything to go over SSL." >> /etc/apache2/sites-available/aanval-ssl
echo "	RewriteEngine On" >> /etc/apache2/sites-available/aanval-ssl
echo "	RewriteCond %{HTTPS} off" >> /etc/apache2/sites-available/aanval-ssl
echo "	RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI}" >> /etc/apache2/sites-available/aanval-ssl
echo "" >> /etc/apache2/sites-available/aanval-ssl
echo "	#Now, we finally get to configuring our VHOST." >> /etc/apache2/sites-available/aanval-ssl
echo "	ServerName aanval.localhost" >> /etc/apache2/sites-available/aanval-ssl
echo "	DocumentRoot /var/www/aanval" >> /etc/apache2/sites-available/aanval-ssl
echo "</VirtualHost>" >> /etc/apache2/sites-available/aanval-ssl

########################################

#We start the background processors for the Aanval web interface, and ask the user of they want an entry in rc.local to ensure the background processors are automatically started on reboot.
#TODO: make an init script.

print_status "Starting background processors for Aanval web interface.."
cd /var/www/aanval/apps
perl idsBackground.pl -start &>> $aanval_logfile
if [ $? != 0 ];then
	print_error "failed to start background processors. See $aanval_logfile for details."
	exit 1
else
	print_good "Successfully started background processors."
fi

print_notification "The background processors need to run in order to export events fro the snort database to aanval's database."

case $bgpstart in
	1)
	print_status "Adding job to start background processors on boot to /etc/rc.local."
	echo "cd /var/www/aanval/apps" >> /etc/rc.local
	echo "perl idsBackground.pl -start" >> /etc/rc.local
	print_good "Successfully added background processors to rc.local."
	;;
	2)
	print_notification "If the system reboots, the background processors will need to be started."
	print_notification "You can do this by running: cd /var/www/aanval/apps && perl idsBackground.pl -start"
	;;
	*)
	print_notification "Invalid configuration option. Check your full_autosnort.conf config and try again."
	exit 1
	;;
esac


########################################

#enable the base-ssl vhost we made, and restart apache to serve it.

a2ensite aanval-ssl &>> $aanval_logfile
if [ $? -ne 0 ]; then
    print_error "Failed to enable base-ssl virtual host. See $aanval_logfile for details."
	exit 1	
else
    print_good "Successfully made virtual host changes."
fi

service apache2 restart &>> $aanval_logfile
if [ $? -ne 0 ]; then
    print_error "Failed to restart apache2. See $aanval_logfile for details."
	exit 1	
else
    print_good "Successfully restarted apache2."
fi


print_notification "The log file for this interface installation is located at: $aanval_logfile"

exit 0