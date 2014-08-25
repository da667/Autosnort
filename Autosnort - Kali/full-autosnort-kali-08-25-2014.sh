#!/bin/bash
#autosnort script for Debian 6 and 7

#Functions, functions everywhere.
#Below are 

# Logging setup. Ganked this entirely from stack overflow. Uses named pipe magic to log all the output of the script to a file. Also capable of accepting redirects/appends to the file for logging compiler stuff (configure, make and make install) to a log file instead of losing it on a screen buffer.

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

#Package installation function.

function install_packages()
{
 apt-get update &>> $logfile && apt-get install -y ${@} &>> $logfile
 if [ $? -eq 0 ]; then
  print_good "Packages successfully installed."
 else
  print_error "Packages failed to install!"
  exit 1
 fi
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

}

########################################

##BEGIN MAIN SCRIPT##

#Pre checks: These are a couple of basic sanity checks the script does before proceeding.

########################################

execdir=`pwd`
source $execdir/full_autosnort.conf

print_status "OS Version Check.."
release=`lsb_release -r|awk '{print $4}'`
if [[ $release == "1.0."* ]]; then
	print_good "OS is Kali Linux. Good to go."
else
    print_notification "This is not Kali Linux 1.0.X, this autosnort script has NOT been tested on other platforms."
	print_notification "If you choose to continue, you continue at your own risk!(Please report your successes or failures!)"
fi

########################################

#root privs check. If you're running Kali, you should be root, but it never hurts to make sure.

print_status "Checking for root privs.."
if [ $(whoami) != "root" ]; then
	print_error "This script must be ran with sudo or root privileges, or this isn't going to work."
	exit 1
else
	print_good "We are root."
fi
	 
########################################	 

print_status "Checking to ensure sshd is running.."

print_notification "`service ssh status`"

########################################

# System updates
export DEBIAN_FRONTEND=noninteractive

print_status "Performing apt-get update and upgrade (If this is a fresh install, this IS going to take a while, like a LONG while).."
print_notification "You can tail -f $logfile for status."
apt-get update &>> $logfile && apt-get -y dist-upgrade &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Apt-get update and upgrade failed. Please check /var/log/autosnort_install.log for details."
	exit 1	
else
    print_good "Updates Installed."
fi

########################################

#These packages are required at a minimum to build snort and barnyard + their component libraries

print_status "Installing base packages: libpcap0.8-dev libtool libmysqlclient-dev libnetfilter-queue-dev libnetfilter-queue1 libnfnetlink-dev libnfnetlink0"

declare -a packages=( libpcap0.8-dev libtool libmysqlclient-dev libnetfilter-queue-dev libnetfilter-queue1 libnfnetlink-dev libnfnetlink0 );
install_packages ${packages[@]}

########################################

#This is where the user decides whether or not they want a full stand-alone sensor or a barebones/distributed installation sensor.

case $ui_inst in
	1)
	print_status "Updating init entries for mysql and apache for auto-start.."
	
	update-rc.d mysql enable &>> $logfile
	if [ $? -ne 0 ]; then
		print_error "Failed to update init entry for mysql. See $logfile for details."
		exit 1
	fi
	
	update-rc.d apache2 enable &>> $logfile
	if [ $? -ne 0 ]; then
		print_error "Failed to update init entry for mysql. See $logfile for details."
		exit 1
	fi	
	
	print_status "Starting apache and mysql services.."
	
	service apache2 start &>> $logfile
	service mysql start &>> $logfile

	print_status "Running mysql_secure_installation script commands.."
	
	mysqladmin -uroot password $root_mysql_pass &>> $logfile
	
	mysql -uroot -p$root_mysql_pass -e "DELETE FROM mysql.user WHERE User=''; DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1'); DROP DATABASE IF EXISTS test; DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'; FLUSH PRIVILEGES;" &>> $logfile
	if [ $? -ne 0 ]; then
		print_error "Secure installation commands failed to run. Please check $logfile for details."
		exit 1	
	else
		print_good "Secure installation script completed. Mysql-server and apache2 successfully started."
	fi
	
	#We make /etc/apache2/ssl and set strict r/w permissions for root only in the directory. 
	#Afterwards, we generate a self-signed certificate and private key, putting strict permissions on those as well.
	#We back up the ssl.conf, default and default-ssl sites, then we write our own ssl.conf, to utilize our private key and certificate.
	#Finally, we enable mod_ssl and mod_rewrite to handle SSL operation and redirection of any HTTP users to HTTPS.
	
	print_status "Generating a private key and self-signed SSL certificate for HTTPS operation.."
	if [ ! -d /etc/apache2/ssl ]; then 
		mkdir -p /etc/apache2/ssl
		if [ $? -ne 0 ]; then
			print_error "Failed to create $snort_basedir. Please check $logfile for details and/or confirm you used an ABOSOLUTE path in the full_autosnort.conf file."
			exit 1
		fi
	else
		print_notification "/etc/apache/ssl already exists. No big deal, we'll go ahead and use it."
	fi
	
	chmod 600 /etc/apache2/ssl
	cd /etc/apache2/ssl
	
	openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=Nevada/L=LasVegas/O=Security/CN=ids.local" -keyout ids.key  -out ids.cert &>> $logfile
	if [ $? -ne 0 ]; then
		print_error "Something went wrong during private and certificate generation. Please check $logfile for details."
		exit 1
	else
		print_good "Private Key and Self-Signed Certificate generated. Location:"
		print_good "/etc/apache2/ssl/ids.key"
		print_good "/etc/apache2/ssl/ids.cert"
	fi
	
	chmod 600 /etc/apache2/ssl/ids.*
		
	print_status "Backing up default ssl.conf, default virtual host file, and replacing ssl.conf.."
	
	mv /etc/apache2/sites-available/default /etc/apache2/defaultsiteconfbak
	mv /etc/apache2/sites-available/default-ssl /etc/apache2/default-sslsiteconfbak
	mv /etc/apache2/mods-available/ssl.conf /etc/apache2/defaultsslconfbak
	
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
	print_status "Enabling mod_ssl and mod_rewrite.."
	
	a2enmod ssl &>> $logfile
	if [ $? -ne 0 ]; then
		print_error "Was not successful enabling mod_ssl. See $logfile for more details."
		exit 1
	fi
	
	a2enmod rewrite &>> $logfile
	if [ $? -ne 0 ]; then
		print_error "Was not successful enabling mod_rewrite. See $logfile for more details."
		exit 1
	else
		print_good "Successfully configured mod_ssl and mod_rewrite for apache2."
	fi
	
	break
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
#This section is a hack I implemented using wget, grep and cut. 
#We pull the downloads page from snort.org and cut out some strings to determine the version of snort and/or daq to pull.
#After that we pull snort, daq, and libnet them compile them.

print_status "Determining latest versions of snort and daq available on snort.org.."


cd /tmp
wget http://www.snort.org -O /tmp/snort &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to contact snort.org. Please check $logfile for details."
	exit 1	
fi

snorttar=`grep snort-[0-9] /tmp/snort | grep .tar.gz | tail -1 | cut -d"/" -f4 | cut -d\" -f1`
daqtar=`grep daq-[0-9] /tmp/snort | grep .tar.gz | tail -1 | cut -d"/" -f4 | cut -d\" -f1`
snortver=`echo $snorttar | sed 's/.tar.gz//g'`
daqver=`echo $daqtar | sed 's/.tar.gz//g'`

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
#libdnet is a library required for snort. Grab, unpack, build, install.

print_status "Acquiring libdnet 1.12.."

cd /usr/src
wget http://libdnet.googlecode.com/files/libdnet-1.12.tgz &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to download libdnet from libdnet.googlecode.com. Please check $logfile for details."
	exit 1	
else
    print_good "Downloaded libdnet 1.12 to /usr/src."
fi

tar -xzvf libdnet-1.12.tgz &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to untar libdnet. Please check $logfile for details."
	exit 1	
fi

cd libdnet-1.12

print_status "Configuring, making, compiling and linking libdnet. This will take a moment or two.."

#The CFLAGS are required to compile libdnet the right way so that DAQ will compile properly with NFQUEUE support enabled.

./configure "CFLAGS=-fPIC -g -O2" &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to configure. Please check $logfile for details."
	exit 1	
fi

make &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to make. Please check $logfile for details."
	exit 1	
fi

make install &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to make install. Please check $logfile for details."
	exit 1	
fi

#this is in regards to the fix posted in David Gullett's snort guide - /usr/local/lib isn't include in ld path by default in Ubuntu. 
#Don't know if this is relevant for Kali, but it hasn't hurt implementing it.

if [ ! -h /usr/lib/libdnet.1 ]; then
print_status "Creating symlink for libdnet on default ld library path.."
ln -s /usr/local/lib/libdnet.1.0.1 /usr/lib/libdnet.1
fi

print_good "Libdnet successfully installed."
cd /usr/src

########################################
#Extract, build and install Daq Libraries.

tar -xzvf $daqtar &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to untar $daqtar. Please check $logfile for details."
	exit 1	
fi

cd $daqver

print_status "Configuring, making and compiling DAQ. This will take a moment or two.."

./configure &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to configure. Please check $logfile for details."
	exit 1	
fi

make &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to make. Please check $logfile for details."
	exit 1	
fi

make install &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to make install. Please check $logfile for details."
	exit 1	
fi

#seen some strange happenings where if this isn't symlinked or in /usr/lib, snort fails to find it and subsequently bails.

if [ ! -h /usr/lib/libsfbpf.so.0 ]; then
print_status "Creating symlink for libsfbpf.so.0 on default ld library path.."
ln -s /usr/local/lib/libsfbpf.so.0 /usr/lib/libsfbpf.so.0
fi

print_good "DAQ libraries successfully installed."



cd /usr/src
tar -xzvf $snorttar &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to untar $snorttar. Please check $logfile for details."
	exit 1	
fi

########################################
#This is where snort actually gets installed. We create the directory the user wants to install snort in (if it doesn't exist) Unpack snort, build, compile and install.
#Afterwards we create a snort system user to drop privs down to when snort is running and a couple of log directories for snort to write logs to.

cd /usr/src
tar -xzvf $snorttar &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to untar $snorttar. Please check $logfile for details."
	exit 1	
fi

if [ ! -d $snort_basedir ]; then 
	mkdir -p $snort_basedir
	if [ $? -ne 0 ]; then
    print_error "Failed to create $snort_basedir. Please check $logfile for details and/or confirm you used an ABOSOLUTE path in the full_autosnort.conf file."
	exit 1
	fi
else
	print_notification "$snort_basedir already exists. No big deal, we'll go ahead and use it."
fi

cd $snortver

print_status "configuring snort (options --prefix=$snort_basedir and --enable-sourcefire), making and installing. This will take a moment or two."

./configure --prefix=$snort_basedir --enable-sourcefire &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to configure. Please check $logfile for details."
	exit 1	
fi

make &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to make. Please check $logfile for details."
	exit 1	
fi

make install &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to make install. Please check $logfile for details."
	exit 1	
fi


print_good "Snort successfully installed."

print_status "Creating directories /var/log/snort, and /var/snort."

if [ ! -d /var/snort ]; then 
	mkdir -p /var/snort
	if [ $? -ne 0 ]; then
    print_error "Failed to create /var/snort. Please check $logfile for details and/or confirm you used an ABOSOLUTE path in the full_autosnort.conf file."
	exit 1
	fi
else
	print_notification "/var/snort already exists. No big deal, we'll go ahead and use it."
fi

if [ ! -d /var/log/snort ]; then 
	mkdir -p /var/log/snort
	if [ $? -ne 0 ]; then
    print_error "Failed to create /var/log/snort. Please check $logfile for details and/or confirm you used an ABOSOLUTE path in the full_autosnort.conf file."
	exit 1
	fi
else
	print_notification "/var/log/snort already exists. No big deal, we'll go ahead and use it."
fi

print_status "Creating snort user and group, assigning ownership of /var/log/snort to snort user and group."

groupadd snort
useradd -g snort snort -s /bin/false
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

if [ ! -d $snort_basedir/etc ]; then 
	mkdir -p $snort_basedir/etc
	if [ $? -ne 0 ]; then
    print_error "Failed to create$snort_basedir/etc. Please check $logfile for details."
	exit 1
	fi
else
	print_notification "$snort_basedir/etc already exists. No big deal, we'll go ahead and use it."
fi

if [ ! -d $snort_basedir/so_rules ]; then 
	mkdir -p $snort_basedir/so_rules
	if [ $? -ne 0 ]; then
    print_error "Failed to create $snort_basedir/so_rules. Please check $logfile for details."
	exit 1
	fi
else
	print_notification "$snort_basedir/so_rules already exists. No big deal, we'll go ahead and use it."
fi

if [ ! -d $snort_basedir/rules ]; then 
	mkdir -p $snort_basedir/rules
	if [ $? -ne 0 ]; then
    print_error "Failed to create $snort_basedir/rules. Please check $logfile for details."
	exit 1
	fi
else
	print_notification "$snort_basedir/rules already exists. No big deal, we'll go ahead and use it."
fi

if [ ! -d $snort_basedir/preproc_rules ]; then 
	mkdir -p $snort_basedir/preproc_rules
	if [ $? -ne 0 ]; then
    print_error "Failed to create $snort_basedir/preproc_rules. Please check $logfile for details."
	exit 1
	fi
else
	print_notification "$snort_basedir/etc already exists. No big deal, we'll go ahead and use it."
fi

if [ ! -d $snort_basedir/snort_dynamicrules ]; then 
	mkdir -p $snort_basedir/snort_dynamicrules
	if [ $? -ne 0 ]; then
    print_error "Failed to create $snort_basedir/snort_dynamicrules. Please check $logfile for details."
	exit 1
	fi
else
	print_notification "$snort_basedir/snort_dynamicrules already exists. No big deal, we'll go ahead and use it."
fi

#we wget snort.org, do a lot of text manipulation from the html file downloaded, and set variables: two variables for attempting to downloading the VRT example snort.conf from labs.snort.org, and four variables for the version of snort to download rules for via pulledpork.
print_status "Checking current rule releases on snort.org.."

wget http://www.snort.org -O /tmp/snort-rules &>> $logfile
if [ $? -ne 0 ]; then
	print_error "Failed to contact snort.org. Please check $logfile for details."	
fi

choice1conf=`grep snortrules-snapshot-[0-9][0-9][0-9][0-9] /tmp/snort-rules|cut -d"-" -f3 |cut -d"." -f1 | sort -ur | head -1` #snort.conf download attempt 1
choice2conf=`grep snortrules-snapshot-[0-9][0-9][0-9][0-9] /tmp/snort-rules|cut -d"-" -f3 |cut -d"." -f1 | sort -ur | head -2 | tail -1` #snort.conf download attempt 2
choice1=`echo $choice1conf |sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./'` #pp config choice 1
choice2=`echo $choice2conf | sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./'` #pp config choice 2
choice3=`grep snortrules-snapshot-[0-9][0-9][0-9][0-9] /tmp/snort-rules|cut -d"-" -f3 |cut -d"." -f1 | sort -ru | head -3 | tail -1 | sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./'`
choice4=`grep snortrules-snapshot-[0-9][0-9][0-9][0-9] /tmp/snort-rules|cut -d"-" -f3 |cut -d"." -f1 | sort -ru | head -4| tail -1 | sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./'`

rm -rf /tmp/snort-rules

wget http://labs.snort.org/snort/$choice1conf/snort.conf -O $snort_basedir/etc/snort.conf &>> $logfile
if [ $? != 0 ];then
	print_error "Attempt 1 to download $choice1 snort.conf from labs.snort.org failed. attempting to download snort.conf for $choice2"
	wget http://labs.snort.org/snort/$choice2conf/snort.conf -O $snort_basedir/etc/snort.conf &>> $logfile
	if [ $? != 0 ];then
		print_error "This attempt to download a snort.conf has failed as well. Aborting pulledpork rule installation.Check $logfile for details."
	else
		print_notification "Successfully downloaded snort.conf for $choice2. This will likely work for now until they upload a new snort.conf to labs.snort.org."
	fi
else
	print_good "Successfully downloaded snort.conf for $choice1."
fi

#Trim up snort.conf as necessary to work properly. Snort is actually executed by pulled pork to dump the so stub files for shared object rules.

print_status "ldconfig processing and creation of whitelist/blacklist.rules files taking place."

touch $snort_basedir/rules/white_list.rules && touch $snort_basedir/rules/black_list.rules && ldconfig

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

print_status "Acquiring packages for pulled pork"
declare -a packages=( perl libarchive-tar-perl libcrypt-ssleay-perl libwww-perl );
install_packages ${packages[@]}

print_status "Acquiring Pulled Pork.."

wget http://pulledpork.googlecode.com/files/pulledpork-0.7.0.tar.gz -O pulledpork-0.7.0.tar.gz &>> $logfile
if [ $? -ne 0 ]; then
	print_error "Failed to acquire pulledpork. Please check $logfile for details."
	continue	
fi

tar -xzvf pulledpork-0.7.0.tar.gz &>> $logfile
if [ $? -ne 0 ]; then
	print_error "Failed to untar pulledpork. Please check $logfile for details."
	continue	
fi

print_good "Pulledpork successfully installed to /usr/src."

cd pulledpork-*/etc
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
echo "distro=Debian-6-0" >> pulledpork.tmp
echo "config_path=$snort_basedir/etc/snort.conf" >> pulledpork.tmp
echo "black_list=$snort_basedir/rules/black_list.rules" >>pulledpork.tmp
echo "IPRVersion=$snort_basedir/rules/iplists" >>pulledpork.tmp	
echo "ips_policy=security" >> pulledpork.tmp
echo "version=0.7.0" >> pulledpork.tmp
cp pulledpork.tmp pulledpork.conf

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

git clone https://github.com/firnsy/barnyard2.git &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to download barnyard2 from github.com. Please see $logfile for details."
	exit 1	
fi

########################################

cd barnyard2

#need to run autoreconf before we can compile it.

autoreconf -fvi -I ./m4 &>> $logfile
if [ $? -ne 0 ]; then
    print_error "autoreconf for barnyard2 failed. see $logfile for details"
	exit 1	
fi

#New work-around to find libmysqlclient.so : Debian 6 and Debian 7 store it in different places, and so far as I can tell so do Ubuntu 12.xx and 13.xx

#we know the root directory is /usr/lib, so we run find, record where libmysqlclient.so is, then use 'dirname' to point the script at the right directory.
#found out the hard way that if you point --with-mysql-libraries directly at the .so file, it doesn't work; it's expecting a directory, NOT a file.

mysqllibloc=`find /usr/lib -name libmysqlclient.so`

./configure --with-mysql --with-mysql-libraries=`dirname $mysqllibloc` &>> $logfile
if [ $? -ne 0 ]; then
    print_error "configure for barnyard2 failed. see $logfile for details"
	exit 1	
fi

make &>> $logfile
if [ $? -ne 0 ]; then
    print_error "make for barnyard2 failed. see $logfile for details"
	exit 1	
fi

make install &>> $logfile
if [ $? -ne 0 ]; then
    print_error "make_install for barnyard2 failed. see $logfile for details"
	exit 1	
fi

print_good "Barnyard2 successfully installed."

########################################

#This block of code is dedicated to establishing a baseline barnyard2.conf.
#If the user elected to install mysql-server and apache, we walk them through integrating barnyard2 with mysql.
#If not, we offer them the choice to have barnyard2 log to a remote database (if configured). 

print_status "Configuring supporting infrastructure for barnyard (file ownership to snort user/group, file permissions, waldo file, configuration, etc.).."


#the statements below copy the barnyard2.conf file where we want it and establish proper rights to various barnyard2 files and directories.

cp etc/barnyard2.conf $snort_basedir/etc
mkdir -p /var/log/barnyard2
chmod 666 /var/log/barnyard2
touch /var/log/snort/barnyard2.waldo
chown snort.snort /var/log/snort/barnyard2.waldo

#keep an original copy of the by2.conf in case the user needs to change settings.
cp $snort_basedir/etc/barnyard2.conf $snort_basedir/etc/barnyard2.conf.orig

echo "config reference_file:	$snort_basedir/etc/reference.config" >> /root/barnyard2.conf.tmp
echo "config classification_file:	$snort_basedir/etc/classification.config" >> /root/barnyard2.conf.tmp
echo "config gen_file:	$snort_basedir/etc/gen-msg.map" >> /root/barnyard2.conf.tmp
echo "config sid_file:	$snort_basedir/etc/sid-msg.map" >> /root/barnyard2.conf.tmp
echo "config hostname: localhost" >> /root/barnyard2.conf.tmp

# The if/then check here is to make sure the user chose to install a web interface. If they chose no, they chose not to install mysql server, so we can skip all this.

if [ $ui_inst = 1 ]; then
	print_status "Integrating mysql with barnyard2.."
	echo "output database: log,mysql, user=snort password=$snort_mysql_pass dbname=snort host=localhost" >> /root/barnyard2.conf.tmp
	
	#The next few steps build the snort database, create the database schema, and grants the snort database user permissions to fully modify contents within the database.

	print_notification "Creating snort database.."
	mysql -u root -p$root_mysql_pass -e "drop database if exists snort; create database if not exists snort; show databases;" &>> $logfile
	if [ $? != 0 ]; then
		print_error "the command did NOT complete successfully. Please see $logfile, confirm the root mysql user password, and try again."
		exit 1
	else
		print_good "snort database created!"
	fi
	
	print_notification "Creating the snort database schema.."
	mysql -u root -p$root_mysql_pass -D snort < /usr/src/barnyard2/schemas/create_mysql &>> $logfile
	if [ $? != 0 ]; then
		print_error "the command did NOT complete successfully. Please see $logfile, confirm the root mysql user password, and try again."
		exit 1
	else
		print_good "snort database schema created!"
	fi

	print_notification "Creating snort database user and granting permissions to the snort database.."
	mysql -u root -p$root_mysql_pass -e "grant create, insert, select, delete, update on snort.* to snort@localhost identified by '$snort_mysql_pass';" &>> $logfile
	if [ $? != 0 ]; then
		print_error "the command did NOT complete successfully. Please see $logfile, confirm the root mysql user password, and try again."
		exit 1
	else
		print_good "snort database user created!"

	fi
	
elif [ $ui_inst = 2 ]; then
	print_notification "You chose to not set up mysql-server earlier."
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
	print_error "Invalid choice for the ui_inst option. Check your configuration file and try again."
fi
	
cd /root

#We have the user decide what interface snort will be listening on. This is setup for the next couple of statements (e.g. if they want the interface up and sniffing at boot, etc.). The first choice here is to pretty up barnyard 2 output)

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


echo "config interface: `hostname`-$snort_iface" >> /root/barnyard2.conf.tmp
echo "input unified2" >> /root/barnyard2.conf.tmp


cp /root/barnyard2.conf.tmp $snort_basedir/etc/barnyard2.conf
rm /root/barnyard2.conf.tmp

print_good "Barnyard2 configuration completed."

#GRO and LRO are checksum offloading techniques that some network cards use to offload checking frame, packet and/or tcp header checksums and can lead to invalid checksums. Snort doesn't like packets with invalid checksums and will ignore them. These commands disable GRO and LRO.

print_status "Disabling lro and gro on $snort_iface.."
ethtool -K $snort_iface gro off &>> $logfile
ethtool -K $snort_iface lro off &>> $logfile

########################################

print_status "Configuring chosen interface to sniff at boot.."

case $boot_iface in
	1 )
	print_status "Adding ifconfig line for $snort_iface to rc.local.."
    grep -v exit /etc/rc.local > /root/rc.local.tmp
	echo "#This is to ensure that the sniffing interface is up. -multicast and -arp ensure the sniffing interface does not respond to traffic. promisc is ensure it collects packets properly." >> /root/rc.local.tmp
	echo "ifconfig $snort_iface up -arp -multicast promisc" >> /root/rc.local.tmp
	cp /root/rc.local.tmp /etc/rc.local
	print_good "$snort_iface successfully configured to sniff at boot."
    ;;
    2 )
    print_notification "$snort_iface will not be configured to sniff at boot."
    ;;
    * )
	print_error "Invalid choice. Check your config file and try again."
	exit 1
    ;;
esac


#We ask the user if they want snort and barnyard dropped to rc.local. We also do some fault checking. If they choose to NOT have an interface up and ready for snort at boot, we don't let them start barnyard2 or snort via rc.local (they would just error out anyhow)

case $startup_choice in
	1 )
	print_status "adding snort and barnyard2 to rc.local.."
	cp /etc/rc.local /root/rc.local.tmp
	echo "#start snort as user/group snort, Daemonize it, read snort.conf and run against $snort_iface" >> /root/rc.local.tmp
	echo "$snort_basedir/bin/snort -D -u snort -g snort -c $snort_basedir/etc/snort.conf -i $snort_iface" >> /root/rc.local.tmp
	echo "/usr/local/bin/barnyard2 -c $snort_basedir/etc/barnyard2.conf -d /var/log/snort -f snort.u2 -w /var/log/snort/barnyard2.waldo -D" >> /root/rc.local.tmp
	cp /root/rc.local.tmp /etc/rc.local
	rm /root/rc.local.tmp
	print_good "Snort and barnyard successfully added to /etc/rc.local."
	print_notification "If you chose 2 for the boot_iface option, it is advised you create an entry in /etc/rc.local to put your sniffing interface up in promiscuous mode BEFORE the command to run snort." 
	print_notification "(ex: ifconfig $snort_iface up -arp -multicast promisc)"
	;;
	2 )
	print_good "Confirmed. Snort and Barnyard will NOT be configured to start on system boot."
	;;
	* )
	print_error "Invalid choice. Please check your config file and try again."
	exit 1
	;;
esac


#Perform the interface installation step here. first, we drop back to the initial working directory where autosnort was ran from.
cd $execdir

case $ui_choice in
	1)
	print_status "Running Snort Report installer.."
	
	bash autosnortreport-kali.sh
	if [ $? != 0 ]; then
		print_error "The installer script failed. Please review the installation log and try again."
		exit 1
	else
		print_good "Snort Report installation successful."
		print_notification "Navigate to http://[ip address] to get started."
	fi
	;;
	
	2)
	print_status "Running Aanval installer.."
	
	bash autoaanval-kali.sh
	if [ $? != 0 ]; then
		print_error "The installer script failed. Please review the installation log and try again."
		exit 1
	else
		print_good "Aanval installation successful."
		print_notification "Navigate to http://[ip address] to get started"
		print_notification "Aanval will ask you for username and password for the aanvaldb user:"
		print_notification "Username: snort"
		print_notification "Password: $MYSQL_PASS_1"
		print_notification "Credentials for the snortdb user (Needed to configure the Aanval Snort Module):"
		print_notification "Username: snort"
		print_notification "Password: $MYSQL_PASS_1"
		print_notification "Default web interface credentials:"
		print_notification "Username: root"
		print_notification "Password: specter"
		print_notification "Please note that you will have to configure and enable the Aanval snort module to see events from your snort sensor."
		print_notification "Please check out aanval.com on how to do this. Its incredibly simple."
		print_notification "You'll want to reboot the system before configuring Aanval. It won't recognize that the php mysql module is installed until you do."
	fi
	;;
	
	3)
	print_status "Running BASE installer.."
	
	bash autobase-kali.sh
	if [ $? != 0 ]; then
		print_error "The installer script failed. Please review the installation log and try again."
		exit 1
	else
		print_good "BASE installation successful."
		print_notification "Navigate to http://[ip address] to get started"
		print_notification "You will be asked where adodb is installed: /usr/share/php/adodb"
		print_notification "You will asked for Database information as well:"
		print_notification "Database Name: snort"
		print_notification "Datahase Host: localhost"
		print_notification "Database Port: 3306 (or leave blank)"
		print_notification "Database Username: snort"
		print_notification "Database Password: $snort_mysql_pass"
		print_notification "Finally, the installer will give you the option of setting authentication. That's all up to you."
	fi
	;;
	
	4)
	echo "Configuring rsyslog output.."
	
	bash autosyslog_full-kali.sh
	if [ $? != 0 ]; then
		print_error "The installer script failed. Please review the installation log and try again."
		exit 1
	else
		print_good "Rsyslog output successfully configured."
		print_notification "Please ensure 514/udp outbound is open on THIS sensor."
		print_notification "Ensure 514/udp inbound is open on your syslog server/SIEM and is ready to recieve events."
	fi
	;;
	
	5)
	print_status "Running Snorby installer.."
	
	bash autosnorby-kali.sh
	if [ $? != 0 ]; then
		print_error "The installer script failed. Please review the installation log and try again."
		exit 1
	else
		print_good "Snorby successfully installed."
		print_notification "Default credentials are user: snorby@snorby.org password: snorby"
		print_notification "Be aware that snorby uses a 'worker' process to manage import of events/alerts. It is an asynchronous process, meaning stuff might not show up immediately."
		print_notification "If the system is rebooted, or isn't displaying events properly I recommend trying the following:"
		print_notification "Log in, navigate to Administration -> Worker & Job Queue and if the worker isn't running, start it. If it is running, restart it."
		print_notification "Additionally, Navigate to the Dashboard page, click More Options and select Force Cache Update."
	fi
	;;
	
	6)
	print_notification "No output interface has been installed per the config file."
	;;
	
	*)
	print_error "Invalid choice. Please check your config file and try again."
	exit 1
	;;
esac


#todo list: give users the ability to choose 2 interfaces or a bridge interface for inline deployments.

print_notification "If you chose to install a web interface, and have a firewall enabled on this system, make sure port 80 on your INBOUND chain is allowed in order to be able to browse to your web interface."
print_notification "One last choice. A reboot is recommended, considering all the configuration files we've messed with and updates that have been applied to the system." 

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