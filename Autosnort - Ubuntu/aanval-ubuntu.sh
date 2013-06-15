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

print_status "Grabbing packages for aanval."
#grab packages for aanval most of the primary required packages are pulled by  the main AS script. Also suppressing the message for libphpadodb
echo libphp-adodb  libphp-adodb/pathmove note | debconf-set-selections
apt-get install -y zlib1g-dev libmysqld-dev byacc libxml2-dev zlib1g php5 php5-mysql php5-gd nmap libssl-dev libcrypt-ssleay-perl libphp-adodb php-pear &>> $aanval_logfile

if [ $? != 0 ];then
	print_error "Failed to acquire required packages for Aanval. See $aanval_logfile for details."
	exit 1
else
	print_good "Successfully acquired packages."
fi

########################################

print_status "making the aanval web UI directory"

#Make the aanval directory under /var/www, and cd into it
mkdir /var/www/aanval
cd /var/www/aanval



# We need to grab aanval from the aanval.com site. If this fails, we exit the script with a status of 1
# A check needs to be built into the main script to verify this script exits cleanly. If it doesn't,
# The user should be informed and brought back to the main interface selection menu.
print_status "Grabbing aanval."
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

print_status "Configuring mysql to work with Aanval."

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

#note: need to pass off mysql_pass_1 as an environment variable in the main script:
#code: ask for snort database password, save to var MYSQL_PASS_1 (yes, case matters)
#export MYSQL_PASS_1, call it in child shell script for aanval. ($MYSQL_PASS_1)

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

print_status "Granting ownership of /var/www/aanval to www-data."

chown -R www-data:www-data /var/www/aanval

print_status "Resetting DocumentRoot to /var/www/aanval"
sed -i 's/DocumentRoot \/var\/www/DocumentRoot \/var\/www\/aanval/' /etc/apache2/sites-available/default

print_status "Starting background processors for Aanval web interface."
cd /var/www/aanval/apps
perl idsBackground.pl -start &>> $aanval_logfile
if [ $? != 0 ];then
	print_error "failed to start background processors. See $aanval_logfile for details."
	exit 1
else
	print_good "Successfully started background processors."
fi

########################################

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

print_notification "The log file for this interface installation is located at: $aanval_logfile"

exit 0