#!/bin/bash
#Snorby shell script 'module'
#Sets up snorby for Autosnort

########################################
#logging setup: Stack Exchange made this.

snorby_logfile=/var/log/snorby_install.log
mkfifo ${snorby_logfile}.pipe
tee < ${snorby_logfile}.pipe $snorby_logfile &
exec &> ${snorby_logfile}.pipe
rm ${snorby_logfile}.pipe

########################################
#Metasploit-like print statements: status, good, bad and notification. Gratouitiously ganked from Darkoperator's metasploit install script.

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

#Pre-setup. First, if the Snorby directory exists, delete it. It causes more problems than it resolves, and usually only exists if the install failed in some way. Wipe it away, start with a clean slate.
if [ -d /var/www/snorby ]; then
	print_notification "Snorby directory exists. Deleting to prevent issues.."
	rm -rf /var/www/snorby
fi

########################################

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

#This entire first block is to: Grab pre-reqs for Snorby, rvm (to install and automatically fix dependencies for ruby), install all the gems needed for snorby, then pull down snorby via github.

print_status "Acquiring packages for snorby (this may take a little while)"

apt-get install -y libyaml-dev git-core wkhtmltopdf libssl-dev libxslt1-dev libsqlite3-dev libmysql++-dev libcurl4-openssl-dev apache2-prefork-dev default-jre-headless curl sudo &>> $snorby_logfile
error_check 'Package installation'

print_status "Acquiring RVM.."
wget https://get.rvm.io -O rvm_stable.sh &>> $snorby_logfile
error_check 'Download of RVM'

bash rvm_stable.sh &>> $snorby_logfile
error_check 'RVM installation'

print_status "Configuring RVM."

/usr/local/rvm/bin/rvm autolibs enable
source /etc/profile.d/rvm.sh

print_good "RVM configured."

########################################
#Now we go to ruby-lang.org to determine the latest 1.9.x release (snorby isn't 2.x compatible) to install, then install it.

print_status "Hitting ruby-lang.org downloads page determine the latest version of ruby 1.9.x to install.."

wget http://www.ruby-lang.org/en/downloads/ -O /tmp/downloads.html &>> $snorby_logfile
error_check 'Download of ruby-lang.org downloads page'

rubyver=`grep -e "ruby-1" /tmp/downloads.html | head -2 | tail -1 | cut -d"-" -f3,4 | cut -d"." -f1,2,3`

print_status "installing ruby-$rubyver (this will take a little while).."
rvm install ruby-$rubyver &>> $snorby_logfile
error_check 'Ruby installation'

########################################

print_status "Installing gems required for snorby.."

gem install thor i18n bundler tzinfo builder memcache-client rack rack-test rack-mount rails rake rubygems-update erubis mail text-format sqlite3 daemon_controller passenger &>> $snorby_logfile

print_good "Gems installed successfully."

update_rubygems &>> $snorby_logfile

########################################

cd /var/www/

print_status "Grabbing snorby via github.."

git clone https://github.com/Snorby/snorby.git &>> $snorby_logfile
error_check 'Snorby download'

########################################

#Now that we pulled down snorby, we have to modify the configuration files.

print_status "Configuring Snorby and pointing it to the mysql database."

cd /var/www/snorby/config

cp database.yml.example database.yml #database name, user, and password
cp snorby_config.yml.example snorby_config.yml #change path to wkhtmltopdf to /usr/bin/wkhtmltopdf

sed -i 's#usr/local/bin#/usr/bin#' /var/www/snorby/config/snorby_config.yml
sed -i 's/password: "Enter Password Here" # Example: password: "s3cr3tsauce"/password:/' /var/www/snorby/config/database.yml
sed -i "s/password:/password: $root_mysql_pass/" /var/www/snorby/config/database.yml

print_good "Snorby successfully configured."

########################################
#This portion compiles the passenger module and configures apache to use it by modifying apache2.conf. We make a backup before we modify apache2.conf. If the backup exists, we restore it to prevent duplicate configuration file directives.

print_status "Installing mod_passenger (This will take a moment or two).."

passengerver=`ls /usr/local/rvm/gems/ruby-$rubyver/gems/ | grep passenger | cut -d"-" -f2,3`
passenger-install-apache2-module --auto &>> $snorby_logfile
error_check 'mod_passenger install'

print_status "Adding passenger module to /etc/apache2.conf"

if [ -f /etc/apache2/apache2_confbak ]; then
	print_notification "Found /etc/apache2/apache2_confbak. Restoring backup to prevent errors/duplicate config file entries.."
	cp /etc/apache2/apache2_confbak /etc/apache2/apache2.conf
	error_check 'apache2.conf restore'
fi

cp /etc/apache2/apache2.conf /etc/apache2/apache2_confbak

echo "" >> /etc/apache2/apache2.conf
echo "# This stuff is to make Snorby work properly mod_passenger is required for snorby to work." >> /etc/apache2/apache2.conf
echo "" >> /etc/apache2/apache2.conf
echo "LoadModule passenger_module /usr/local/rvm/gems/ruby-$rubyver/gems/passenger-$passengerver/buildout/apache2/mod_passenger.so" >> /etc/apache2/apache2.conf
echo "PassengerRoot /usr/local/rvm/gems/ruby-$rubyver/gems/passenger-$passengerver" >> /etc/apache2/apache2.conf
echo "PassengerDefaultRuby /usr/local/rvm/wrappers/ruby-$rubyver/ruby" >> /etc/apache2/apache2.conf
#Newly added. TEST THIS.
echo "PassengerDefaultUser www-data" >> /etc/apache2/apache2.conf
echo "PassengerUser www-data" >> /etc/apache2/apache2.conf
echo "PassengerGroup www-data" >> /etc/apache2/apache2.conf
#END NEWLY ADDED
print_good "Apache successfully configured to use passenger."

########################################
#These are virtual host settings. The default virtual host forces redirect of all traffic to https (SSL, port 443) to ensure console traffic is encrypted and secure.

print_status "Configuring Snorby vhost.."

echo "#This is an SSL VHOST added by autosnort. Simply remove the file if you no longer wish to serve the web interface." > /etc/apache2/sites-available/snorby-ssl.conf
echo "<VirtualHost *:443>" >> /etc/apache2/sites-available/snorby-ssl.conf
echo "	#Turn on SSL. Most of the relevant settings are set in /etc/apache2/mods-available/ssl.conf" >> /etc/apache2/sites-available/snorby-ssl.conf
echo "	SSLEngine on" >> /etc/apache2/sites-available/snorby-ssl.conf
echo "" >> /etc/apache2/sites-available/snorby-ssl
echo "	#Mod_Rewrite Settings. Force everything to go over SSL." >> /etc/apache2/sites-available/snorby-ssl.conf
echo "	RewriteEngine On" >> /etc/apache2/sites-available/snorby-ssl.conf
echo "	RewriteCond %{HTTPS} off" >> /etc/apache2/sites-available/snorby-ssl.conf
echo "	RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI}" >> /etc/apache2/sites-available/snorby-ssl.conf
echo "" >> /etc/apache2/sites-available/snorby-ssl.conf
echo "	#Now, we finally get to configuring our VHOST." >> /etc/apache2/sites-available/snorby-ssl.conf
echo "	ServerName snorby.localhost" >> /etc/apache2/sites-available/snorby-ssl.conf
echo "	DocumentRoot /var/www/snorby/public" >> /etc/apache2/sites-available/snorby-ssl.conf
echo "     <Directory /var/www/snorby/public>" >> /etc/apache2/sites-available/snorby-ssl.conf
echo "          # This relaxes Apache security settings." >> /etc/apache2/sites-available/snorby-ssl
echo "          AllowOverride all" >> /etc/apache2/sites-available/snorby-ssl.conf
echo "          # MultiViews must be turned off." >> /etc/apache2/sites-available/snorby-ssl.conf
echo "          Options -MultiViews" >> /etc/apache2/sites-available/snorby-ssl.conf
echo "     </Directory>" >> /etc/apache2/sites-available/snorby-ssl.conf
echo "</VirtualHost>" >> /etc/apache2/sites-available/snorby-ssl.conf

print_good "Snorby vhost added."

########################################

#The below portion are the final steps. We run bundler and rake to prep Snorby for use.

print_status "Running bundler.."

cd /var/www/snorby

bundle install --deployment &>> $snorby_logfile
error_check 'bundler'

#TODO:`which pdfkit` --install-wkhtmltopdf 

print_status "Running rake.."

rake snorby:setup &>> $snorby_logfile
error_check 'rake'

########################################

#The commands below are to drop privileges: We want to have the snort database user manage the snorby database. This is done for purposes of least privilege. You don't need root, so I'm not giving it to you.

print_status "Giving permission to snort database user to manage the snorby database (dropping privs).."

mysql -uroot -p$root_mysql_pass -e "grant create, insert, select, delete, update on snorby.* to snort@localhost identified by '$snort_mysql_pass';" &>> $snorby_logfile

print_status "Reconfiguring Snorby and Barnyard2 to work together."

sed -i 's/username: root/username: snort/' /var/www/snorby/config/database.yml
sed -i 's/password: $root_mysql_pass/password: $snort_mysql_pass/' /var/www/snorby/config/database.yml
sed -i 's/dbname=snort/dbname=snorby/' $snort_basedir/etc/barnyard2.conf

########################################

#I'm not comfortable with the database user's creds being in a world-readable file.

print_status "Resetting permissions on database.yml and snorby_config.yml.."

chmod 400 /var/www/snorby/config/database.yml 
chmod 400 /var/www/snorby/config/snorby_config.yml

########################################

#give www-data access to snorby's files, enable the snorby site, restart apache.

print_status "Giving ownership of /var/www/snorby to www-data user and group."

chown -R www-data:www-data /var/www/snorby/

########################################

a2ensite snorby-ssl.conf &>> $snorby_logfile
error_check 'enable Snorby vhost'

service apache2 restart &>> $snorby_logfile
error_check 'apache service restart'

print_notification "The log file for this interface installation is located at: $snorby_logfile"

exit 0