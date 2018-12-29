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
if [ -d /var/www/html/snortreport ]; then
	print_notification "Directory exists. Deleting to prevent issues.."
	rm -rf /var/www/html/snortreport &>> $sreport_logfile
fi
if [ -d /var/www/html/jpgraph ]; then
	print_notification "Directory exists. Deleting to prevent issues.."
	rm -rf /var/www/html/jpgraph &>> $sreport_logfile
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
error_check 'jpgraph download'

print_status "Installing jpgraph.."

tar -xzvf jpgraph305.tar.gz &>> $sreport_logfile
error_check 'jpgraph installation'

rm -rf jpgraph305.tar.gz
mv jpgraph-3* jpgraph

########################################

#now to install snort report.

print_status "downloading and installing Snort Report.."

wget http://symmetrixtech.com/wp/wp-content/uploads/2014/09/snortreport-1.3.4.tar.gz &>> $sreport_logfile
error_check 'Snort Report download'

tar -xzvf snortreport-1.3.4.tar.gz &>> $sreport_logfile
error_check 'Snort Report installation'

rm -rf snortreport-1.3.4.tar.gz
mv /var/www/html/snortreport-1.3.4 /var/www/html/snortreport

########################################

print_status "Pointing Snortreport to the mysql database.."

sed -i "s/PASSWORD/$snort_mysql_pass/" /var/www/html/snortreport/srconf.php 

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
#Here we're making some virtual hosts in /etc/httpd/conf/httpd.conf to support SSL.

print_status "Adding Virtual Host settings and reconfiguring httpd to use SSL.."

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
error_check 'SELinux permission reset'

########################################
#This is to tighten file permissions on Snort Report files, especially srconf.php; it shouldn't be world-readable.

print_status "Setting file ownership for /var/www/html/snortreport, /var/www/html/jpgraph to apache; making srconf.php read-only by apache user and group.."

chown -R apache:apache /var/www/html/snortreport &>> $sreport_logfile
error_check 'Snort Report file ownership reset'

chown -R apache:apache /var/www/html/jpgraph &>> $sreport_logfile
error_check 'JPGraph file ownership reset'

chmod 400 /var/www/html/snortreport/srconf.php &>> $sreport_logfile
error_check 'srconf.php file permission reset'

service httpd restart &>> $sreport_logfile
error_check 'httpd restart'


print_notification "The log file for this interface installation is located at: $sreport_logfile"

exit 0