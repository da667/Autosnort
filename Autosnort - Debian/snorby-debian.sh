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

#This entire first block is to: Grab pre-reqs for Snorby, rvm (to install and automatically fix dependencies for ruby), install all the gems needed for snorby, then pull down snorby via github.

print_status "Acquiring packages for snorby (this may take a little while)"

apt-get install -y libyaml-dev git-core wkhtmltopdf libssl-dev libxslt1-dev libsqlite3-dev libmysql++-dev libcurl4-openssl-dev apache2-prefork-dev default-jre-headless curl sudo &>> $snorby_logfile
if [ $? -eq 0 ]; then
	print_good "Packages successfully installed."
else
	print_error "Packages failed to install!"
	exit 1
fi


print_status "Acquiring RVM."

\curl -k -\#L https://get.rvm.io | sudo bash -s stable &>> $snorby_logfile
if [ $? -eq 0 ]; then
	print_good "RVM installed successfully."
else
	print_error "RVM failed to install."
	exit 1
fi

print_status "Configuring RVM."

/usr/local/rvm/bin/rvm autolibs enable
source /etc/profile.d/rvm.sh

print_good "RVM configured."

print_status "Hitting ruby-lang.org to determine the latest version of ruby 1.9.x to install.."

wget http://ruby-lang.org/en/downloads -O /tmp/downloads.html &>> $snorby_logfile
if [ $? -ne 0 ]; then
	print_error "Failed to hit ruby-lang.org. Please see $snorby_logfile for more details."
	exit 1
fi

########################################

print_status "doing some shell magic to pick out the latest ruby 1.9.X version."

rubyver=`cat /tmp/downloads.html | grep -e "ruby-" | head -2 | tail -1 | cut -d"-" -f3,4 | cut -d"." -f1,2,3`
print_status "installing ruby-$rubyver (this will take a little while)"
rvm install ruby-$rubyver &>> $snorby_logfile
if [ $? -ne 0 ]; then
	print_error "Failed to install ruby-$rubyver. Please see $snorby_logfile for more details."
	exit 1
else
	print_good "Ruby-$rubyver installed successfully."
fi

########################################

print_status "Installing gems required for snorby."

gem install thor i18n bundler tzinfo builder memcache-client rack rack-test rack-mount rails rake rubygems-update erubis mail text-format sqlite3 daemon_controller passenger &>> $snorby_logfile

print_good "Gems installed successfully."

update_rubygems &>> $snorby_logfile

########################################

cd /var/www/

print_status "Grabbing snorby via github."

git clone http://github.com/Snorby/snorby.git &>> $snorby_logfile
if [ $? -ne 0 ]; then
	print_error "Failed to grab Snorby. Please see $snorby_logfile for more details."
	exit 1
else
	print_good "Acquired Snorby successfully."
fi

########################################

#Now that we pulled down snorby, we have to modify the configuration files. sed is used to point snorby to the proper path for wkhtmltopdf, and we have the user enter the root mysql user's creds to have snorby create the snorby database.
#TODO: at the end of the script give the snort database user rights to manage the snorby database; database.yml is world readable by default. I don't like the idea of having root database creds world-readable.

print_status "Configuring Snorby and pointing it to the mysql database."

cd /var/www/snorby/config

cp database.yml.example database.yml #database name, user, and password
cp snorby_config.yml.example snorby_config.yml #change path to wkhtmltopdf to /usr/bin/wkhtmltopdf

sed -i 's/usr\/local\/bin/usr\/bin/' snorby_config.yml

while true; do
	print_notification "Please enter the ROOT mysql user's password. Snorby needs it in order to create the snorby database."
	read -s -p "Please enter the ROOT database user password:" root_pass_1
	echo ""
	read -s -p "Confirm:" root_pass_2
	echo ""
	if [ "$root_pass_1" == "$root_pass_2" ]; then
		print_good "password confirmed."
		echo ""
		sed -i 's/password: "Enter Password Here" # Example: password: "s3cr3tsauce"/password: '$root_pass_1'/' database.yml
		break
	else
		echo ""
		print_notification -e "Passwords do not match. Please try again."
		continue
	fi
done

print_good "Snorby successfully configured"

########################################

#This entire block and all the echo statements below are to install the passenger apache module. I don't know much about rails or ruby, other than passenger is considered vital to getting everything to work. This compiles passenger, adds it to apache2.conf and creates a new default site for snorby

print_status "Compiling and configuring Passenger module. (This will take a moment or two)"

passengerver=`ls /usr/local/rvm/gems/ruby-$rubyver/gems/ | grep passenger | cut -d"-" -f2,3`
passenger-install-apache2-module --auto &>> $snorby_logfile
if [ $? -ne 0 ]; then
	print_error "Failed to compile passenger. Please see $snorby_logfile for more details."
	exit 1
else
	print_good "Compiled passenger."
fi

print_status "Adding passenger module to /etc/apache2.conf"

#add to apache2.conf:
echo "" >> /etc/apache2/apache2.conf
echo "# This stuff is to make Snorby work properly mod_passenger is required for snorby to work." >> /etc/apache2/apache2.conf
echo "" >> /etc/apache2/apache2.conf
echo "LoadModule passenger_module /usr/local/rvm/gems/ruby-$rubyver/gems/passenger-$passengerver/buildout/apache2/mod_passenger.so" >> /etc/apache2/apache2.conf
echo "PassengerRoot /usr/local/rvm/gems/ruby-$rubyver/gems/passenger-$passengerver" >> /etc/apache2/apache2.conf
echo "PassengerDefaultRuby /usr/local/rvm/wrappers/ruby-$rubyver/ruby" >> /etc/apache2/apache2.conf

print_good "Apache successfully configured to use passenger."

########################################

#add to sites-avaiable/snorby, disable default site. wonder if maybe I should try doing this for the other web interfaces?

print_status "Configuring apache to point to snorby's DocumentRoot as the default site."

echo "<VirtualHost *:80>" >> /etc/apache2/sites-available/snorby
echo "     ServerName snorby.localhost" >> /etc/apache2/sites-available/snorby
echo "     # !!! Be sure to point DocumentRoot to 'public'!" >> /etc/apache2/sites-available/snorby
echo "     DocumentRoot /var/www/snorby/public" >> /etc/apache2/sites-available/snorby
echo "     <Directory /var/www/snorby/public>" >> /etc/apache2/sites-available/snorby
echo "          # This relaxes Apache security settings." >> /etc/apache2/sites-available/snorby
echo "          AllowOverride all" >> /etc/apache2/sites-available/snorby
echo "          # MultiViews must be turned off." >> /etc/apache2/sites-available/snorby
echo "          Options -MultiViews" >> /etc/apache2/sites-available/snorby
echo "     </Directory>" >> /etc/apache2/sites-available/snorby
echo "</VirtualHost>" >> /etc/apache2/sites-available/snorby

print_good "Snorby's DocumentRoot set as the default site."

########################################

#The below portion are the final steps. The first thing we do is make a copy of the Gemfile.lock, and using grep -v, remove all references to psych_shield in the Gemfile.lock file. Reason for this is that bundler will bomb out because it sees an inconsistency with the Gemfile.lock and Gemfile. Grepping out psych_shield fixes that.

#The rest is to perform the final installation steps for snorby use bundler to grab the remaining gems needed and configure everything, then rake to make it run. The a2dis/ensite are to disable the default apache site and enable snorby, setting it as the default site.
#TODO:https

print_status "Running bundler."

cd /var/www/snorby

#Ran into issues with psych_shield causing bundler to bail out."

cp Gemfile.lock Gemfile.lock.bak
cat Gemfile.lock.bak | grep -v psych_shield > Gemfile.lock

bundle install --deployment &>> $snorby_logfile
if [ $? -ne 0 ]; then
	print_error "Bundler failed to run. Please see $snorby_logfile for more details."
	exit 1
else
	print_good "Bundler completed."
fi

print_status "Running rake"

rake snorby:setup &>> $snorby_logfile
if [ $? -ne 0 ]; then
	print_error "Rake failed to run. Please see $snorby_logfile for more details."
	exit 1
else
	print_good "Rake completed."
fi

########################################

#The commands below are to drop priveleges: We want to have the snort user manage the snorby database. This is done for security purposes. I'm not comfortable with the root database user's creds being in a world-readable file.

print_status "Giving permission to snort database user to manage the snorby database (dropping privs)"

mysql -uroot -p$root_pass_1 -e "grant create, insert, select, delete, update on snorby.* to snort@localhost identified by '$MYSQL_PASS_1';" &>> $snorby_logfile

print_status "Reconfiguring Snorby and Barnyard2 to work together."

sed -i 's/username: root/username: snort/' /var/www/snorby/config/database.yml
sed -i 's/password: '$root_pass_1'/password: '$MYSQL_PASS_1'/' /var/www/snorby/config/database.yml
sed -i 's/dbname=snort/dbname=snorby/' /usr/local/snort/etc/barnyard2.conf

#give www-data access to snorby's files, enable the snort site, disable the default, restart apache.

print_status "Giving ownership of /var/www/snorby to www-data user and group."

chown -R www-data:www-data /var/www/snorby/

a2dissite default &>> $snorby_logfile
if [ $? -ne 0 ]; then
	print_error "Failed to disable default site. Please see $snorby_logfile for more details."
	exit 1
else
	print_good "Default site disabled."
fi

a2ensite snorby &>> $snorby_logfile
if [ $? -ne 0 ]; then
	print_error "Failed to enable Snorby site. Please see $snorby_logfile for more details."
	exit 1
else
	print_good "Snorby site enabled and set to default. Please see $snorby_logfile for more details."
fi

service apache2 reload &>> $snorby_logfile
if [ $? -ne 0 ]; then
	print_error "Failed to restart Apache. Please see $snorby_logfile for more details."
	exit 1
else
	print_good "Apache successfully restarted."
fi

print_notification "The log file for this interface installation is located at: $snorby_logfile"

#echo "cd /var/www/snorby && ruby script/delayed_job start" >> /etc/rc.local
#echo "cd /var/www/snorby && rails runner 'Snorby::Jobs::SensorCacheJob.new(false).perform; Snorby::Jobs::DailyCacheJob.new(false).perform'" >> /etc/rc.local

#the above entries to rc.local don't actually work on boot, but if the root user actually runs those commands, it  does work... so I'm disabling the commands until a reliable method to start the delayed_job and run the cache jobs on boot is discovered.

#SSL config:
#a2enmod ssl
#a2enmod rewrite
#more to come here...

exit 0