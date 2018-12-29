#!/bin/bash
#auto-snort script for CentOS 6.x+
#Functions, functions everywhere.

# Logging setup. Ganked this entirely from stack overflow. Uses named pipe magic to log all the output of the script to a file. Also capable of accepting redirects/appends to the file for logging compiler stuff (configure, make and make install) to a log file instead of losing it on a screen buffer. This gives the user cleaner output, while logging everything in the background, in the event they need to send it to me for analysis/assistance.

logfile=/var/log/autosnort_install.log
mkfifo ${logfile}.pipe
tee < ${logfile}.pipe $logfile &
exec &> ${logfile}.pipe
rm ${logfile}.pipe

########################################

#metasploit-like print statements. Gratuitiously ganked from  Darkoperator's metasploit install script. status messages, error messages, good status returns. I added in a notification print for areas users should definitely pay attention to.

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

#Package installation function.

function install_packages()
{
yum -y update &>> $logfile && yum -y install ${@} &>> $logfile
error_check 'Package installation'
}

########################################
#This is a postprocessing function that should get ran after pulled pork is ran. The code is identical in all cases, so it made sense to made a function for code re-use.
#This block of code notifies the user where pulledpork is installed, removes dummy files for so rule stub generation and replaces them with valid snort configuration files (e.g. classification.config, etc.).
#Change with rule tarballs around snort 2.9.6.0 or so: gen-msg.map is no longer distrbuted with rule tarballs. Change to the script to copy it from the source tarball etc directory.
#PulledPork is now added as a cron job to run once weekly to ensure the latest rules are installed.

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

#Make a backup of the crontab before we mess with it. This is to prevent multiple redundant entries to the crontab. If we see our backup file, we restore before modifying it.

if [ -f /etc/crontab_bkup ];then
	print_notification "Found /etc/crontab_bkup. Restoring before adding our pulledpork crontab entry.."
	cp /etc/crontab_bkup /etc/crontab &>> $logfile
	chmod 644 /etc/crontab &>> $logfile
fi

cp /etc/crontab /etc/crontab_bkup &>> $logfile
chmod 600 /etc/crontab_bkup &>> $logfile

echo "#This line has been added by Autosnort to run pulledpork for the latest rule updates." >> /etc/crontab
echo "  0  0  *  *  7  root /usr/src/pulledpork-*/pulledpork.pl -c /usr/src/pulledpork-*/etc/pulledpork.conf" >> /etc/crontab
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


#These lines establish where autosnort was executed. The config file _should_ be in this directory. the script exits if the config isn't in the same directory as the autosnort-centOS shell script.

print_status "Checking for config file.."
execdir=`pwd`
if [ ! -f $execdir/full_autosnort.conf ]; then
	print_error "full_autosnort.conf was NOT found in $execdir. The script relies HEAVILY on this config file. Please make sure it is in the same directory you are executing the full-autosnort-CentOS script!"
	exit 1
else
	print_good "Found config file."
fi

source $execdir/full_autosnort.conf

########################################

print_status "OS Version Check.."
#Version Check is slightly more complicated now. We now look for "Red Hat" or "CentOS" and the major version number in /etc/redhat-release.
#Full disclaimer: I don't have access to RHEL 6/7, but those who do have told me things work the same.
os_name=`egrep -o 'CentOS|Red Hat' /etc/redhat-release`
release=`grep -oP '(?<!\.)[67]\.[0-9]+(\.[0-9]+)?' /etc/redhat-release | cut -d"." -f1`
if [[ "$os_name $release" == "CentOS 6" || "$os_name $release" == "CentOS 7" || "$os_name $release" == "Red Hat 6" || "$os_name $release" == "Red Hat 7" ]]; then
	print_good "OS is CentOS/Red Hat. Good to go."
else
    print_notification "Unable to detect OS as Redhat or CentOS 6/7. If you modified/removed /etc/redhat-release, OS detection fails. Also, be aware this script has NOT been tested on any other RPM-based platform BUT CentOS 6 and CentOS 7."
	print_notification "Please report your successes or failures!"
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

print_status "checking sshd status.."

print_notification "`service sshd status`"

########################################

print_status "Checking for wget.."

which wget &>> $logfile
if [ $? -ne 0 ]; then
    print_notification "Wget not found. Installing.." 
	install_packages wget
else
    print_good "Found wget."
fi

########################################

#CentOS 7 came out and changed a few things. One of which being WHERE the epel-release RPM is located on dl.fedoraproject.org, while still keeping the old directory structure for CentOS 6 and prior.
#This new code tries to download the EPEL rpm for CentOS/RHEL releases 6 and less, or 7 and greater. If the script can't determine your os release, we inform the user and try to move on. Hopefully without things breaking terribly.

rpm -q epel-release &>> $logfile
if [ $? -eq 0 ]; then
	print_good "EPEL package already installed."
else
	print_status "Installing EPEL repos for required packages to build snort on CentOS/RHEL.."
	arch=`uname -i`
	if [[ "$release" -ge "7" ]]; then
		wget https://dl.fedoraproject.org/pub/epel/$release/$arch/e/ -O epel-index.html &>> $logfile
		error_check 'Connection to dl.fedoraproject.org'
		epel_package=`grep epel-release epel-index.html | cut -d'"' -f6`
		rm -rf epel-index.html
		wget https://dl.fedoraproject.org/pub/epel/$release/$arch/e/$epel_package &>> $logfile
		error_check 'EPEL Package download'
		rpm -Uvh $epel_package &>> $logfile
		error_check 'EPEL Package installation'
		rm -rf epel-release*
	elif [[ "$release" -le "6" ]]; then
		wget https://dl.fedoraproject.org/pub/epel/$release/$arch -O epel-index.html &>> $logfile
		error_check 'Connection to dl.fedoraproject.org'
		epel_package=`grep epel-release epel-index.html | cut -d'"' -f6`
		rm -rf epel-index.html
		wget https://dl.fedoraproject.org/pub/epel/$release/$arch/$epel_package &>> $logfile
		error_check 'EPEL Package download'
		rpm -Uvh $epel_package &>> $logfile
		error_check 'EPEL Package installation'
		rm -rf epel-release*
	else
		print_notification "Unable to determine where to find the EPEL RPM for your os. Possible problems:"
		print_notification " 1) not running CentOS/RHEL"
		print_notification "2) the /etc/redhat-release file is missing." 
		print_notification "3) EPEL RPMs don't exist for the OS you're running. We'll try to continue, however."
	fi
fi

########################################

# System updates
print_status "Updating system via YUM (May take a while if this is a fresh install).."
yum -y update &>> $logfile
error_check 'System updates'

########################################

#These packages are required at a minimum to build snort, barnyard2, their component libraries and run pulled pork for rule management.
#CentOS 7 moved to full mariadb as such... some core package names changed. Thus we need to do version checking here as well to ensure proper package names are installed. Additionally, CentOS 7 has additional dependencies for running pulledpork: perl-Sys-Syslog perl-LWP-Protocol-https

print_status "Installing packages: ethtool make zlib-devel gcc libtool pcre-devel libdnet-devel libpcap-devel mysql/mariadb-devel flex bison autoconf perl perl-Crypt-SSLeay perl-libwww-perl perl-Archive-Tar perl-IO-Socket-SSL.."

if [[ "$release" -ge "7" ]]; then
	declare -a packages=( ethtool make zlib-devel gcc libtool pcre-devel libdnet-devel libpcap-devel mariadb-devel perl perl-Crypt-SSLeay perl-libwww-perl perl-Archive-Tar perl-IO-Socket-SSL perl-Sys-Syslog perl-LWP-Protocol-https flex bison autoconf );
	install_packages ${packages[@]}
else
	declare -a packages=( ethtool make zlib-devel gcc libtool pcre-devel libdnet-devel libpcap-devel mysql-devel perl perl-Crypt-SSLeay perl-libwww-perl perl-Archive-Tar perl-IO-Socket-SSL flex bison autoconf );
	install_packages ${packages[@]}
fi

########################################

#The user chooses whether or not they want to install software to support a web-based IDS console.
#If they choose to install the pre-reqs to support a web-based IDS console, the script installs the necessary software packages, configures httpd and mysqld to run on startup, runs commands equivalent to the mysql_secure_installation script (automatically), generates a private key and self-signed SSL cert, and lays down an HTTP to HTTPS mod_rewrite virtual host to enforce web console encryption regardless of the web interface installed.

case $ui_inst in
	1)
	print_status "Acquiring and installing mysql/mariadb and httpd.."
	#With CentOS/RHEL 7, systemd and its tool systemctl controls WHAT gets started on-boot.
	#As such, we need to check what version of CentOS/RHEL we're installing and use chkconfig/systemctl appropriately to ensure the service is started  on boot
	
	if [[ "$release" -ge "7" ]]; then
		declare -a packages=( httpd mariadb mariadb-server mariadb-bench mod_ssl )	
		install_packages ${packages[@]}
		systemctl enable httpd.service &>> $logfile	
		error_check	'Update of apache systemd entry'
		systemctl enable mariadb.service &>> $logfile	
		error_check 'Update of mariadb systemd entry'
		systemctl start mariadb.service &>> $logfile	
		error_check 'Activation of mariadb'
		systemctl start httpd.service &>> $logfile	
		error_check 'Activation of httpd'
	else
		declare -a packages=( httpd mysql mysql-bench mysql-server mod_ssl );
		install_packages ${packages[@]}
		chkconfig mysqld --add &>> $logfile	
		chkconfig httpd --add &>> $logfile
		chkconfig mysqld --level 345 on &>> $logfile
		error_check 'Update of mysql init entry'
		chkconfig httpd --level 345 on &>> $logfile
		error_check	'Update of apache init entry'
		service mysqld start &>> $logfile
		error_check 'Activiation of mysql'
		service httpd start &>> $logfile	
		error_check 'Activation of mysql'
	fi

	print_status "Running mysql_secure_installation script commands.."
	
	#These are equivalent commands to the mysql_secure_installation script that perform all the same actions automatically with no prompts.
	
	mysqladmin -uroot password $root_mysql_pass &>> $logfile
	
	mysql -uroot -p$root_mysql_pass -e "DELETE FROM mysql.user WHERE User=''; DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1'); DROP DATABASE IF EXISTS test; DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'; FLUSH PRIVILEGES;" &>> $logfile
	error_check 'mysql_secure_installation commands'
	
	#Create /etc/httpd/ssl directory, assign strict permissions to it, then drop the generated private key and self-signed cert in that directory. We'll be using this later during the interface installation script.
	
	print_status "Generating a private key and self-signed SSL certificate for HTTPS operation.."
	
	dir_check /etc/httpd/ssl
	chmod 700 /etc/httpd/ssl
	cd /etc/httpd/ssl
	
	openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=Nevada/L=LasVegas/O=Security/CN=`hostname`" -keyout ids.key  -out ids.cert &>> $logfile
	error_check 'SSL certificate and key generation'
	print_good "SSL Private key location: /etc/httpd/ssl/ids.key"
	print_good "SSL certificate location:/etc/httpd/ssl/ids.cert"
	
	chmod 600 /etc/httpd/ssl/ids.*
	
	#This is here for failed runs of autosnort. It turns out multiple runs of the scripts appends the redirect virtual host (below) multiple times to httpd.conf, which breaks things and makes httpd sad. If the backup file we make for the stock httpd.conf is here, we assume there was a failed autosnort install and copy over it, but not before saving httpd.conf (in case the user did something to it)
	
	if [ -f /etc/httpd/conf/httpd.conf.orig ]; then
		print_status "found http.conf.orig. Making copy of current httpd.conf (/etc/httpd/conf/httpd_copy) and restoring original from /etc/httpd/conf/httpd.conf.orig.."
		cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd_copy
		mv /etc/httpd/conf/httpd.conf.orig /etc/httpd/conf/httpd.conf
	fi
	
	#If these files exist move/copy them as necessary. We copy httpd.conf so there's a backup available in case the user wants to remove the web IDS interface in the future (or there's a failed autosnort install and we don't make repeated edits to httpd.conf and cause the config to fail entirely)
	
	print_status "Backing up ssl.conf and httpd.conf..."
	
	if [ -f  /etc/httpd/conf.d/ssl.conf ]; then
		mv /etc/httpd/conf.d/ssl.conf /etc/httpd/sslconf.bak
	fi
	
	if [ -f /etc/httpd/conf/httpd.conf ]; then
		cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.orig
	fi
	
	#These are configuration options that are appended to the end of httpd.conf. These config options are a catch-all for unencrypted HTTP traffic. This virtual host catches the traffic and redirects it to HTTPS, enforcing web interface encryption.
	
	echo "" >> /etc/httpd/conf/httpd.conf
	echo "# These lines have been added by Autosnort. To revert these changes, you can run cp /etc/httpd/conf/httpd.conf.orig /etc/httpd/conf/httpd.conf"  >> /etc/httpd/conf/httpd.conf
	echo "# Mod_ssl provides https, mod_rewrite is enabled already and will be used to force users to use HTTPS." >> /etc/httpd/conf/httpd.conf
	echo "LoadModule ssl_module modules/mod_ssl.so" >> /etc/httpd/conf/httpd.conf
	echo "Listen 443" >> /etc/httpd/conf/httpd.conf
	echo "" >> /etc/httpd/conf/httpd.conf
	echo "#This VHOST exists as a catch, to redirect any requests made via HTTP to HTTPS." >> /etc/httpd/conf/httpd.conf
	echo "<VirtualHost *:80>" >> /etc/httpd/conf/httpd.conf
	echo "        #Mod_Rewrite Settings. Force everything to go over SSL." >> /etc/httpd/conf/httpd.conf
	echo "        RewriteEngine On" >> /etc/httpd/conf/httpd.conf
	echo "        RewriteCond %{HTTPS} off" >> /etc/httpd/conf/httpd.conf
	echo "        RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI}" >> /etc/httpd/conf/httpd.conf
	echo "</VirtualHost>" >> /etc/httpd/conf/httpd.conf
	echo "" >> /etc/httpd/conf/httpd.conf	
	;;
	
	2)
	print_notification "You've chosen to not install a mysql server or apache."
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

print_status "Determining latest versions of snort and daq available on snort.org.."


cd /tmp
wget http://www.snort.org -O /tmp/snort &>> $logfile
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

print_status "Acquiring $snortver and $daqver from snort.org.."

wget http://www.snort.org/downloads/snort/$snorttar -O $snorttar &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to download $snorttar. Please check $logfile for details."
	exit 1	
else
    print_good "Downloaded $snorttar to /usr/src."
fi



wget http://www.snort.org/downloads/snort/$daqtar -O $daqtar &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to download $daqtar. Please check $logfile for details."
	exit 1	
else
    print_good "Downloaded $daqtar to /usr/src."
fi

########################################
#Download, extract, build and install Daq Libraries.

print_status "Acquiring and unpacking $daqver to /usr/src.."

wget http://www.snort.org/downloads/snort/$daqtar -O $daqtar &>> $logfile
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

wget http://www.snort.org/downloads/snort/$snorttar -O $snorttar &>> $logfile
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
	print_notification "snort user exists. Verifying group exists.."
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
#This block if code gets very very hairy, very very fast.
#1. Setup necessary directory structure for snort
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

#Pulled Pork. Download pre-req packages, unpack, and configure pulled pork.

cd /usr/src
print_status "Acquiring Pulled Pork.."

wget http://pulledpork.googlecode.com/files/pulledpork-0.7.0.tar.gz -O pulledpork-0.7.0.tar.gz &>> $logfile
error_check 'Download of pulledpork'

tar -xzvf pulledpork-0.7.0.tar.gz &>> $logfile
error_check 'Untar of pulledpork'

print_good "Pulledpork successfully installed to /usr/src."

print_status "Generating pulledpork.conf.."

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
echo "distro=Centos-5-4" >> pulledpork.tmp
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

#now we have to download barnyard 2 and configure all of its stuff.

print_status "Downloading, making and compiling barnyard2.."

cd /usr/src

wget https://github.com/firnsy/barnyard2/archive/master.tar.gz -O barnyard2.tar.gz &>> $logfile
error_check 'Download of Barnyard2'

tar -xzvf barnyard2.tar.gz &>> $logfile
error_check 'Untar of Barnyard2'

########################################

cd barnyard2*

#need to run autoreconf before we can compile it.

autoreconf -fvi -I ./m4 &>> $logfile
error_check 'Autoreconf of Barnyard2'

#This is a new work-around to find libmysqlclient.so, instead of it/then statements based on architecture.

mysqllibloc=`find /usr/lib* -name libmysqlclient.so`

./configure --with-mysql --with-mysql-libraries=`dirname $mysqllibloc` &>> $logfile
error_check 'Configure of Barnyard2'

make &>> $logfile
error_check 'Make of Barnyard2'

make install &>> $logfile
error_check 'Installation of Barnyard2'

########################################

#This block of code is dedicated to establishing a baseline barnyard2.conf.
#If the user elected to install mysql-server and apache, we walk them through integrating barnyard2 with mysql.
#If not, we offer them the choice to have barnyard2 log to a remote database (if configured). 

print_status "Configuring supporting infrastructure for barnyard (file ownership to snort user/group, file permissions, waldo file, configuration, etc.).."


#the statements below copy the barnyard2.conf file where we want it and establish proper rights to various barnyard2 files and directories.

cp etc/barnyard2.conf $snort_basedir/etc
touch /var/log/snort/barnyard2.waldo
dir_check /var/log/barnyard2
chmod 660 /var/log/barnyard2
chown snort.snort /var/log/snort/barnyard2.waldo

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

#This is to pretty up barnyard 2 output)

ip link show $snort_iface &>> $logfile
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

print_status "Configuring $snort_iface.."
ethtool -K $snort_iface gro off &>> $logfile
ethtool -K $snort_iface lro off &>> $logfile

########################################
#Finally got around doing service persistence the right way.
#If the user is running CentOS/RHEL greater than or equal to version 7, we install a systemd script. Otherwise we install an init script via chkconfig. This portion also stops to see if the init/systemd script is already there (from a previous/failed install)

print_status "Adding Sys V/Systemd script for persistence"
print_notification "Please be aware $snort_iface will be configured to boot in promiscuous mode, and will NOT respond to multicast or ARP requests."
print_notification "This can be changed by modifying the init script (CentOS/Redhat 6 and below - /etc/init.d/snortbarn) or the systemd script (CentOS/Redhat 7 and above - /usr/lib/systemd/system/snortbarn.service)"

cd $execdir
if [[ "$release" -ge "7" ]]; then
	if [ -f /usr/lib/systemd/system/snortbarn.service ]; then
		print_notification "snortbarn.service systemd script already installed."
	else
		if [ ! -f $execdir/snortbarn.service ]; then
			print_error "Unable to find $execdir/snortbarn.service. Please ensure the snort.service file is there and try again."
			exit 1
		else
			print_good "Found snortbarn.service systemd script."
		fi
		cp snortbarn.service snortbarn.service2 &>> $logfile
		sed -i "s#snort_basedir#$snort_basedir#g" snortbarn.service2
		sed -i "s#snort_iface#$snort_iface#g" snortbarn.service2
		cp snortbarn.service2 /usr/lib/systemd/system/snortbarn.service &>> $logfile
		chown root:root /usr/lib/systemd/system/snortbarn.service &>> $logfile
		chmod 644 /usr/lib/systemd/system/snortbarn.service &>> $logfile
		rm -rf snortbarn.service2 &>> $logfile
		systemctl enable snortbarn.service &>> $logfile
		error_check 'Systemd service install'
		print_notification "Systemd script located in /lib/systemd/system/snortbarn.service"
		rm -rf snortbarn.service2 &>> $logfile
	fi
else
	if [ -f /etc/init.d/snortbarn ]; then
	print_notification "Snortbarn init script already installed."
	else	
		if [ ! -f $execdir/snortbarn ]; then
			print_error" Unable to find $execdir/snortbarn. Please ensure snortbarn file is there and try again."
			exit 1
		else
			print_good "Found snortbarn init script."
		fi
		hstnm=`hostname`
		cp snortbarn snortbarn_2 &>> $logfile
		sed -i "s#snort_basedir#$snort_basedir#g" snortbarn_2
		sed -i "s#hstnm#$hstnm#g" snortbarn_2
		sed -i "s#snort_iface#$snort_iface#g" snortbarn_2
		cp snortbarn_2 /etc/init.d/snortbarn &>> $logfile
		chown root:root /etc/init.d/snortbarn &>> $logfile
		chmod 700 /etc/init.d/snortbarn &>> $logfile
		chkconfig snortbarn --add &>> $logfile
		chkconfig snortbarn --level 345 on &>> $logfile
		error_check 'Init Script created'
		print_notification "Init script located in /etc/init.d/snortbarn"
		rm -rf snortbarn_2 &>> $logfile
	fi
fi



########################################

#Perform the interface installation step here. first, we drop back to the initial working directory where autosnort was ran from.
cd $execdir

case $ui_choice in
	1)
	print_status "Running Snort Report installer.."
	
	bash autosnortreport-CentOS.sh
	error_check 'Snortreport web interface installation'
	
	print_notification "Navigate to http://[ip address] to get started."
	;;
	
	2)
	print_status "Running Aanval installer.."
	
	bash autoaanval-CentOS.sh
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
	
	bash autobase-CentOS.sh
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
	
	bash autosyslog_full-CentOS.sh
	error_check 'SYSLOG output configuration'

	print_notification "Please ensure 514/udp outbound is open on THIS sensor."
	print_notification "Ensure 514/udp inbound is open on your syslog server/SIEM and that is configured to recieve syslog events."
	;;
	
	5)
	print_status "Running Snorby installer.."
	
	bash autosnorby-CentOS.sh
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
	print_status "Rebooting now."
	init 6
	;;
	
	2)
	print_notification "Do not reboot selected. I would highly recommend that you reboot this system before putting it into production."
	;;
	
	*)
	print_error "Not a valid choice. Exiting."
	exit 1
	;;
esac

print_notification "The log file for autosnort is located at: $logfile" 
print_good "We're all done here. Have a nice day."

exit 0