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

print_status "Installing packages for Snort Report.."

yum -y install php php-common php-gd php-cli php-mysql &>> $sreport_logfile
if [ $? != 0 ];then
	print_error "Failed to acquire required packages for Snort Report. See $sreport_logfile for details."
	exit 1
else
	print_good "Successfully acquired packages."
fi

########################################

#Grab jpgraph and throw it in /var/www/html
#Required to display graphs in snort report UI

print_status "Downloading and installing jpgraph.."

cd /var/www/html

wget http://jpgraph.net/download/download.php?p=5 -O jpgraph305.tar.gz &>> $sreport_logfile
if [ $? != 0 ];then
	print_error "Attempt to pull down jpgraph failed. See $sreport_logfile for details."
	exit 1
else
	print_good "Successfully downloaded jpgraph."
fi

print_status "Installing jpgraph.."

tar -xzvf jpgraph305.tar.gz &>> $sreport_logfile
if [ $? != 0 ];then
	print_error "Attempt to install jpgraph failed. See $sreport_logfile for details."
	exit 1
else
	print_good "Successfully installed jpgraph."
fi

rm -rf jpgraph305.tar.gz
mv jpgraph-3* jpgraph

########################################

#now to install snort report.

print_status "downloading and installing Snort Report.."


wget http://www.symmetrixtech.com/ids/snortreport-1.3.4.tar.gz &>> $sreport_logfile
if [ $? != 0 ];then
	print_error "Attempt to pull down Snortreport failed. See $sreport_logfile for details."
	exit 1
else
	print_good "Successfully downloaded Snort Report."
fi

tar -xzvf snortreport-1.3.4.tar.gz &>> $sreport_logfile
if [ $? != 0 ];then
	print_error "Attempt to install Snort Report failed. See $sreport_logfile for details."
	exit 1
else
	print_good "Successfully installed Snort Report."
fi

rm -rf snortreport-1.3.4.tar.gz
mv /var/www/html/snortreport-1.3.4 /var/www/html/snortreport

########################################

print_status "Pointing Snortreport to the mysql database.."

sed -i 's/PASSWORD/'$MYSQL_PASS_1'/' /var/www/html/snortreport/srconf.php

print_good "Snort Report successfully configured to talk to mysql database."

########################################

# Snort Report is littered with short open tags.
# sed statement 1 removes all short open tags, but breaks some things.
# sed statement 2 fixes some of the things that sed statement 1 mistakenly replaced
# sed statement 3 fixes all instances of <?= that sed statement 1 mistakenly replaced
# end product: no short open tags, no need to turn on the short open tags directive in php.ini


print_status "Fixing short open tags.."

cd /var/www/html/snortreport

for s_open_file in `ls -1 *.php`; do 
	sed -i 's#<?#<?php#g' $s_open_file
	sed -i 's#<?phpphp#<?php#g' $s_open_file
	sed -i 's#<?php=#<?php echo #g' $s_open_file
done

print_good "Short open tags fixed."


########################################
#Here we're making some virtual hosts in /etc/httpd/conf/httpd.conf, but not before backing it up.
#We create a port 80 virtual host whose only purpose is to redirect (via mod_rewrite) to the second virtual host
#The second virtual host is configured for SSL with Perfect Forward Secrecy.
#As a part of this config, we move /etc/httpd/conf.d/ssl.conf to /etc/httpd, because the settings in that file can and will override over virtual host settings in httpd.conf.

print_status "Adding Virtual Host settings and reconfiguring httpd to use SSL.."

echo "LoadModule ssl_module modules/mod_ssl.so" >> /etc/httpd/conf/httpd.conf
echo "Listen 443" >> /etc/httpd/conf/httpd.conf
echo "" >> /etc/httpd/conf/httpd.conf
echo "#This VHOST exists as a catch, to redirect any requests made via HTTP to HTTPS." >> /etc/httpd/conf/httpd.conf
echo "<VirtualHost *:80>" >> /etc/httpd/conf/httpd.conf
echo "        DocumentRoot /var/www/html/snortreport" >> /etc/httpd/conf/httpd.conf
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
echo "		ServerName snortreport.localhost" >> /etc/httpd/conf/httpd.conf
echo "		DocumentRoot /var/www/html/snortreport" >> /etc/httpd/conf/httpd.conf
echo "	</VirtualHost>" >> /etc/httpd/conf/httpd.conf
echo "</IfModule>" >> /etc/httpd/conf/httpd.conf

print_good "httpd reconfigured."

########################################

print_status "Reconfiguring SELinux Permissions to allow httpd r/w access to the snortreport directory.."
cd /var/www/html
chcon -R -t httpd_sys_rw_content_t snortreport/ &>> $sreport_logfile
if [ $? != 0 ];then
	print_error "Failed to reset SELinux permissions. See $sreport_logfile for details."
	exit 1
else
	print_good "Successfully reset SELinux permissions."
fi

########################################
#This is to tighten file permissions on Snort Report files, especially srconf.php; it shouldn't be world-readable.

print_status "Setting file ownership for /var/www/html/snortreport, /var/www/html/jpgraph to apache; making srconf.php read-only by apache user and group.."

chown -R apache:apache /var/www/html/snortreport &>> $sreport_logfile
if [ $? != 0 ];then
	print_error "Failed to reset ownership of /var/www/html/snortreport. See $sreport_logfile for details."
	exit 1
else
	print_good "Successfully changed file ownership of /var/www/html/snortreport to apache user and group."
fi

chown -R apache:apache /var/www/html/jpgraph &>> $sreport_logfile
if [ $? != 0 ];then
	print_error "Failed to reset ownership of /var/www/html/jpgraph. See $sreport_logfile for details."
	exit 1
else
	print_good "Successfully changed file ownership of /var/www/html/jpgraph to apache user and group."
fi

chmod 400 /var/www/html/snortreport/srconf.php &>> $sreport_logfile
if [ $? != 0 ];then
	print_error "Failed to reset ownership of /var/www/html/snortreport/srconf.php. See $sreport_logfile for details."
	exit 1
else
	print_good "Successfully changed file permissions of /var/www/html/snortreport/srconf.php."
fi

service httpd restart &>> $sreport_logfile
if [ $? != 0 ];then
	print_error "httpd failed to restart. See $sreport_logfile for details."
	exit 1
else
	print_good "Successfully restarted httpd."
fi


print_notification "The log file for this interface installation is located at: $sreport_logfile"

exit 0