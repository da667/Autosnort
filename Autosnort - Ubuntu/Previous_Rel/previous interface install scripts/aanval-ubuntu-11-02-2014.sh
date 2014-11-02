#!/bin/bash
#Aanval shell script 'module'
#Sets up Aanval for for Autosnort
#WARNING: DO NOT TRY TO USE AANVAL TO MANAGE THE SENSOR!
#GETTING THIS TO ACTUALLY WORK IS GOING TO TAKE A LOT OF TIME AND EFFORT
#TO FIGURE OUT WHERE AANVAL IS TRYING TO LOOK FOR THINGS, NOT TO MENTION
#SOME RE-WORKING OF AUTOSNORT ITSELF...THIS IS STRICTLY TO GET THE IDS 
#EVENT VIEW FUNCTIONALITY WORKING.
#Updated on 2/1/2014

########################################
#logging setup: Stack Exchange made this.

aanval_logfile=/var/log/aanval_install.log
mkfifo ${aanval_logfile}.pipe
tee < ${aanval_logfile}.pipe $aanval_logfile &
exec &> ${aanval_logfile}.pipe
rm ${aanval_logfile}.pipe

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

print_status "Grabbing packages for aanval.."
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

#Make the aanval directory under /var/www, and cd into it
mkdir /var/www/aanval
cd /var/www/aanval



# We need to grab aanval from the aanval.com site

print_status "Grabbing aanval.."
wget https://www.aanval.com/download/pickup -O aanval.tar.gz --no-check-certificate &>> $aanval_logfile
if [ $? != 0 ];then
	print_error "Attempt to pull down aanval console failed. See $aanval_logfile for details."
	exit 1
else
	print_good "Successfully downloaded Aanval."
fi

print_status "Installing Aanval."

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

while true; do
	print_notification "Enter the mysql root user password to create the aanvaldb database."
	mysql -u root -p -e "create database aanvaldb;" &>> $aanval_logfile
	if [ $? != 0 ]; then
		print_notification "the command did NOT complete successfully. (bad password?) Please try again."
		continue
	else
		print_good "aanvaldb database created!"
		break
	fi
done

#Here we call the MYSQL_PASS_1 variable from the main autosnort script in order to give the snort database user access to the aanval db for maintenance.

while true; do
	print_notification "you'll need to enter the mysql root user password one more time to grant the snort database user permissions to the aanvaldb database."
	mysql -u root -p -e "grant create, insert, select, delete, update on aanvaldb.* to snort@localhost identified by '$MYSQL_PASS_1';" &>> $aanval_logfile
	if [ $? != 0 ]; then
		print_notification "the command did NOT complete successfully. (bad password?) Please try again."
		continue
	else
		print_good "database access granted!"
		break
	fi
done

########################################

print_status "Granting ownership of /var/www/aanval to www-data.."

chown -R www-data:www-data /var/www/aanval

print_status "Resetting DocumentRoot to /var/www/aanval"
sed -i 's/DocumentRoot \/var\/www/DocumentRoot \/var\/www\/aanval/' /etc/apache2/sites-available/*default*

########################################

#These are virtual host settings. The default virtual host forces redirect of all traffic to https (SSL, port 443) to ensure console traffic is encrypted and secure. We then enable the new SSL site we made, and restart apache to start serving it.

print_status "Configuring Virtual Host Settings for Snort Report..."

echo "#This default vhost config geneated by autosnort. To remove, run cp /etc/apache2/defaultsiteconfbak /etc/apache2/sites-available/000-default.conf" > /etc/apache2/sites-available/000-default.conf
echo "#This VHOST exists as a catch, to redirect any requests made via HTTP to HTTPS." >> /etc/apache2/sites-available/000-default.conf
echo "<VirtualHost *:80>" >> /etc/apache2/sites-available/000-default.conf
echo "        DocumentRoot /var/www/snortreport" >> /etc/apache2/sites-available/000-default.conf
echo "        #Mod_Rewrite Settings. Force everything to go over SSL." >> /etc/apache2/sites-available/000-default.conf
echo "        RewriteEngine On" >> /etc/apache2/sites-available/000-default.conf
echo "        RewriteCond %{HTTPS} off" >> /etc/apache2/sites-available/000-default.conf
echo "        RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI}" >> /etc/apache2/sites-available/000-default.conf
echo "</VirtualHost>" >> /etc/apache2/sites-available/000-default.conf

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
while true; do
	print_notification "Would you like to add commands to start the background processors on boot to rc.local?"
	read -p "
	Select 1 if you want entries added to /etc/rc.local
	Select 2 if you do not.
	" bgpstart
	case $bgpstart in
		1)
		print_status "Adding job to start background processors on boot to /etc/rc.local."
		echo "cd /var/www/aanval/apps" >> /etc/rc.local
		echo "perl idsBackground.pl -start" >> /etc/rc.local
		print_good "Successfully added background processors to rc.local."
		break
		;;
		2)
		print_notification "If the system reboots, the background processors will need to be started."
		print_notification "You can do this by running: cd /var/www/aanval/apps && perl idsBackground.pl -start"
		break
		;;
		*)
		print_notification "I didn't understand your response. Please try again."
		continue
		;;
	esac
done

########################################

#enable our vhosts and restart apache to enable serve them.

a2ensite 000-default.conf
if [ $? -ne 0 ]; then
    print_error "Failed to enable the default virtual host. See $aanval_logfile for details."
	exit 1	
else
    print_good "Successfully made virtual host changes."
fi

a2ensite aanval-ssl.conf &>> $aanval_logfile
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