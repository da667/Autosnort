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

print_status "Grabbing packages for aanval.."
yum -y install php php-common php-gd php-cli php-mysql byacc libxslt-devel php-pear.noarch php-adodb.noarch perl-Crypt-SSLeay perl-libwww-perl perl-Archive-Tar perl-IO-Socket-SSL openssl-devel mod_ssl &>> $aanval_logfile
if [ $? != 0 ];then
	print_error "Failed to acquire required packages for Aanval. See $aanval_logfile for details."
	exit 1
else
	print_good "Successfully acquired packages."
fi

########################################

#Make the aanval directory under /var/www, and cd into it
mkdir /var/www/html/aanval
cd /var/www/html/aanval



# We need to grab aanval from the aanval.com site. 
print_status "Grabbing aanval."
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
	print_good "Successfully installed aanval to /var/www/html/aanval."
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

#Here we're making some virtual hosts in /etc/httpd/conf/httpd.conf, but not before backing it up.
#We create a port 80 virtual host whose only purpose is to redirect (via mod_rewrite) to the second virtual host
#The second virtual host is configured for SSL with Perfect Forward Secrecy.
#As a part of this config, we move /etc/httpd/conf.d/ssl.conf to /etc/httpd, because the settings in that file can and will override over virtual host settings in httpd.conf.


cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.orig

print_status "Adding Virtual Host settings and reconfiguring httpd to use SSL.."

echo "LoadModule ssl_module modules/mod_ssl.so" >> /etc/httpd/conf/httpd.conf
echo "Listen 443" >> /etc/httpd/conf/httpd.conf
echo "" >> /etc/httpd/conf/httpd.conf
echo "#This VHOST exists as a catch, to redirect any requests made via HTTP to HTTPS." >> /etc/httpd/conf/httpd.conf
echo "<VirtualHost *:80>" >> /etc/httpd/conf/httpd.conf
echo "        DocumentRoot /var/www/html/aanval" >> /etc/httpd/conf/httpd.conf
echo "        #Mod_Rewrite Settings. Force everything to go over SSL." >> /etc/httpd/conf/httpd.conf
echo "        RewriteEngine On" >> /etc/httpd/conf/httpd.conf
echo "        RewriteCond %{HTTPS} off" >> /etc/httpd/conf/httpd.conf
echo "        RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI}" >> /etc/httpd/conf/httpd.conf
echo "</VirtualHost>" >> /etc/httpd/conf/httpd.conf
echo "" >> /etc/httpd/conf/httpd.conf
echo "<IfModule mod_ssl.c>" >> /etc/httpd/conf/httpd.conf
echo "	<VirtualHost *:443>" >> /etc/httpd/conf/httpd.conf
echo "		#SSL Settings, including support for PFS." >> /etc/httpd/conf/httpd.conf
echo "		SSLEngine on" >> /etc/httpd/conf/httpd.conf
echo "		SSLCertificateFile /etc/httpd/ssl/ids.cert" >> /etc/httpd/conf/httpd.conf
echo "		SSLCertificateKeyFile /etc/httpd/ssl/ids.key" >> /etc/httpd/conf/httpd.conf
echo "		SSLProtocol all -SSLv2 -SSLv3" >> /etc/httpd/conf/httpd.conf
echo "		SSLHonorCipherOrder on" >> /etc/httpd/conf/httpd.conf
echo "		SSLCipherSuite \"EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+aRSA+RC4 EECDH EDH+aRSA RC4 !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS\"" >> /etc/httpd/conf/httpd.conf
echo "" >> /etc/httpd/conf/httpd.conf
echo "		#Mod_Rewrite Settings. Force everything to go over SSL." >> /etc/httpd/conf/httpd.conf
echo "		RewriteEngine On" >> /etc/httpd/conf/httpd.conf
echo "		RewriteCond %{HTTPS} off" >> /etc/httpd/conf/httpd.conf
echo "		RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI}" >> /etc/httpd/conf/httpd.conf
echo "" >> /etc/httpd/conf/httpd.conf
echo "		#Now, we finally get to configuring our VHOST." >> /etc/httpd/conf/httpd.conf
echo "		ServerName aanval.localhost" >> /etc/httpd/conf/httpd.conf
echo "		DocumentRoot /var/www/html/aanval" >> /etc/httpd/conf/httpd.conf
echo "	</VirtualHost>" >> /etc/httpd/conf/httpd.conf
echo "</IfModule>" >> /etc/httpd/conf/httpd.conf

mv /etc/httpd/conf.d/ssl.conf /etc/httpd/sslconf.bak

print_good "httpd reconfigured."

#The remainder of the script is for permissions cleanup -- giving apache ownership of the DocumentRoot, and ensuring SELinux is configured to allow apache to perform actions required for Aanval to function properly.

print_status "Granting ownership of /var/www/html/aanval to apache.."

chown -R apache:apache /var/www/html/aanval
if [ $? != 0 ];then
	print_error "Failed to reset ownership. See $aanval_logfile for details."
	exit 1
else
	print_good "Successfully changed file ownership to apache user and group."
fi

print_status "Configuring SELinux permissions for Aanval.."
print_notification "Setsebool takes a moment or two to do its thing. Please be patient, I promise the script isn't hanging."
#discovered during testing that this HAD to be set for aanval to be able to talk to the mysql database.

setsebool -P httpd_can_network_connect_db 1
if [ $? != 0 ];then
	print_error "Failed run setsebool. See $aanval_logfile for details."
	exit 1
else
	print_good "Successfully ran setsebool to allow database connections."
fi

#this is to ensure httpd has access to do what it needs to files in /var/www/html/aanval
cd /var/www/html
chcon -R -t httpd_sys_rw_content_t aanval/
if [ $? != 0 ];then
	print_error "Failed to modify SELinux permissions. See $aanval_logfile for details."
	exit 1
else
	print_good "Successfully modified SELinux permissions."
fi

print_good "SELinux permissions successfully modified."

########################################
# The background processors are vital to Aanval working properly. They're responsible for importing data to the aanval interface.
# We start the background processors now, and ask the user if they want to add a command to start them at boot via rc.local, or if they want to handle that themselves.
# TODO: Make a full init script for this.

print_status "Starting background processors for Aanval web interface.."
cd /var/www/html/aanval/apps
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
		print_status "Adding job to start background processors on boot to /etc/rc.local.."
		echo "cd /var/www/html/aanval/apps" >> /etc/rc.local
		echo "perl idsBackground.pl -start" >> /etc/rc.local
		print_good "Successfully added background processors to rc.local."
		break
		;;
		2)
		print_notification "If the system reboots, the background processors will need to be started."
		print_notification "You can do this by running: cd /var/www/html/aanval/apps && perl idsBackground.pl -start"
		break
		;;
		*)
		print_notification "I didn't understand your response. Please try again."
		continue
		;;
	esac
done

#This restart is to make sure the configuration changes to httpd were performed succesfully and do not cause any problems starting/stopping the service.
print_status "Restarting httpd.."
service httpd restart &>> $aanval_logfile
if [ $? != 0 ];then
	print_error "httpd failed to restart. See $aanval_logfile for details."
	exit 1
else
	print_good "Successfully restarted httpd."
fi

print_notification "The log file for this interface installation is located at: $aanval_logfile"

exit 0