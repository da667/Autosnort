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
#Pre-setup. First, if the aanval directory exists, delete it. It causes more problems than it resolves, and usually only exists if the install failed in some way. Wipe it away, start with a clean slate.

if [ -d /var/www/html/aanval ]; then
	print_notification "aanval directory exists. Deleting to prevent issues.."
	rm -rf /var/www/html/aanval
fi
execdir=`pwd`
if [ ! -f $execdir/full_autosnort.conf ]; then
	print_error "full_autosnort.conf was NOT found in $execdir. This script relies HEAVILY on this config file. The main autosnort script, full_autosnort.conf and this file should be located in the SAME directory to ensure success."
	exit 1
else
	source $execdir/full_autosnort.conf
	print_good "Found config file."
fi

########################################

print_status "Grabbing packages for aanval.."
yum -y install php php-common php-gd php-cli php-mysql byacc libxslt-devel php-pear.noarch  perl-Crypt-SSLeay perl-libwww-perl perl-Archive-Tar perl-IO-Socket-SSL openssl-devel mod_ssl &>> $aanval_logfile
#second time in a row where adodb is required, but I can't get it in centOS 7
#error_check 'Package installation'
########################################

#Make the aanval directory under /var/www, and cd into it
mkdir /var/www/html/aanval
cd /var/www/html/aanval



# We need to grab aanval from the aanval.com site. 
print_status "Grabbing aanval."
wget https://www.aanval.com/download/pickup -O aanval.tar.gz --no-check-certificate &>> $aanval_logfile
error_check 'Aanval download'

print_status "Installing Aanval.."

tar -xzvf aanval.tar.gz &>> $aanval_logfile
error_check 'Aanval file install'
rm -rf aanval.tar.gz

########################################

#Creating the database infrastructure for Aanval -- We make the database aanvaldb and give the snort user the ability to do work on it.
#This database is totally separate from the snort database, BOTH must be present.

print_status "Configuring mysql to work with Aanval.."

mysql -u root -p$root_mysql_pass -e "create database aanvaldb;" &>> $aanval_logfile
error_check 'Aanval database creation'


#granting the snort user the ability to maintain the snort database so Aanval doesn't need root dba creds.

print_status "Granting snort database user permissions to operate on aanval's database.."
mysql -u root -p$root_mysql_pass -e "grant create, insert, select, delete, update on aanvaldb.* to snort@localhost identified by '$snort_mysql_pass';" &>> $aanval_logfile
error_check 'Grant permissions to aanval database'

########################################

#Here we're making some virtual hosts in /etc/httpd/conf/httpd.conf to support SSL, and ensuring proper file perms for aanval


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
echo "		ServerName aanval.localhost" >> /etc/httpd/conf/httpd.conf
echo "		DocumentRoot /var/www/html/aanval" >> /etc/httpd/conf/httpd.conf
echo "	</VirtualHost>" >> /etc/httpd/conf/httpd.conf
echo "</IfModule>" >> /etc/httpd/conf/httpd.conf

print_good "httpd reconfigured."
print_status "Granting ownership of /var/www/html/aanval to apache.."

chown -R apache:apache /var/www/html/aanval
error_check 'aanval file ownership reset'

########################################
#These are SELinux perms that Aanval requires.

print_status "Configuring SELinux permissions for Aanval.."
print_notification "Setsebool takes a moment or two to do its thing. Please be patient, I promise the script isn't hanging."

setsebool -P httpd_can_network_connect_db 1
error_check 'setsebool'

cd /var/www/html
chcon -R -t httpd_sys_rw_content_t aanval/
error_check 'SELinux permission reset'

########################################
# The background processors are vital to Aanval working properly. They're responsible for importing data to the aanval interface.
#We start the Background processors now and add either a systemd or init script depending CentOS/RHEL release.

print_status "Starting background processors for Aanval web interface.."
cd /var/www/html/aanval/apps
perl idsBackground.pl -start &>> $aanval_logfile
error_check 'aanval background processor initialization'

print_status "Adding init/systemd script for aanval background processors.."

#This is code to check what centOS release it is we're running on and copy either the sys V init script and include it, or the systemd script for aanval's BPUs. We do some checks to make sure the systemd/init script are in the same directory the aanval installer script is in.

cd $execdir
release=`grep -oP '(?<!\.)[67]\.[0-9]+(\.[0-9]+)?' /etc/redhat-release | cut -d"." -f1`

if [[ "$release" -ge "7" ]]; then
	if [ -f /usr/lib/systemd/system/aanvalbpu.service ]; then
		print_notification "aanvalbpu.service systemd script is already installed."
	else
		print_notification "Installing aanvalbpu.service.."
		if [ ! -f $execdir/aanvalbpu.service ]; then
			print_error "The aanvalbpu.service file was not found in $execdir. Please make sure the file is there and try again."
			exit 1
		else
			print_good "Found aanvalbpu.service systemd script."
		fi
		cp aanvalbpu.service /usr/lib/systemd/system/aanvalbpu.service &>> $aanval_logfile
		chown root:root /usr/lib/systemd/system/aanvalbpu.service &>> $aanval_logfile
		chmod 644 /usr/lib/systemd/system/aanvalbpu.service &>> $aanval_logfile
		systemctl enable aanvalbpu.service &>> $aanval_logfile
		error_check 'Systemd service install'
		print_notification "aanvalbpu.service located in /lib/systemd/system/aanvalbpu.service"
	fi
else
	if [ -f /etc/init.d/aanvalbpu ]; then
		print_notification "aanvalbpu init script already installed."
	else
		if [ ! -f $execdir/aanvalbpu ]; then
			print_error "The aanvalbpu file was not found in $execdir. Please make sure the file is there and try again."
			exit 1
		else
			print_good "Found aanvalbpu init script."
		fi
		cp aanvalbpu /etc/init.d/aanvalbpu &>> $aanval_logfile
		chown root:root /etc/init.d/aanvalbpu &>> $aanval_logfile
		chmod 700 /etc/init.d/aanvalbpu &>> $aanval_logfile
		chkconfig aanvalbpu --add &>> $aanval_logfile
		chkconfig aanvalbpu --level 345 on &>> $aanval_logfile
		error_check 'Init Script creation'
		print_notification "aanvalbpu init script located in /etc/init.d/aanvalbpu"
	fi
fi

########################################
#This restart is to make sure the configuration changes to httpd were performed succesfully and do not cause any problems starting/stopping the service.
print_status "Restarting httpd.."
service httpd restart &>> $aanval_logfile
error_check 'httpd restart'

print_notification "The log file for this interface installation is located at: $aanval_logfile"

exit 0