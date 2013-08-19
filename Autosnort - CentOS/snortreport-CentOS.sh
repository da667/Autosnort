#!/bin/bash
#Snortreport shell script 'module'
#Sets up snortreport for Autosnort on CentOS Systems
#modified on 08/15. Not yet tested.

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

print_status "Installing packages for Snortreport."

yum -y install php php-common php-gd php-cli php-mysql &>> $sreport_logfile
if [ $? != 0 ];then
	print_error "Failed to acquire required packages for Snortreport. See $sreport_logfile for details."
	exit 1
else
	print_good "Successfully acquired packages."
fi

########################################

#Grab jpgraph and throw it in /var/www/html
#Required to display graphs in snort report UI

print_status "Downloading and installing jpgraph."

cd /var/www/html

wget http://hem.bredband.net/jpgraph/jpgraph-1.27.1.tar.gz &>> $sreport_logfile
if [ $? != 0 ];then
	print_error "Attempt to pull down jpgraph failed. See $sreport_logfile for details."
	exit 1
else
	print_good "Successfully downloaded jpgraph."
fi

print_status "Installing jpgraph."

tar -xzvf jpgraph-1.27.1.tar.gz &>> $sreport_logfile
if [ $? != 0 ];then
	print_error "Attempt to install jpgraph failed. See $sreport_logfile for details."
	exit 1
else
	print_good "Successfully installed jpgraph."
fi

rm -rf jpgraph-1.27.1.tar.gz
mv jpgraph-1.27.1 jpgraph

########################################

#now to install snort report.

print_status "downloading and installing Snortreport."


wget http://www.symmetrixtech.com/ids/snortreport-1.3.3.tar.gz &>> $sreport_logfile
if [ $? != 0 ];then
	print_error "Attempt to pull down Snortreport failed. See $sreport_logfile for details."
	exit 1
else
	print_good "Successfully downloaded Snortreport."
fi

tar -xzvf snortreport-1.3.3.tar.gz &>> $sreport_logfile
if [ $? != 0 ];then
	print_error "Attempt to install Snort Report failed. See $sreport_logfile for details."
	exit 1
else
	print_good "Successfully installed Snortreport."
fi

rm -rf snortreport-1.3.3.tar.gz
mv /var/www/html/snortreport-1.3.3 /var/www/html/snortreport

########################################

print_status "Pointing Snortreport to the mysql database."

sed -i 's/YOURPASS/'$MYSQL_PASS_1'/' /var/www/html/snortreport/srconf.php

print_good "Snortreport successfully configured to talk to mysql database."

########################################

#known problem with snort report 1.3.3 not playing nice on systems that have the short_open_tag directive in php.ini set to off -- READ:Debian by default. Give the user a choice if they want the script to automatically resolve this, or if they plan on adding in proper php open tags on their own.

print_notification "Would you like me to to set the short_open_tag directive in php.ini to on for snort report?"
print_notification "Please see http://autosnort.blogspot.com/2012/11/how-to-fix-problems-with-snort-report.html as to why this is important."
while true; do
	read -p "
Select 1 for autosnort to enable short_open_tag automagically
Select 2 to continue if you plan on reconfiguring the php scripts with short open tags manually
" srecon
	case $srecon in
		1 )
		print_status "Reconfiguring php.ini..."
		sed -i 's/short\_open\_tag \= Off/short\_open\_tag \= On/' /etc/php.ini
		print_good "php.ini successfully reconfigured."
		break
		;;
		2 )
		echo ""
		print_notification "You have chosen to not enable short open tags." 
		print_notification "You'll need to modify the offending php pages to remove the short open tags contained on those pages in order for the web pages to render properly."
		break
		;;
		* )
		echo ""
		print_notification "Invalid choice. Please try again."
		;;
	esac
done

########################################

#there's no default site config in CentOS httpd. The default site is defined in /etc/httpd/conf/httpd.conf, so that's the file we're editing. As such, I'm inclined to make a backup of the original config.
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.orig
print_status "Resetting default site DocumentRoot and Directory Permissions to /var/www/html/snortreport"
sed -i 's#/var/www/html#/var/www/html/snortreport#g' /etc/httpd/conf/httpd.conf

print_status "Reconfiguring SELinux Permissions to allow httpd r/w access to the snortreport directory."
chcon -R -t httpd_sys_rw_content_t snortreport/

print_good "SELinux permissions successfully modified."

print_notification "The log file for this interface installation is located at: $sreport_logfile"

exit 0