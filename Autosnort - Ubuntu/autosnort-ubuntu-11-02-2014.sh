#!/bin/bash
#Autosnort script for Ubuntu 12.04+

#Functions, functions everywhere.

# Logging setup. Ganked this entirely from stack overflow. Uses FIFO/pipe magic to log all the output of the script to a file. Also capable of accepting redirects/appends to the file for logging compiler stuff (configure, make and make install) to a log file instead of losing it on a screen buffer. This gives the user cleaner output, while logging everything in the background, for troubleshooting, analysis, or sending it to me for help.

logfile=/var/log/autosnort_install.log
mkfifo ${logfile}.pipe
tee < ${logfile}.pipe $logfile &
exec &> ${logfile}.pipe
rm ${logfile}.pipe

########################################

#metasploit-like print statements. Gratuitously ganked from  Darkoperator's metasploit install script. status messages, error messages, good status returns. I added in a notification print for areas users should definitely pay attention to.

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

#Script does a lot of error checking. Decided to insert an error check function. If a task performed returns a non zero status code, something very likely went wrong.

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
#Package installation function.

function install_packages()
{

apt-get update &>> $logfile && apt-get install -y ${@} &>> $logfile
error_check 'Package installation'

}

########################################
#This is a postprocessing function that should get ran after pulled pork is ran. The code is identical in all cases, so it made sense to made a function for code re-use.
#This block of code notifies the user where pulledpork is installed, removes dummy files for so rule stub generation and replaces them with valid snort configuration files (e.g. classification.config, etc.).
#Change with rule tarballs around snort 2.9.6.0 or so: gen-msg.map is no longer distrbuted with rule tarballs. Change to the script to copy it from the source tarball etc directory.

function pp_postprocessing()
{

print_good "Rules processed successfully. Rules located in $snort_basedir/rules."
print_notification "Pulledpork is located in /usr/src/pulledpork-[pulledpork version]."
print_notification "By default, Autosnort runs Pulledpork with the Security over Connectivity ruleset."
print_notification "If you want to change how pulled pork operates and/or what rules get enabled/disabled, Check out the /usr/src/pulledpork-[pulledpork version]/etc directory, and the .conf files contained therein."

#This cleans up all the dummy files in the snort config file directory, with the exception of the ones we want the script to keep in place.
for configs in `ls -1 $snort_basedir/etc/* | egrep -v "snort.conf|sid-msg.map"`; do
	rm -rf $configs
done

print_status "Moving other snort configuration files.."
cd /tmp
tar -xzvf snortrules-snapshot-*.tar.gz &>> $logfile

for conffiles in `ls -1 /tmp/etc/* | egrep -v "snort.conf|sid-msg.map"`; do
	cp $conffiles $snort_basedir/etc
done

cp /usr/src/$snortver/etc/gen-msg.map $snort_basedir/etc

#Restores /etc/crontab_bkup if it exists. This is to prevent dupe crontab entries.

if [ -f /etc/crontab_bkup ]; then
	print_notification "Found /etc/crontab_bkup. Restoring original crontab to prevent duplicate cron entries.."
	cp /etc/crontab_bkup /etc/crontab
	chmod 644 /etc/crontab
	error_check 'crontab restore'
fi

print_status "Backup up crontab to /etc/crontab_bkup.."

cp /etc/crontab /etc/crontab_bkup
chmod 600 /etc/crontab_bkup
error_check 'crontab backup'

print_status "Adding entry to /etc/crontab to run pulledpork Sunday at midnight (once weekly).."

echo "#This line has been added by Autosnort to run pulledpork for the latest rule updates." >> /etc/crontab
echo "  0  0  *  *  7  root /usr/src/pulledpork-*/pulledpork.pl -c /usr/src/pulledpork-*/etc/pulledpork.conf" >> /etc/crontab

print_notification "crontab has been modified. If you want to modify when pulled pork runs to check rule updates, modify /etc/crontab."

}

#This script creates a lot of directories by default. This is a function that checks if a directory already exists and if it doesn't creates the directory (including parent dirs if they're missing).

function dir_check()
{

if [ ! -d $1 ]; then
	print_notification "$1 does not exist. Creating.."
	mkdir -p $1
else
	print_notification "$1 already exists. (No problem, We'll use it anyhow)"
fi

}

########################################
##BEGIN MAIN SCRIPT##

#Pre checks: These are a couple of basic sanity checks the script does before proceeding.

########################################

#These lines establish where autosnort was executed. The config file _should_ be in this directory. the script exits if the config isn't in the same directory as the autosnort-ubuntu shell script.

print_status "Checking for config file.."
execdir=`pwd`
if [ ! -f $execdir/full_autosnort.conf ]; then
	print_error "full_autosnort.conf was NOT found in $execdir. The script relies HEAVILY on this config file. Please make sure it is in the same directory you are executing the full-autosnort-kali script!"
	exit 1
else
	print_good "Found config file."
fi

source $execdir/full_autosnort.conf

########################################

print_status "OS Version Check.."
release=`lsb_release -r|awk '{print $2}'`
if [[ $release == "12."* || $release == "14."* ]]; then
	print_good "OS is Ubuntu. Good to go."
else
    print_notification "This is not Ubuntu 12.x or 14.x, this autosnort script has NOT been tested on other platforms."
	print_notification "You continue at your own risk!(Please report your successes or failures!)"

fi

########################################

print_status "Checking for root privs.."
if [ $(whoami) != "root" ]; then
	print_error "This script must be ran with sudo or root privileges."
	exit 1
else
	print_good "We are root."
fi
	 
########################################	 

print_status "Checking to ensure sshd is running.."

print_notification "`service ssh status`"

########################################

print_status "Wget check.."

which wget 2>&1 >> /dev/null
if [ $? -ne 0 ]; then
    print_error "Wget not found." 
	print_notification "Installing wget."
	install_packages wget
else
    print_good "Found wget."
fi

########################################
#this is a nice little hack I found in stack exchange to suppress messages during package installation.
export DEBIAN_FRONTEND=noninteractive

# System updates
print_status "Performing apt-get update and upgrade (May take a while if this is a fresh install).."
apt-get update &>> $logfile && apt-get -y upgrade &>> $logfile
error_check 'System updates'

########################################

#These packages are required at a minimum to build snort and barnyard + their component libraries

print_status "Installing base packages: ethtool build-essential libpcap0.8-dev libpcre3-dev bison flex autoconf libtool libmysqlclient-dev libnetfilter-queue-dev libnetfilter-queue1 libnfnetlink-dev libnfnetlink0 libarchive-tar-perl libcrypt-ssleay-perl libwww-perl.."

declare -a packages=( ethtool build-essential libpcap0.8-dev libpcre3-dev bison flex autoconf libtool libmysqlclient-dev libnetfilter-queue-dev libnetfilter-queue1 libnfnetlink-dev libnfnetlink0 libarchive-tar-perl libcrypt-ssleay-perl libwww-perl );
install_packages ${packages[@]}

########################################

#This is where the user decides whether or not they want a full stand-alone sensor or a barebones/distributed installation sensor. If they opt to install apache and mysql, we generate a self-signed ssl cert and private key. We then back up the default ssl and sites-available/default site, then make some customizations.

case $ui_inst in
	1)
	print_status "Acquiring and installing mysql-server and apache2.."
	declare -a packages=( mysql-server apache2 );
	install_packages ${packages[@]}
	
	print_status "Updating init entries for mysql and apache for auto-start.."
	
	update-rc.d mysql enable &>> $logfile
	error_check 'Update of mysql init entry'
	
	update-rc.d apache2 enable &>> $logfile
	error_check	'Update of apache init entry'
	
	print_status "Starting apache and mysql services.."
	
	service apache2 start &>> $logfile
	service mysql start &>> $logfile

	print_status "Running mysql_secure_installation script commands.."
	
	#These are equivalent commands to the mysql_secure_installation script that perform all the same actions automatically with no prompts.
	
	mysqladmin -uroot password $root_mysql_pass &>> $logfile
	
	mysql -uroot -p$root_mysql_pass -e "DELETE FROM mysql.user WHERE User=''; DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1'); DROP DATABASE IF EXISTS test; DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'; FLUSH PRIVILEGES;" &>> $logfile
	error_check 'mysql_secure_installation commands'
	
	#We make /etc/apache2/ssl and set strict r/w/x permissions for root only in the directory. 
	#Afterwards, we generate a self-signed certificate and private key, putting strict permissions on those as well.
	#We back up the ssl.conf, default and default-ssl sites, then we write our own ssl.conf, to utilize our private key and certificate. Ubuntu 14.04 uses apache 2.4 and because of that... all vhosts need to end in ".conf" so we have logic to handle backing Ubuntu 12.x, 14.x and any other cases as necessary.
	#Finally, we enable mod_ssl and mod_rewrite to handle SSL operation and redirection of any HTTP users to HTTPS.
	
	print_status "Generating a private key and self-signed SSL certificate for HTTPS operation.."
	dir_check /etc/apache2/ssl
	
	chmod 700 /etc/apache2/ssl
	cd /etc/apache2/ssl
	
	openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=Nevada/L=LasVegas/O=Security/CN=`hostname`" -keyout ids.key  -out ids.cert &>> $logfile
	error_check 'SSL certificate and key generation'
	print_good "SSL private key location: /etc/apache2/ssl/ids.key"
	print_good "SSL certificate location: /etc/apache2/ssl/ids.cert"
	
	chmod 600 /etc/apache2/ssl/ids.*
	
	print_status "Backing up default ssl.conf, default virtual host file, and replacing ssl.conf.."
	
	#This section is to handle the different default file names for Ubuntu 12.x and 14.x. They need to be moved out of the way/backed up to prevent them from interfering with web interface operation.
	
	ubun_maj_ver=`lsb_release -r | egrep -o "12|14"`
	if [[ "$ubun_maj_ver" -eq "12" ]]; then
		if [ -f /etc/apache2/defaultsiteconfbak ]; then
			print_notification "Original default site already backed up."
		else
			print_status "Backing up and deactivating default and default-ssl vhosts.."
			a2dissite default &>> $logfile
			mv /etc/apache2/sites-available/default /etc/apache2/defaultsiteconfbak &>> $logfile
		fi
		if [ -f /etc/apache2/sites-available/default-ssl ]; then
			mv /etc/apache2/sites-available/default-ssl /etc/apache2/default-sslsiteconfbak
		fi
	elif [[ "$ubun_maj_ver" -eq "14" ]]; then
		if [ -f /etc/apache2/000-defaultsiteconfbak ]; then
			print_notification "Original default site already backed up."
		else
			print_status "Backing up and deactivating default and default-ssl vhosts.."
			a2dissite 000-default.conf &>> $logfile
			mv /etc/apache2/sites-available/000-default.conf /etc/apache2/000-defaultsiteconfbak
		fi
		if [ -f /etc/apache2/sites-available/default-ssl.conf ]; then
			mv /etc/apache2/sites-available/default-ssl.conf /etc/apache2/default-sslsiteconfbak
		fi
	else
		if [ -f /etc/apache2/defaultsiteconfbak ]; then
		print_notification "Original default site already backed up."
		else
			print_status "Backing up and deactivating default and default-ssl vhosts.."
			a2dissite default &>> $logfile
			mv /etc/apache2/sites-available/default /etc/apache2/defaultsiteconfbak &>> $logfile
		fi
		if [ -f /etc/apache2/sites-available/default-ssl ]; then
			mv /etc/apache2/sites-available/default-ssl /etc/apache2/default-sslsiteconfbak
		fi
	fi
	
	if [ -f /etc/apache2/mods-available/ssl.conf ]; then
		mv /etc/apache2/mods-available/ssl.conf /etc/apache2/defaultsslconfbak
		
	fi	
	#ssl.conf config options for Debian-based Distros.
	
	echo "#This ssl.conf was generated by autosnort. To remove, run cp /etc/apache2/sslconfbak /etc/apache2/mods-available/ssl.conf to reset to defaults." > /etc/apache2/mods-available/ssl.conf
	echo "<IfModule mod_ssl.c>" >> /etc/apache2/mods-available/ssl.conf
	echo "	SSLRandomSeed startup builtin" >> /etc/apache2/mods-available/ssl.conf
	echo "	SSLRandomSeed startup file:/dev/urandom 512" >> /etc/apache2/mods-available/ssl.conf
	echo "	SSLRandomSeed connect builtin" >> /etc/apache2/mods-available/ssl.conf
	echo "	SSLRandomSeed connect file:/dev/urandom 512" >> /etc/apache2/mods-available/ssl.conf
	echo "	AddType application/x-x509-ca-cert .crt" >> /etc/apache2/mods-available/ssl.conf
	echo "	AddType application/x-pkcs7-crl    .crl" >> /etc/apache2/mods-available/ssl.conf
	echo "	SSLSessionCache        shmcb:\${APACHE_RUN_DIR}/ssl_scache(512000)" >> /etc/apache2/mods-available/ssl.conf
	echo "	SSLSessionCacheTimeout  300" >> /etc/apache2/mods-available/ssl.conf
	echo "	SSLCertificateFile /etc/apache2/ssl/ids.cert" >> /etc/apache2/mods-available/ssl.conf
	echo "	SSLCertificateKeyFile /etc/apache2/ssl/ids.key" >> /etc/apache2/mods-available/ssl.conf
	echo "	SSLProtocol all -SSLv2 -SSLv3" >> /etc/apache2/mods-available/ssl.conf
	echo "	SSLHonorCipherOrder on" >> /etc/apache2/mods-available/ssl.conf
	echo "	SSLCipherSuite \"EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+aRSA+RC4 EECDH EDH+aRSA RC4 !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS \"" >> /etc/apache2/mods-available/ssl.conf
	echo "</IfModule>" >> /etc/apache2/mods-available/ssl.conf
	
	print_good "moved ssl.conf, default and default-ssl sites."
	
	print_status "Enabling mod_ssl.."
	a2enmod ssl &>> $logfile
	error_check 'Enabling of mod_ssl'
	
	print_status "Enabling mod_rewrite.."	
	a2enmod rewrite &>> $logfile
	error_check 'Enabling of mod_rewrite'
	
	#These are configuration options that are dropped into /etc/apache2/sites-available/default. These options act as a catch-all for unencrypted HTTP traffic. This vhost catches the unencrypted traffic and redirects it to HTTPS, enforcing web interface encryption.
	
	echo "#This default vhost config geneated by autosnort. To remove, run cp /etc/apache2/defaultsiteconfbak /etc/apache2/sites-available/default or cp /etc/apache2/000-defaultsiteconfbak /etc/apache2/sites-available/000-default.conf (if ubuntu 14.04+)" > /etc/apache2/sites-available/default.conf
	echo "#This VHOST exists as a catch, to redirect any requests made via HTTP to HTTPS." >> /etc/apache2/sites-available/default.conf
	echo "<VirtualHost *:80>" >> /etc/apache2/sites-available/default.conf
	echo "        #Mod_Rewrite Settings. Force everything to go over SSL." >> /etc/apache2/sites-available/default.conf
	echo "        RewriteEngine On" >> /etc/apache2/sites-available/default.conf
	echo "        RewriteCond %{HTTPS} off" >> /etc/apache2/sites-available/default.conf
	echo "        RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI}" >> /etc/apache2/sites-available/default.conf
	echo "</VirtualHost>" >> /etc/apache2/sites-available/default.conf
	a2ensite default.conf &>> $logfile
	error_check 'enable of autosnort default site'
	;;	
	
	2)
	print_notification "Apache and Mysql will not be configured to start on boot. No web interface will be installed."
	;;	
	
	*)
	print_notification "Invalid choice, Check your full_autosnort.conf file and try again."
	exit 1
	;;
esac

########################################
# We download the index page from snort.org
# Then using shell text manipulation tools (grep, cut, sed, head, tail) we pull:
# The snort and daq version to download
# Some text manipulation to pull a snort.conf file versions to download from labs.snort.org
# The last four supported snort rule tarball versions

print_status "Checking latest versions of Snort, Daq and Rules via snort.org..."

cd /tmp
wget https://www.snort.org -O /tmp/snort &> $logfile
error_check 'Download of www.snort.org index page'

snorttar=`grep snort-[0-9] /tmp/snort | grep .tar.gz | tail -1 | cut -d"/" -f4 | cut -d\" -f1`
daqtar=`grep daq-[0-9] /tmp/snort | grep .tar.gz | tail -1 | cut -d"/" -f4 | cut -d\" -f1`
snortver=`echo $snorttar | sed 's/.tar.gz//g'`
daqver=`echo $daqtar | sed 's/.tar.gz//g'`
choice1conf=`grep snortrules-snapshot-[0-9][0-9][0-9][0-9] /tmp/snort |cut -d"-" -f3 |cut -d"." -f1 | sort -ur | head -1` #snort.conf download attempt 1
choice2conf=`grep snortrules-snapshot-[0-9][0-9][0-9][0-9] /tmp/snort |cut -d"-" -f3 |cut -d"." -f1 | sort -ur | head -2 | tail -1` #snort.conf download attempt 2
choice1=`echo $choice1conf |sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./'` #pp config choice 1
choice2=`echo $choice2conf | sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./'` #pp config choice 2
choice3=`grep snortrules-snapshot-[0-9][0-9][0-9][0-9] /tmp/snort |cut -d"-" -f3 |cut -d"." -f1 | sort -ru | head -3 | tail -1 | sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./'`
choice4=`grep snortrules-snapshot-[0-9][0-9][0-9][0-9] /tmp/snort |cut -d"-" -f3 |cut -d"." -f1 | sort -ru | head -4| tail -1 | sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./'`

rm /tmp/snort
cd /usr/src

########################################
#libdnet is a library required for snort. Grab, unpack, build, install.

print_status "Acquiring and unpacking libdnet 1.12 to /usr/src.."

cd /usr/src
wget http://libdnet.googlecode.com/files/libdnet-1.12.tgz &>> $logfile
error_check 'Download of libdnet'

tar -xzvf libdnet-1.12.tgz &>> $logfile
error_check 'Untar of libdnet'

cd libdnet-1.12

print_status "Configuring, making, compiling and linking libdnet. This will take a moment or two.."

#The CFLAGS are required to compile libdnet the right way so that DAQ will compile properly with NFQUEUE support enabled.

./configure "CFLAGS=-fPIC -g -O2" &>> $logfile
error_check 'Configure libdnet'

make &>> $logfile
error_check 'Make libdnet'

make install &>> $logfile
error_check 'Installation of libdnet'

#this is in regards to the fix posted in David Gullett's snort guide - /usr/local/lib isn't include in ld path by default in Ubuntu. 
#Don't know if this is relevant for Kali, but it hasn't hurt implementing it.

if [ ! -h /usr/lib/libdnet.1 ]; then
print_status "Creating symlink for libdnet on default ld library path.."
ln -s /usr/local/lib/libdnet.1.0.1 /usr/lib/libdnet.1
fi

cd /usr/src

########################################
#Download, extract, build and install Daq Libraries.

print_status "Acquiring and unpacking $daqver to /usr/src.."

wget https://www.snort.org/downloads/snort/$daqtar -O $daqtar &>> $logfile
error_check 'Download of DAQ'

tar -xzvf $daqtar &>> $logfile
error_check 'Untar of DAQ'

cd $daqver

print_status "Configuring, making, compiling and linking DAQ libraries. This will take a moment or two.."

./configure &>> $logfile
error_check 'Configure DAQ'

make &>> $logfile
error_check 'Make DAQ'

make install &>> $logfile
error_check 'Installation of DAQ libraries'

#seen some strange happenings where if this isn't symlinked or in /usr/lib, snort fails to find it and subsequently bails.

if [ ! -h /usr/lib/libsfbpf.so.0 ]; then
print_status "Creating symlink for libsfbpf.so.0 on default ld library path.."
ln -s /usr/local/lib/libsfbpf.so.0 /usr/lib/libsfbpf.so.0
fi

cd /usr/src

########################################
#This is where snort actually gets installed. We create the directory the user wants to install snort in (if it doesn't exist), Download, Unpack, build, compile and install.
#Afterwards we create a snort system user to drop privs down to when snort is running, the snort group, and a /var/log/snort for writing unified 2 files.
#The --prefix option is based on where the user wants to install snort, while --enable-sourcefire provides most of the Snort options users desire.

print_status "Acquiring and unpacking $snortver to /usr/src.."

wget https://www.snort.org/downloads/snort/$snorttar -O $snorttar &>> $logfile
error_check 'Download of Snort'

tar -xzvf $snorttar &>> $logfile
error_check 'Untar of Snort'

dir_check $snort_basedir

cd $snortver

print_status "configuring snort (options --prefix=$snort_basedir and --enable-sourcefire), making and installing. This will take a moment or two."

./configure --prefix=$snort_basedir --enable-sourcefire &>> $logfile
error_check 'Configure Snort'

make &>> $logfile
error_check 'Make Snort'

make install &>> $logfile
error_check 'Installation of Snort'

dir_check /var/log/snort

print_status "Checking for snort user and group.."

getent passwd snort &>> $logfile
if [ $? -eq 0 ]; then
	print_notificiation "snort user exists. Verifying group exists.."
	id -g snort &>> $logfile
	if [ $? -eq 0 ]; then
		print_notification "snort group exists."
	else
		print_noficiation "snort group does not exist. Creating.."
		groupadd snort
		usermod -G snort snort
	fi
else
	print_status "Creating snort user and group.."
	groupadd snort
	useradd -g snort snort -s /bin/false	
fi

print_status "Tightening permissions to /var/log/snort.."
chmod 770 /var/log/snort
chown snort:snort /var/log/snort

########################################
#This block of code gets very very hairy, very very fast.
#1. Setup necessary directory structure for snort (make them if they don't exist)
#2. Determine latest the last 4 versions of snort tarballs, and last 2 snort releases
#3. Download a reference snort.conf from labs.snort.org for the current (if available) release or snort, or the one prior
#4. Modify snort.conf as necessary, and generate some dummy files in place to ensure snort doesn't barf generate SO rule stub files.
#5. Grab pulled pork, the packages required to run it, and generate a skeleton pulledpork.conf (while leaving the original intact)
#6. Grab rules via pulled pork. SHOULD support so rules, if the user has a VRT subscription for the current snort release OR the current snort release is more than 30 days old (at which point, the snort tarball release 30 days ago is made free, and the SO rules are compatible)
#7. Replace dummy files, and copy gen-msp.map from snort tarball.

dir_check $snort_basedir/etc
dir_check $snort_basedir/so_rules
dir_check $snort_basedir/rules
dir_check $snort_basedir/preproc_rules
dir_check $snort_basedir/snort_dynamicrules

print_status "Attempting to download snort.conf for $choice1.."

wget https://labs.snort.org/snort/$choice1conf/snort.conf -O $snort_basedir/etc/snort.conf --no-check-certificate &>> $logfile

if [ $? != 0 ];then
	print_error "Attempt to download $choice1 snort.conf from labs.snort.org failed. attempting to download snort.conf for $choice2.."
	wget https://labs.snort.org/snort/$choice2conf/snort.conf -O $snort_basedir/etc/snort.conf --no-check-certificate &>> $logfile
	error_check 'Download of secondary snort.conf'
else
	print_good "Successfully downloaded snort.conf for $choice1."
fi

#Trim up snort.conf as necessary to work properly. Snort is actually executed by pulled pork to dump the SO stub files for shared object rules.

print_status "ldconfig processing and creation of whitelist/blacklist.rules files taking place."

touch $snort_basedir/rules/white_list.rules
touch $snort_basedir/rules/black_list.rules
ldconfig

print_status "Modifying snort.conf -- specifying unified 2 output, SO whitelist/blacklist and standard rule locations.."

sed -i "s#dynamicpreprocessor directory /usr/local/lib/snort_dynamicpreprocessor#dynamicpreprocessor directory $snort_basedir/lib/snort_dynamicpreprocessor#" $snort_basedir/etc/snort.conf
sed -i "s#dynamicengine /usr/local/lib/snort_dynamicengine/libsf_engine.so#dynamicengine $snort_basedir/lib/snort_dynamicengine/libsf_engine.so#" $snort_basedir/etc/snort.conf
sed -i "s#dynamicdetection directory /usr/local/lib/snort_dynamicrules#dynamicdetection directory $snort_basedir/snort_dynamicrules#" $snort_basedir/etc/snort.conf
sed -i "s/# output unified2: filename merged.log, limit 128, nostamp, mpls_event_types, vlan_event_types/output unified2: filename snort.u2, limit 128/" $snort_basedir/etc/snort.conf
sed -i "s#var WHITE_LIST_PATH ../rules#var WHITE_LIST_PATH $snort_basedir/rules#" $snort_basedir/etc/snort.conf
sed -i "s#var BLACK_LIST_PATH ../rules#var BLACK_LIST_PATH $snort_basedir/rules#" $snort_basedir/etc/snort.conf
sed -i "s/include \$RULE\_PATH/#include \$RULE\_PATH/" $snort_basedir/etc/snort.conf
echo "# unified snort.rules entry" >> $snort_basedir/etc/snort.conf
echo "include \$RULE_PATH/snort.rules" >> $snort_basedir/etc/snort.conf

#making a copy of our fully configured snort.conf, and touching some files into existence, so snort doesn't barf when executed to generate the so rule stubs.
#These are blank files (except unicode.map, which snort will NOT start without the real deal), but if they don't exist, snort barfs when pp uses it to generate SO stub files.

touch $snort_basedir/etc/reference.config
touch $snort_basedir/etc/classification.config
cp /usr/src/$snortver/etc/unicode.map $snort_basedir/etc/unicode.map
touch $snort_basedir/etc/threshold.conf
touch $snort_basedir/rules/snort.rules

print_good "snort.conf configured. location: $snort_basedir/etc/snort.conf"

#Pulled Pork. Download, unpack, and configure.

cd /usr/src

print_status "Acquiring Pulled Pork.."

wget http://pulledpork.googlecode.com/files/pulledpork-0.7.0.tar.gz -O pulledpork-0.7.0.tar.gz &>> $logfile
error_check 'Download of pulledpork'

tar -xzvf pulledpork-0.7.0.tar.gz &>> $logfile
error_check 'Untar of pulledpork'

print_good "Pulledpork successfully installed to /usr/src."

print_status "Generating pulledpork.conf."

cd pulledpork-*/etc

#Create a copy of the original conf file (in case the user needs it), ask the user for an oink code, then fill out a really stripped down pulledpork.conf file with only the lines needed to run the perl script
cp pulledpork.conf pulledpork.conf.orig

echo "rule_url=https://www.snort.org/reg-rules/|snortrules-snapshot.tar.gz|$o_code" > pulledpork.tmp
echo "rule_url=https://www.snort.org/reg-rules/|opensource.gz|$o_code" >> pulledpork.tmp
echo "rule_url=https://s3.amazonaws.com/snort-org/www/rules/community/|community-rules.tar.gz|Community" >> pulledpork.tmp
echo "rule_url=http://labs.snort.org/feeds/ip-filter.blf|IPBLACKLIST|open" >> pulledpork.tmp
echo "ignore=deleted.rules,experimental.rules,local.rules" >> pulledpork.tmp
echo "temp_path=/tmp" >> pulledpork.tmp
echo "rule_path=$snort_basedir/rules/snort.rules" >> pulledpork.tmp
echo "local_rules=$snort_basedir/rules/local.rules" >> pulledpork.tmp
echo "sid_msg=$snort_basedir/etc/sid-msg.map" >> pulledpork.tmp
echo "sid_msg_version=2" >> pulledpork.tmp
echo "sid_changelog=/var/log/sid_changes.log" >> pulledpork.tmp
echo "sorule_path=$snort_basedir/lib/snort_dynamicrules/" >> pulledpork.tmp
echo "snort_path=$snort_basedir/bin/snort" >> pulledpork.tmp
echo "distro=Ubuntu-12-04" >> pulledpork.tmp
echo "config_path=$snort_basedir/etc/snort.conf" >> pulledpork.tmp
echo "black_list=$snort_basedir/rules/black_list.rules" >>pulledpork.tmp
echo "IPRVersion=$snort_basedir/rules/iplists" >>pulledpork.tmp	
echo "ips_policy=security" >> pulledpork.tmp
echo "version=0.7.0" >> pulledpork.tmp
cp pulledpork.tmp pulledpork.conf

#Run pulledpork. If the first rule download fails, the script waits 15 minutes before trying again, and so on until there are no other snort rule tarballs to attempt to download.

cd /usr/src/pulledpork-*
	
print_status "Attempting to download rules for $choice1 .."
perl pulledpork.pl -c /usr/src/pulledpork-*/etc/pulledpork.conf -vv &>> $logfile
if [ $? == 0 ]; then
	pp_postprocessing
else
	print_error "Rule download for $choice1 snort rules has failed. Waiting 15 minutes, then trying text-only rule download for $choice2.."
	sleep 910
	perl pulledpork.pl -S $choice2 -c /usr/src/pulledpork-*/etc/pulledpork.conf -T -vv &>> $logfile
	if [ $? == 0 ]; then
		pp_postprocessing
	else
		print_error "Rule download for $choice2 snort rules has failed. Waiting 15 minutes, then trying text-only rule download $choice3.."
		sleep 910
		perl pulledpork.pl -S $choice3 -c /usr/src/pulledpork-*/etc/pulledpork.conf -T -vv &>> $logfile
		if [ $? == 0 ]; then
			pp_postprocessing
		else
			print_error "Rule download for $choice3 has failed. Waiting 15 minutes, then trying text-only rule download for $choice4 (Final shot!)"
			sleep 910
			perl pulledpork.pl -S $choice4 -c /usr/src/pulledpork-*/etc/pulledpork.conf -T -vv &>> $logfile
			if [ $? == 0 ]; then
				pp_postprocessing
			else
				print_error "Rule download for $choice4 has failed; Either you've downloaded rules for another sensor from the same public IP address in the last 15 minutes, your Oink Code is invalid, or you have another issue. Check $logfile, Troubleshoot your connectivity issues to snort.org, and ensure you wait a minimum of 15 minutes before trying again."
				exit 1
			fi
		fi
	fi
fi

########################################

#now we have to download barnyard 2 and configure all of its stuff. But first, we check to see if /usr/src/barnyard 2 exists. If it does, remove it so git clone doesn't fail.

if [ -d /usr/src/barnyard2-master ]; then
	rm -rf /usr/src/barnyard2-master
fi

print_status "Downloading, making and compiling barnyard2.."

cd /usr/src

wget https://github.com/firnsy/barnyard2/archive/master.tar.gz -O barnyard2.tar.gz &>> $logfile
error_check 'Download of Barnyard2'

tar -xzvf barnyard2.tar.gz &>> $logfile
error_check 'Untar of barnyard2'

cd barnyard2*

#need to run autoreconf before we can compile it.

autoreconf -fvi -I ./m4 &>> $logfile
error_check 'Autoreconf of Barnyard2'

#This is a new work-around to find libmysqlclient.so, instead of it/then statements based on architecture.

mysqllibloc=`find /usr/lib -name libmysqlclient.so`

./configure --with-mysql --with-mysql-libraries=`dirname $mysqllibloc` &>> $logfile
error_check 'Configure of Barnyard2'

make &>> $logfile
error_check 'Make of Barnyard2'

make install &>> $logfile
error_check 'Installation of Barnyard2'

########################################
#This block of code is dedicated to establishing a baseline barnyard2.conf.
#If the user elected to install mysql and apache, we walk them through integrating barnyard2 with mysql.
#If not, we offer them the choice to have barnyard2 log to a remote database (if configured). 

print_status "Configuring supporting infrastructure for barnyard (file ownership to snort user/group, file permissions, waldo file, configuration, etc.).."


#the statements below copy the barnyard2.conf file where we want it and establish proper rights to various barnyard2 files and directories.

cp etc/barnyard2.conf $snort_basedir/etc
touch /var/log/snort/barnyard2.waldo
dir_check /var/log/barnyard2
chmod 660 /var/log/barnyard2
chown snort:snort /var/log/snort/barnyard2.waldo

#keep an original copy of the by2.conf in case the user needs to change settings.
cp $snort_basedir/etc/barnyard2.conf $snort_basedir/etc/barnyard2.conf.orig

echo "config reference_file:	$snort_basedir/etc/reference.config" >> /root/barnyard2.conf.tmp
echo "config classification_file:	$snort_basedir/etc/classification.config" >> /root/barnyard2.conf.tmp
echo "config gen_file:	$snort_basedir/etc/gen-msg.map" >> /root/barnyard2.conf.tmp
echo "config sid_file:	$snort_basedir/etc/sid-msg.map" >> /root/barnyard2.conf.tmp
echo "config hostname: `hostname`" >> /root/barnyard2.conf.tmp

# The if/then check here is to make sure the user chose to install a web interface. If they chose no, they chose not to install mysql server, so we can skip all this.

if [ $ui_inst = 1 ]; then
	print_status "Integrating mysql with barnyard2.."
	echo "output database: log,mysql, user=snort password=$snort_mysql_pass dbname=snort host=localhost" >> /root/barnyard2.conf.tmp
	
	#The next few steps build the snort database, create the database schema, and grants the snort database user permissions to fully modify contents within the database.

	print_notification "Creating snort database.."
	mysql -u root -p$root_mysql_pass -e "drop database if exists snort; create database if not exists snort; show databases;" &>> $logfile
	error_check 'Snort database creation'
	
	print_notification "Creating the snort database schema.."
	mysql -u root -p$root_mysql_pass -D snort < /usr/src/barnyard2*/schemas/create_mysql &>> $logfile
	error_check 'Snort database schema creation'

	print_notification "Creating snort database user and granting permissions to the snort database.."
	mysql -u root -p$root_mysql_pass -e "grant create, insert, select, delete, update on snort.* to snort@localhost identified by '$snort_mysql_pass';" &>> $logfile
	error_check 'Snort database user creation'
	
elif [ $ui_inst = 2 ]; then
	case $r_dbase in
		1)
		echo "output database: log,mysql, user=$rdb_user password=$rdb_pass_1 dbname=$rdb_name host=$rdb_host" >> /root/barnyard2.conf.tmp
		;;
		2)
		print_notification "You have indicated that you do not have a remote have a remote database to report events to."
		print_notification "The only valid output options you will have available will be rsyslog or no output!"
		;;
		*)
		print_error "Invalid choice for the r_dbase option. Check your configuration file and try again."
		exit 1
		;;
	esac

else
	print_error "Invalid choice for the ui_inst option. Also, how did you get here? Check your configuration file and try again."
	exit 1
fi
	
cd /root


#This choice here is to pretty up barnyard 2 output

ifconfig $snort_iface &>> $logfile
if [ $? != 0 ]; then
	print_error "that interface doesn't seem to exist. Check your config file and try again."
	exit 1
else
	if [ "$snort_iface" = "lo" ]; then
		print_error "The loopback interface is an invalid selection. Check your config file and try again."
		exit 1
	else
		print_status "Configuring to monitor on $snort_iface.."
	fi
fi

echo "config interface: $snort_iface" >> /root/barnyard2.conf.tmp
echo "input unified2" >> /root/barnyard2.conf.tmp

cp /root/barnyard2.conf.tmp $snort_basedir/etc/barnyard2.conf
rm /root/barnyard2.conf.tmp

print_good "Barnyard2 configuration completed."

########################################

#GRO and LRO are checksum offloading techniques that some network cards use to offload checking frame, packet and/or tcp header checksums and can lead to invalid checksums. Snort doesn't like packets with invalid checksums and will ignore them. These commands disable GRO and LRO.

print_notification "Disabling LRO and GRO on the sniffing interface.."
ethtool -K $snort_iface gro off &>> $logfile
ethtool -K $snort_iface lro off &>> $logfile

########################################
#Finally got around doing service persistence the right way. We check to see if the init script is already installed. If it isn't we verify the user has the init script in the right place for us to copy, then copy it into place.

cd $execdir
if [ -f /etc/init.d/snortbarn ]; then
	print_notification "Snortbarn init script already installed."
else
	if [ ! -f $execdir/snortbarn ]; then
		print_error" Unable to find $execdir/snortbarn. Please ensure snortbarn file is there and try again."
		exit 1
	else
		print_good "Found snortbarn init script."
	fi
	
	cp snortbarn snortbarn_2 &>> $logfile
	sed -i "s#snort_basedir#$snort_basedir#g" snortbarn_2
	sed -i "s#snort_iface#$snort_iface#g" snortbarn_2
	cp snortbarn_2 /etc/init.d/snortbarn &>> $logfile
	chown root:root /etc/init.d/snortbarn &>> $logfile
	chmod 700 /etc/init.d/snortbarn &>> $logfile
	update-rc.d snortbarn defaults &>> $logfile
	error_check 'Init Script installation'
	print_notification "Init script located in /etc/init.d/snortbarn"
	rm -rf snortbarn_2 &>> $logfile
fi

########################################
#Perform the interface installation step here. first, we drop back to the initial working directory where autosnort was ran from.

cd $execdir

case $ui_choice in
	1)
	print_status "Running Snort Report installer.."
	
	bash autosnortreport-ubuntu.sh
	error_check 'Snortreport web interface installation'
	
	print_notification "Navigate to http://[ip address] to get started."
	;;
	
	2)
	print_status "Running Aanval installer.."
	
	bash autoaanval-ubuntu.sh
	error_check 'Aanval web interface installation'
	
	print_notification "Navigate to http://[ip address] to get started"
	print_notification "Aanval will ask you for username and password for the aanvaldb user:"
	print_notification "Username: snort"
	print_notification "Password: $snort_mysql_pass"
	print_notification "Credentials for the snortdb user (Needed to configure the Aanval Snort Module):"
	print_notification "Username: snort"
	print_notification "Password: $snort_mysql_pass"
	print_notification "Default web interface credentials:"
	print_notification "Username: root"
	print_notification "Password: specter"
	print_notification "Please note that you will have to configure and enable the Aanval snort module to see events from your snort sensor."
	print_notification "Please check out aanval.com on how to do this."
	print_notification "You'll want to reboot the system before configuring Aanval. It won't recognize that the php mysql module is installed until you do."
	;;
	
	3)
	print_status "Running BASE installer.."
	
	bash autobase-ubuntu.sh
	error_check 'BASE web interface installation'
	
	print_notification "Navigate to http://[ip address] to get started"
	print_notification "You will be asked where adodb is installed: /usr/share/php/adodb"
	print_notification "You will asked for Database information as well:"
	print_notification "Database Name: snort"
	print_notification "Datahase Host: localhost"
	print_notification "Database Port: 3306 (or leave blank)"
	print_notification "Database Username: snort"
	print_notification "Database Password: $snort_mysql_pass"
	print_notification "Finally, the installer will give you the option of setting authentication. That's all up to you."
	;;
	
	4)
	echo "Configuring rsyslog output.."
	
	bash autosyslog_full-ubuntu.sh
	error_check 'SYSLOG output configuration'

	print_notification "Please ensure 514/udp outbound is open on THIS sensor."
	print_notification "Ensure 514/udp inbound is open on your syslog server/SIEM and that is configured to recieve syslog events."
	;;
	
	5)
	print_status "Running Snorby installer.."
	
	bash autosnorby-ubuntu.sh
	error_check 'Snorby web interface installation'
	print_notification "Default credentials are user: snorby@snorby.org password: snorby"
	print_notification "Be aware that snorby uses a 'worker' process to manage import of events/alerts. It is an asynchronous process, meaning stuff might not show up immediately."
	print_notification "If the system is rebooted, or isn't displaying events properly I recommend trying the following:"
	print_notification "Log in, navigate to Administration -> Worker & Job Queue and if the worker isn't running, start it. If it is running, restart it."
	print_notification "Additionally, Navigate to the Dashboard page, click More Options and select Force Cache Update."
	;;
	
	6)
	print_notification "No output interface has been installed per the config file."
	;;
	
	*)
	print_error "Invalid choice. Please check your config file and try again."
	exit 1
	;;
esac

print_notification "If you chose to install a web interface, and have a firewall enabled on this system, make sure port 443 on your INBOUND chain is allowed in order to be able to browse to your web interface."

########################################

case $reboot_choice in
	1)
		print_status "Rebooting now.."
		init 6
		;;
	2)
		print_notification "Okay, I'd recommend going down for reboot before putting this thing in production, however."
		;;
	*)
		print_notification "I didn't understand your choice, so I'm going to assume you're not ready to reboot the system. when you are, just run the reboot or init 6 command (prepended by sudo if you're not running as root) and you're done here."
		;;
esac
print_notification "The log file for autosnort is located at: $logfile" 
print_good "We're all done here. Have a nice day."

exit 0