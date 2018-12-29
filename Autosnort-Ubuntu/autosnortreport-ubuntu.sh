#!/bin/bash
#Snortreport shell script 'module'
#Sets up snort report for Autosnort

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

#Pre-setup. First, if the SnortReport or JPGraph directories exist, delete them. It causes more problems than it resolves, and usually only exists if the install failed in some way. Wipe it away, start with a clean slate.
if [ -d /var/www/snortreport ]; then
	print_notification "Directory exists. Deleting to prevent issues.."
	rm -rf /var/www/snortreport &>> $sreport_logfile
fi
if [ -d /var/www/jpgraph ]; then
	print_notification "Directory exists. Deleting to prevent issues.."
	rm -rf /var/www/jpgraph &>> $sreport_logfile
fi

########################################
#The config file should be in the same directory that SnortReport script is exec'd from. This shouldn't fail, but if it does..

execdir=`pwd`
if [ ! -f $execdir/full_autosnort.conf ]; then
	print_error "full_autosnort.conf was NOT found in $execdir. This script relies HEAVILY on this config file. The main autosnort script, full_autosnort.conf and this file should be located in the SAME directory."
	exit 1
else
	source $execdir/full_autosnort.conf
	print_good "Found config file."
fi

########################################

print_status "Installing packages for Snortreport.."

apt-get install -y php5 php5-mysql php5-gd nmap nbtscan &>> $sreport_logfile
error_check 'Package installation'

########################################

#Grab jpgraph and throw it in /var/www
#Required to display graphs in snort report UI

print_status "Downloading and installing jpgraph.."

cd /var/www

wget http://jpgraph.net/download/download.php?p=5 -O jpgraph305.tar.gz &>> $sreport_logfile
error_check 'jpgraph download'

print_status "Installing jpgraph.."

tar -xzvf jpgraph305.tar.gz &>> $sreport_logfile
error_check 'jpgraph installation'

rm -rf jpgraph305.tar.gz &>> $sreport_logfile
mv jpgraph-3* jpgraph &>> $sreport_logfile

########################################

#now to install snort report.

print_status "downloading and installing Snort Report.."

wget http://symmetrixtech.com/wp/wp-content/uploads/2014/09/snortreport-1.3.4.tar.gz &>> $sreport_logfile
error_check 'snortreport download'

tar -xzvf snortreport-1.3.4.tar.gz &>> $sreport_logfile
error_check 'snortreport file installation'

rm -rf snortreport-1.3.4.tar.gz &>> $sreport_logfile
mv /var/www/snortreport-1.3.4 /var/www/snortreport &>> $sreport_logfile

########################################

print_status "Pointing Snort Report to the mysql database.."

sed -i "s/PASSWORD/$snort_mysql_pass/" /var/www/snortreport/srconf.php 

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
	sed -i 's#<?#<?php#g' $s_open_file
	sed -i 's#<?phpphp#<?php#g' $s_open_file
	sed -i 's#<?php=#<?php echo #g' $s_open_file
done

print_good "Short open tags fixed."

########################################

#changing access to srconf.php -- the file is world-readable by default. I don't like that. Also, the files here should probably be owned by www-data.

print_status "Setting file ownership for /var/www/snortreport, /var/www/jpgraph to www-data; making srconf.php read-only by www-data user and group.."

chmod 400 /var/www/snortreport/srconf.php &>> $sreport_logfile

chown -R www-data:www-data /var/www/snortreport &>> $sreport_logfile
chown -R www-data:www-data /var/www/jpgraph &>> $sreport_logfile

print_good "File permissions reset."

########################################

#These are virtual host settings. The default virtual host forces redirect of all traffic to https (SSL, port 443) to ensure console traffic is encrypted and secure. We then enable the new SSL site we made, and restart apache to start serving it.

print_status "Configuring Virtual Host Settings for Snort Report..."

echo "#This is an SSL VHOST added by autosnort. Simply remove the file if you no longer wish to serve the web interface." > /etc/apache2/sites-available/snortreport-ssl.conf
echo "<VirtualHost *:443>" >> /etc/apache2/sites-available/snortreport-ssl.conf
echo "	#Turn on SSL. Most of the relevant settings are set in /etc/apache2/mods-available/ssl.conf" >> /etc/apache2/sites-available/snortreport-ssl.conf
echo "	SSLEngine on" >> /etc/apache2/sites-available/snortreport-ssl.conf
echo "" >> /etc/apache2/sites-available/snortreport-ssl.conf
echo "	#Mod_Rewrite Settings. Force everything to go over SSL." >> /etc/apache2/sites-available/snortreport-ssl.conf
echo "	RewriteEngine On" >> /etc/apache2/sites-available/snortreport-ssl.conf
echo "	RewriteCond %{HTTPS} off" >> /etc/apache2/sites-available/snortreport-ssl.conf
echo "	RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI}" >> /etc/apache2/sites-available/snortreport-ssl.conf
echo "" >> /etc/apache2/sites-available/snortreport-ssl.conf
echo "	#Now, we finally get to configuring our VHOST." >> /etc/apache2/sites-available/snortreport-ssl.conf
echo "	ServerName snortreport.localhost" >> /etc/apache2/sites-available/snortreport-ssl.conf
echo "	DocumentRoot /var/www/snortreport" >> /etc/apache2/sites-available/snortreport-ssl.conf
echo "</VirtualHost>" >> /etc/apache2/sites-available/snortreport-ssl.conf

########################################

a2ensite snortreport-ssl.conf &>> $sreport_logfile
error_check 'snortreport vhost'

service apache2 restart &>> $sreport_logfile
error_check 'Apache restart'

print_notification "The log file for this interface installation is located at: $sreport_logfile"

exit 0