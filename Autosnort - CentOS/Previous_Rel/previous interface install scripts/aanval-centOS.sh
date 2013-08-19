#!/bin/bash
#Aanval shell script 'module'
#Sets up Aanval for for Autosnort
#WARNING: DO NOT TRY TO USE AANVAL TO MANAGE THE SENSOR!
#GETTING THIS TO ACTUALLY WORK IS GOING TO TAKE A LOT OF TIME AND EFFORT
#TO FIGURE OUT WHERE AANVAL IS TRYING TO LOOK FOR THINGS, NOT TO MENTION
#SOME RE-WORKING OF AUTOSNORT ITSELF...THIS IS STRICTLY TO GET THE IDS 
#EVENT VIEW FUNCTIONALITY WORKING.

echo "grabbing packages for aanval"
#grab packages for aanval most of the primary required packages are pulled by  the main AS script.
yum -y install perl-Crypt-SSLeay perl-libwww-perl perl-Archive-Tar perl-IO-Socket-SSL openssl-devel

echo "making the aanval web UI directory"
#Make the aanval directory under /var/www/html, and cd into it
mkdir /var/www/html/aanval
cd /var/www/html/aanval

# We need to grab aanval from the aanval.com site. If this fails, we exit the script with a status of 1
# A check needs to be built into the main script to verify this script exits cleanly. If it doesn't,
# The user should be informed and brought back to the main interface selection menu.
echo "grabbing aanval."
wget https://www.aanval.com/download/pickup -O aanval.tar.gz --no-check-certificate
if [ $? != 0 ];then
	echo "Attempt to pull down aanval console failed. Please verify network connectivity and try again."
	exit 1
else
	echo "Successfully downloaded the aanval tarball."
fi
tar -xzvf aanval.tar.gz
rm aanval.tar.gz

#Creating the database infrastructure for Aanval -- We make the database aanvaldb and give the snort user the ability to do work on it.
#This database is totally separate from the snort database, BOTH must be present.

while true; do
	echo "enter the mysql root user password to create the aanvaldb database."
	mysql -u root -p -e "create database aanvaldb;"
	if [ $? != 0 ]; then
		echo "the command did NOT complete successfully. (bad password?) Please try again."
		continue
	else
		echo "aanvaldb database created!"
		break
	fi
done

#note: need to pass off mysql_pass_1 as an environment variable in the main script:
#code: ask for snort database password, save to var MYSQL_PASS_1 (yes, case matters)
#export MYSQL_PASS_1, call it in child shell script for aanval. ($MYSQL_PASS_1)

while true; do
	echo "you'll need to enter the mysql root user password one more time to grant the snort database user permissions to the aanvaldb database."
	mysql -u root -p -e "grant create, insert, select, delete, update on aanvaldb.* to snort@localhost identified by '$MYSQL_PASS_1';"
	if [ $? != 0 ]; then
		echo "the command did NOT complete successfully. (bad password?) Please try again."
		continue
	else
		echo "database access granted!"
		break
	fi
done
echo ""
echo "modifying SELinux to allow httpd access to aanval directory and mysql database. This will take a moment or two. please be patient."
echo ""
#discovered during testing that this HAD to be set for aanval to be able to talk to the mysql database.
setsebool -P httpd_can_network_connect_db 1
#this is to ensure httpd has access to do what it needs to files in /var/www/html/aanval
cd /var/www/html
chcon -R -t httpd_sys_rw_content_t aanval/

echo ""
echo ""
echo "SELinux reconfigured. Remember: you need to poke a hole in the firewall for port 80!"
echo ""
echo ""

exit 0