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

#Package installation function.

#Declaring Functions - This function is an easier way to reuse the yum code. 
function install_packages()
{
yum -y update &>> $logfile && yum -y install ${@} &>> $logfile
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

print_good "Rules processed successfully. Rules located in /usr/local/snort/rules."
print_notification "Pulledpork is located in /usr/src/pulledpork-[pulledpork version]."
print_notification "By default, Autosnort runs Pulledpork with the Security over Connectivity ruleset."
print_notification "If you want to change how pulled pork operates and/or what rules get enabled/disabled, Check out the /usr/src/pulledpork-[pulledpork version]/etc directory, and the .conf files contained therein."

#This cleans up all the dummy files in the snort config file directory, with the exception of the ones we want the script to keep in place.
for configs in `ls -1 /usr/local/snort/etc/* | egrep -v "snort.conf|sid-msg.map"`; do
	rm -rf $configs
done

print_status "Moving other snort configuration files.."
cd /tmp
tar -xzvf snortrules-snapshot-*.tar.gz &>> $logfile

for conffiles in `ls -1 /tmp/etc/* | egrep -v "snort.conf|sid-msg.map"`; do
	cp $conffiles /usr/local/snort/etc
done

cp /usr/src/$snortver/etc/gen-msg.map /usr/local/snort/etc

}

########################################

##BEGIN MAIN SCRIPT##

#Pre checks: These are a couple of basic sanity checks the script does before proceeding.

########################################

print_status "OS Version Check.."

# /etc/redhat-release differs between 6 and 7, so let's grab the whole thing.
# Use Perl regex engine (for negative lookbehinds) to ensure we account for major and minor versions (e.g. 6.7 and 7.4.1046)
if [[ `cat /etc/redhat-release | grep -P '(?<!\.)[67]\.[0-9]+(\.[0-9]+)?'` ]]; then
	print_good "OS is CentOS. Good to go."
else
    print_notification "This is not CentOS 6 or CentOS 7. Be aware this script has NOT been tested on other platforms (Including RHEL, Fedora and/or SuSE)."
	print_notification "If you choose to continue, please report your successes or failures!"
	while true; do
		read -p "Continue? (y/n)" warncheck
		case $warncheck in
        [Yy]* ) 
		break
		;;
        [Nn]* ) 
		print_error "Bailing." 
		exit 1
		;;
        * ) 
		print_notification "Please answer yes or no."
		;;
        esac
	done
fi

########################################

print_status "Checking for root privs.."
if [ $(whoami) != "root" ]; then
	print_error "This script must be ran with sudo or root privileges, or this isn't going to work."
	exit 1
else
	print_good "We are root."
fi
	 
########################################	 

print_status "Checking to ensure sshd is running.."

print_notification "`service sshd status`"

########################################

print_status "Wget check.."

/usr/bin/which wget &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Wget not found." 
	print_notification "Installing wget."
	install_packages wget
else
    print_good "Found wget."
fi

########################################

# System updates
print_status "Updating system via YUM (May take a while if this is a fresh install).."
yum -y update &>> $logfile
if [ $? -ne 0 ]; then
    print_error "YUM update failed. Please check $logfile for details."
	exit 1	
else
    print_good "Updates Installed."
fi

########################################

#The EPEL repos are required to install snort.
#Check to see if EPEL is already installed (Thanks for the suggestion!)
#If not, get the correct version and install it.
#Noticed that the EPEL RPM for 32 and 64-bit centos is exactly the same (identical md5sums)

rpm -q epel-release &>> $logfile
if [ $? -eq 0 ]; then
	print_good "EPEL package already installed."
else
	print_status "Installing EPEL repos for required packages to build snort on CentOS.."
	arch=`uname -i`
	epelrel=`echo $release|cut -d"." -f1`
	wget https://dl.fedoraproject.org/pub/epel/$epelrel/$arch -O epel-index.html &>> $logfile
	if [ $? -ne 0 ]; then
		print_error "failed to reach dl.fedoraproject.org."
		exit 1
	fi
	epel_package=`grep epel-release epel-index.html | cut -d'"' -f6`
	rm -rf epel-index.html
	wget https://dl.fedoraproject.org/pub/epel/$epelrel/$arch/$epel_package &>> $logfile
	if [ $? -ne 0 ]; then
		print_error "failed to acquire epel-release package."
		exit 1
	fi
	rpm -Uvh $epel_package &>> $logfile
	if [ $? -eq 0 ]; then
		print_good "EPEL RPM acquired and successfully installed."	
		rm -rf $epel_package
	else
		print_error "Failed to install EPEL package. Please check $logfile for details."
		exit 1
	fi
fi

########################################

#These packages are required at a minimum to build snort and barnyard + their component libraries

print_status "Installing base packages: ethtool make zlib-devel gcc libtool pcre-devel libdnet-devel libpcap-devel mysql-devel flex bison autoconf.. "

declare -a packages=( ethtool make zlib-devel gcc libtool pcre-devel libdnet-devel libpcap-devel mysql-devel flex bison autoconf );
install_packages ${packages[@]}

########################################

#We give the user a choice whether or not they want mysql and/or httpd installed to support a web interface for event review.
#If they decide they want mysql and httpd, we generate a private key and self-signed cert for HTTPS operation and back up the default configuration files. ssl.conf gets moved otherwise it interferes with the SSL virtual hosts we make.

#We run the secure install script to force the user to assign a password for database privs.
#We also have to add httpd and mysqld services manually via chkconfig, and start them.

while true; do
	print_notification "Do you plan on installing a web interface to review intrusion events, such as snortreport, aanval or base? (If in doubt, select option 1)"
	read -p "
1 is yes
2 is no
" ui_inst
	case $ui_inst in
	1)
	print_status "Acquiring and installing mysql and httpd.."
	declare -a packages=( httpd mysql mysql-bench mysql-server mod_ssl );
	install_packages ${packages[@]}
	service mysqld start &>> $logfile
	service httpd start &>> $logfile
	chkconfig mysqld --add &>> $logfile
	chkconfig httpd --add &>> $logfile
	chkconfig mysqld --level 3 on &>> $logfile
	chkconfig httpd --level 3 on &>> $logfile
	print_status "Running mysql_secure_installation script.."
	/usr/bin/mysql_secure_installation
	if [ $? -ne 0 ]; then
		print_error "The secure installation script Failed to run. Please check $logfile for details."
		exit 1	
	else
		print_good "Secure installation script completed."
	fi
	
	print_status "Generating a private key and self-signed SSL certificate for HTTPS operation.."
	mkdir /etc/httpd/ssl
	cd /etc/httpd/ssl
	openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=Nevada/L=LasVegas/O=Security/CN=ids.local" -keyout ids.key  -out ids.cert &>> $logfile
	if [ $? -ne 0 ]; then
		print_error "Something went wrong during private and certificate generation. Please check $logfile for details."
		exit 1
	else
		print_good "Private Key and Self-Signed Certificate generated. Location:"
		print_good "/etc/httpd/ssl/ids.key"
		print_good "/etc/httpd/ssl/ids.cert"
	fi
	
	chmod 600 /etc/httpd/ssl/ids.*
	mv /etc/httpd/conf.d/ssl.conf /etc/httpd/sslconf.bak
	cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.orig
	
	break
	;;
	2)
	print_notification "You've chosen to not install a mysql server or apache. This means you will NOT be able to install a web interface on this sensor."
	break
	;;
	*)
	print_notification "Invalid choice, please enter 1 or 2."
	continue
	;;
	esac
done

########################################
#This section is a hack I implemented using wget, grep and cut. We pull the downloads page from snort.org and cut out some strings to determine the version of snort and/or daq to pull.
#After that we pull snort and daq, them compile them.

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

rm /tmp/snort-downloads
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

########################################

# The --enable-sourcefire option gives us ppm and perfstats for performance troubleshooting.

cd /usr/src
tar -xzvf $snorttar &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to untar $snorttar. Please check $logfile for details."
	exit 1	
fi

cd $snortver

print_status "configuring snort (options --prefix=/usr/local/snort and --enable-sourcefire), making and installing. This will take a moment or two.."

./configure --prefix=/usr/local/snort --enable-sourcefire &>> $logfile
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

#supporting infrastructure for snort.

print_status "Creating directories /var/log/snort, and /var/snort."

mkdir /var/snort && mkdir /var/log/snort

print_status "Creating snort user and group, assigning ownership of /var/log/snort to snort user and group."

#users and groups for snort to run non-priveledged. snort's login shell is set to /bin/false to enforce the fact that this is a service account.

groupadd snort
useradd -g snort snort -s /bin/false
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

mkdir -p /usr/local/snort/etc
mkdir -p /usr/local/snort/so_rules
mkdir -p /usr/local/snort/rules
mkdir -p /usr/local/snort/preproc_rules
mkdir -p /usr/local/snort/lib/snort_dynamicrules

#we wget the snort-rules page off  snort.org, do a lot of text manipulation from the html file downloaded, and set variables: two variables for attempting to downloading the VRT example snort.conf from labs.snort.org, and four variables for the version of snort to download rules for via pulledpork.
print_status "Checking current rule releases on snort.org.."

wget http://www.snort.org -O /tmp/snort-rules &>> $logfile
if [ $? -ne 0 ]; then
	print_error "Failed to contact snort.org. Please check $logfile for details."
	continue	
fi

choice1conf=`grep snortrules-snapshot-[0-9][0-9][0-9][0-9] /tmp/snort-rules|cut -d"-" -f3 |cut -d"." -f1 | sort -ur | head -1` #snort.conf download attempt 1
choice2conf=`grep snortrules-snapshot-[0-9][0-9][0-9][0-9] /tmp/snort-rules|cut -d"-" -f3 |cut -d"." -f1 | sort -ur | head -2 | tail -1` #snort.conf download attempt 2
choice1=`echo $choice1conf |sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./'` #pp config choice 1
choice2=`echo $choice2conf | sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./'` #pp config choice 2
choice3=`grep snortrules-snapshot-[0-9][0-9][0-9][0-9] /tmp/snort-rules|cut -d"-" -f3 |cut -d"." -f1 | sort -ru | head -3 | tail -1 | sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./'`
choice4=`grep snortrules-snapshot-[0-9][0-9][0-9][0-9] /tmp/snort-rules|cut -d"-" -f3 |cut -d"." -f1 | sort -ru | head -4| tail -1 | sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./'`

wget http://labs.snort.org/snort/$choice1conf/snort.conf -O /usr/local/snort/etc/snort.conf &>> $logfile
if [ $? != 0 ];then
	print_error "Attempt to download a $choice1 snort.conf from labs.snort.org failed. attempting to download snort.conf for $choice2"
	wget http://labs.snort.org/snort/$choice2conf/snort.conf -O /usr/local/snort/etc/snort.conf &>> $logfile
	if [ $? != 0 ];then
		print_error "This attempt to download a snort.conf has failed as well. Aborting pulledpork rule installation.Check $logfile for details."
		continue 
	else
		print_notification "Successfully downloaded snort.conf for $prevver. This will likely work for now until they upload a new snort.conf to labs.snort.org."
	fi
else
	print_good "Successfully downloaded snort.conf for $choice1."
fi

#Trim up snort.conf as necessary to work properly. Why was this moved? Because SO stub files weren't being generated properly because the snort.conf wasn't properly tuned prior to having pulled pork attempt to dump the SO stub files from snort.

print_status "ldconfig processing and creation of whitelist/blacklist.rules files taking place."

touch /usr/local/snort/rules/white_list.rules && touch /usr/local/snort/rules/black_list.rules && ldconfig

print_status "Modifying snort.conf -- specifying unified 2 output, SO whitelist/blacklist and standard rule locations.."

sed -i 's/dynamicpreprocessor directory \/usr\/local\/lib\/snort_dynamicpreprocessor\//dynamicpreprocessor directory \/usr\/local\/snort\/lib\/snort_dynamicpreprocessor\//' /usr/local/snort/etc/snort.conf
sed -i 's/dynamicengine \/usr\/local\/lib\/snort_dynamicengine\/libsf_engine.so/dynamicengine \/usr\/local\/snort\/lib\/snort_dynamicengine\/libsf_engine.so/' /usr/local/snort/etc/snort.conf
sed -i 's/dynamicdetection directory \/usr\/local\/lib\/snort_dynamicrules/dynamicdetection directory \/usr\/local\/snort\/lib\/snort_dynamicrules/' /usr/local/snort/etc/snort.conf
sed -i 's/# output unified2: filename merged.log, limit 128, nostamp, mpls_event_types, vlan_event_types/output unified2: filename snort.u2, limit 128/' /usr/local/snort/etc/snort.conf
sed -i 's/var WHITE_LIST_PATH ..\/rules/var WHITE_LIST_PATH \/usr\/local\/snort\/rules/' /usr/local/snort/etc/snort.conf
sed -i 's/var BLACK_LIST_PATH ..\/rules/var BLACK_LIST_PATH \/usr\/local\/snort\/rules/' /usr/local/snort/etc/snort.conf
sed -i 's/include \$RULE\_PATH/#include \$RULE\_PATH/' /usr/local/snort/etc/snort.conf
echo "# unified snort.rules entry" >> /usr/local/snort/etc/snort.conf
echo "include \$RULE_PATH/snort.rules" >> /usr/local/snort/etc/snort.conf

#making a copy of our fully configured snort.conf, and touching some files into existence, so snort doesn't barf when executed to generate the so rule stubs.
#These are blank files (except unicode.map, which snort will NOT start without the real deal), but if they don't exist, snort barfs when pp uses it to generate SO stub files.

touch /usr/local/snort/etc/reference.config
touch /usr/local/snort/etc/classification.config
cp /usr/src/$snortver/etc/unicode.map /usr/local/snort/etc/unicode.map
touch /usr/local/snort/etc/threshold.conf
touch /usr/local/snort/rules/snort.rules


print_good "snort.conf configured. location: /usr/local/snort/etc/snort.conf"


#setting the stage for downloading and installation of pulled pork.

cd /usr/src

print_status "Acquiring packages for pulled pork"
declare -a packages=( perl perl-Crypt-SSLeay perl-libwww-perl perl-Archive-Tar perl-IO-Socket-SSL );
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

#Create a copy of the original conf file (in case the user needs it), ask the user for an oink code, then fill out a really stripped down pulledpork.conf file with only the lines needed to run the perl script

cp pulledpork.conf pulledpork.conf.orig

read -p "What is your oink code?   " o_code
echo "rule_url=https://www.snort.org/reg-rules/|snortrules-snapshot.tar.gz|$o_code" > pulledpork.tmp
echo "rule_url=https://www.snort.org/reg-rules/|opensource.gz|$o_code" >> pulledpork.tmp
echo "rule_url=https://s3.amazonaws.com/snort-org/www/rules/community/|community-rules.tar.gz|Community" >> pulledpork.tmp
echo "rule_url=http://labs.snort.org/feeds/ip-filter.blf|IPBLACKLIST|open" >> pulledpork.tmp
echo "ignore=deleted.rules,experimental.rules,local.rules" >> pulledpork.tmp
echo "temp_path=/tmp" >> pulledpork.tmp
echo "rule_path=/usr/local/snort/rules/snort.rules" >> pulledpork.tmp
echo "local_rules=/usr/local/snort/rules/local.rules" >> pulledpork.tmp
echo "sid_msg=/usr/local/snort/etc/sid-msg.map" >> pulledpork.tmp
echo "sid_msg_version=2" >> pulledpork.tmp
echo "sid_changelog=/var/log/sid_changes.log" >> pulledpork.tmp
echo "sorule_path=/usr/local/snort/lib/snort_dynamicrules/" >> pulledpork.tmp
echo "snort_path=/usr/local/snort/bin/snort" >> pulledpork.tmp
echo "distro=Centos-5-4" >> pulledpork.tmp
echo "config_path=/usr/local/snort/etc/snort.conf" >> pulledpork.tmp
echo "black_list=/usr/local/snort/rules/black_list.rules" >>pulledpork.tmp
echo "IPRVersion=/usr/local/snort/rules/iplists" >>pulledpork.tmp	
echo "ips_policy=security" >> pulledpork.tmp
echo "version=0.7.0" >> pulledpork.tmp
cp pulledpork.tmp pulledpork.conf
	
#the actual PP routine: give them a choice to try and download rules for the four most recent versions of snort. run PP twice for each case statement - the first time downloads the rules to /tmp so we can copy configuration files to /usr/local/snort/etc. The second time actually processes the rules. If the user cannot download the snort rules tarball for the most recent snort release (no VRT subscription), and has to download rules for any previous version of snort, pulledpork is configured to process text rules only; this is to ensure SO rule compatibility problems don't occur and break snort entirely.			
while true; do		
	print_notification "Since this script can't tell how many days it has been since snort $choice1 has been released, and I don't want to waste 15 minutes of your time, what version of snort do want to download rules for?"
	read -p "
Select 1 to download rules for snort $choice1 (Select this if it has been more than 30 days since snort $choice1 has been released or if you have a VRT rule subscription oinkcode)
Select 2 to download rules for snort $choice2 (Select this if it has been less than 30 days since snort $choice1 has been released or you do NOT have a VRT rule subscription oinkcode)
Select 3 to download rules for snort $choice3 (Select this if it has been less than 30 days since snort $choice1 AND $choice2 have been released and you do not have a VRT rule subscription oinkcode)
Select 4 to download rules for snort $choice4 (Select this as a last resort, if all other options do not work.)
" pp_choice
	cd /usr/src/pulledpork-*
	case $pp_choice in
		1)
		print_status "downloading rules for $choice1 .."
		perl pulledpork.pl -c /usr/src/pulledpork-*/etc/pulledpork.conf -vv &>> $logfile
		if [ $? != 0 ]; then
			print_error "rule download for $choice1 snort rules has failed. Check $logfile for details. Rememeber to wait AT LEAST 15 minutes before attempting another download."
			continue
		else 
			pp_postprocessing
		fi
		break
		;;
		2)
		print_status "downloading rules for $choice2 .."
		perl pulledpork.pl -S $choice2 -c /usr/src/pulledpork-*/etc/pulledpork.conf -T -vv &>> $logfile
		if [ $? != 0 ]; then
			print_error "rule download for $choice2 snort rules has failed. Check $logfile for details. Rememeber to wait AT LEAST 15 minutes before attempting another download."
			continue
		else
			pp_postprocessing
		fi
		break
		;;
		3)
		print_status "downloading rules for $choice3 .."
		perl pulledpork.pl -S $choice3 -c /usr/src/pulledpork-*/etc/pulledpork.conf -T -vv &>> $logfile
		if [ $? != 0 ]; then
			print_error "rule download for $choice3 snort rules has failed. Check $logfile for details. Rememeber to wait AT LEAST 15 minutes before attempting another download."
			continue
		else
			pp_postprocessing
		fi
		break
		;;
		4)
		print_status "downloading rules for $choice4 .."
		perl pulledpork.pl -S $choice4 -c /usr/src/pulledpork-*/etc/pulledpork.conf -T -vv &>> $logfile
		if [ $? != 0 ]; then
			print_error "rule download for $choice4 snort rules has failed. Check $logfile for details. Rememeber to wait AT LEAST 15 minutes before attempting another download."
			continue
		else
			pp_postprocessing
		fi
		break
		;;
		*)
		print_notification "Invalid selection. Please try again."
		continue
		;;
	esac
done


########################################

#now we have to download barnyard 2 and configure all of its stuff.

print_status "Downloading, making and compiling barnyard2.."

cd /usr/src

wget https://github.com/firnsy/barnyard2/archive/master.tar.gz -O barnyard2.tar.gz &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to download barnyard2 from github.com. Please see $logfile for details."
	exit 1	
else
    print_good "Downloaded barnyard2 to /usr/src."
fi

########################################

tar -xzvf barnyard2.tar.gz &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to untar barnyard2. see $logfile for details"
	exit 1	
fi

########################################

cd barnyard2*

#need to run autoreconf before we can compile it.

autoreconf -fvi -I ./m4 &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Autoreconf for barnyard2 failed. see $logfile for details"
	exit 1	
fi

#This is a new work-around to find libmysqlclient.so, instead of it/then statements based on architecture.

mysqllibloc=`find /usr/lib* -name libmysqlclient.so`

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

cp etc/barnyard2.conf /usr/local/snort/etc
mkdir -p /var/log/barnyard2
chmod 666 /var/log/barnyard2
touch /var/log/snort/barnyard2.waldo
chown snort.snort /var/log/snort/barnyard2.waldo

#keep an original copy of the by2.conf in case the user needs to change settings.
cp /usr/local/snort/etc/barnyard2.conf /usr/local/snort/etc/barnyard2.conf.orig

echo "config reference_file:	/usr/local/snort/etc/reference.config" >> /root/barnyard2.conf.tmp
echo "config classification_file:	/usr/local/snort/etc/classification.config" >> /root/barnyard2.conf.tmp
echo "config gen_file:	/usr/local/snort/etc/gen-msg.map" >> /root/barnyard2.conf.tmp
echo "config sid_file:	/usr/local/snort/etc/sid-msg.map" >> /root/barnyard2.conf.tmp
echo "config hostname: localhost" >> /root/barnyard2.conf.tmp

# The if/then check here is to make sure the user chose to install a web interface. If they chose no, they chose not to install mysql server, so we can skip all this.

if [ $ui_inst = 1 ]; then
	print_status "Integrating mysql with barnyard2.."
	# We need to ask the user to provide a password for the snort database user.
	# We save the snort database user's password as an environment variable, and in the barnyard2.conf.tmp file
	# This is so we can re-use this variable for child shell scripts (e.g. scripts that install the different web interfaces)
	# This environment variable should last the life of the shell script, but should not become a permanent environment variable.
	while true; do
		print_notification "Please enter a password for the snort database user. This user will be used to access the intrusion event database that barnyard2 populates."
		echo ""
		read -s -p "Please enter the snort database user password:" MYSQL_PASS_1
		echo ""
		read -s -p "Confirm:" mysql_pass_2
		echo ""
		if [ "$MYSQL_PASS_1" == "$mysql_pass_2" ]; then
			print_good "password confirmed."
			export MYSQL_PASS_1
			echo "output database: log,mysql, user=snort password=$MYSQL_PASS_1 dbname=snort host=localhost" >> /root/barnyard2.conf.tmp
			break
		else
			print_notification "Passwords do not match. Please try again."
			continue
		fi
	done

#The next few steps build the snort database, create the database schema, and grants the snort database user permissions to fully modify contents within the database.
#We ask the user for the root mysql user's password 3 times, one for each task.
	print_notification "The next several steps will need you to enter the mysql root user password."

	#1. If the database exists, we blow it away to ensure a clean install.

	while true; do
		print_notification "Enter the mysql root user password to create the snort database."
		print_notification "If you already have a database named snort, this WILL drop that database!"
		mysql -u root -p -e "drop database if exists snort; create database if not exists snort; show databases;" &>> $logfile
		if [ $? != 0 ]; then
			print_error "the command did NOT complete successfully. Please see $logfile, confirm the root mysql user password, and try again."
			continue
		else
			print_good "snort database created!"
			break
		fi
	done

	#2. Add the schema

	while true; do
		print_notification "enter the mysql root user password again to create the snort database schema"
		mysql -u root -p -D snort < /usr/src/barnyard2*/schemas/create_mysql &>> $logfile
		if [ $? != 0 ]; then
			print_error "the command did NOT complete successfully. Please see $logfile, confirm the root mysql user password, and try again."
			continue
		else
			print_good "snort database schema created!"
			break
		fi
	done

	#3. Grant the snort database user permissions to do what is necessary to maintain the database.

	while true; do
		print_notification "you'll need to enter the mysql root user password one more time to create the snort database user and grant it permissions to the snort database."
		mysql -u root -p -e "grant create, insert, select, delete, update on snort.* to snort@localhost identified by '$MYSQL_PASS_1';" &>> $logfile
		if [ $? != 0 ]; then
			print_error "the command did NOT complete successfully. Please see $logfile, confirm the root mysql user password, and try again."
			continue
		else
			print_good "snort database user created!"
			break
		fi
	done
else
	print_notification "You chose to not install mysql-server earlier."
	print_notificiation "Follow the prompts below if you have a remote mysql server you want barnyard2 to report events to."
	while true; do
		read -p "Do you have a remote mysql database/C2 system that you want barnyard2 to report events to?
		Select 1 for yes
		Select 2 for no
		" r_dbase
		case $r_dbase in
			1)
			read -p "enter the database username: " rdb_user
			read -p "enter the remote database name: " rdb_name
			read -p "enter the remote database hostname/ip: " rdb_host
			read -s -p "enter the remote database user password: " rdb_pass_1
			echo ""
			read -s -p "Confirm: " rdb_pass_2
			if [ "$rdb_pass_1" == "$rdb_pass_1" ]; then
				print_good "password confirmed."
			else
				print_notification -e "Passwords do not match. Please try again."
				continue
			fi
			echo "output database: log,mysql, user=$rdb_user password=$rdb_pass_1 dbname=$rdb_name host=$rdb_host" >> /root/barnyard2.conf.tmp
			break
			;;
			2)
			print_notification "You have indicated that you do not have a remote have a remote database to report events to."
			print_notification "You have also indicated you have no desire to install a local database or webUI for local events"
			print_notification "The only valid output options you will have available will be rsyslog or no output!"
			break
			;;
			*)
			print_notification "Invalid choice, please try again."
			continue
			;;
		esac
	done
fi
	
cd /root

#We have the user decide what interface snort will be listening on. This is setup for the next couple of statements (e.g. if they want the interface up and sniffing at boot, etc.). The first choice here is to pretty up barnyard 2 output)

while true; do
	print_notification "What interface will snort listen on? (please choose only one interface)"
	read -p "
Based on output from ifconfig, here are your choices:
`ifconfig -a | grep encap | grep -v lo`
" snort_iface
	ifconfig $snort_iface &>> $logfile
	if [ $? != 0 ]; then
		print_notification "That interface doesn't seem to exist. Please try again."
		continue
	else
		if [ "$snort_iface" = "lo" ]; then
			print_notification "And what, dear user, do you expect to find on the loopback interface? Try again."
			continue
		else
			print_status "Configuring to monitor on $snort_iface.."
			break
		fi
	fi
done

echo "config interface: `hostname`-$snort_iface" >> /root/barnyard2.conf.tmp
echo "input unified2" >> /root/barnyard2.conf.tmp


cp /root/barnyard2.conf.tmp /usr/local/snort/etc/barnyard2.conf

#cleaning up the temp file

rm /root/barnyard2.conf.tmp

print_good "Barnyard2 configuration completed."

########################################

#The choice above determines whether or not we'll be adding an entry to /etc/sysconfig/network-scripts  for the snort interface and adding the rc.local hack to bring snort's sniffing interface up at boot. We also run ethtool to disable checksum offloading and other nice things modern NICs like to do; per the snort manual, leaving these things enabled causes problems with rules not firing properly. We give the user the choice of not doing this, in the case that they may not have two dedicated network interfaces available.

print_notification "Disabling LRO and GRO on the sniffing interface.."
ethtool -K $snort_iface gro off &>> $logfile
ethtool -K $snort_iface lro off &>> $logfile

while true; do
	print_notification "Would you like to have $snort_iface configured to run in promiscuous mode on boot? THIS IS REQUIRED if you want snort to run Daemonized on boot."
	print_notification "BE AWARE: If you choose this option, $snort_iface will not respond to any traffic on its interface. If $snort_iface is the only interface on your system, this isn't a good idea."
	read -p "
Selecting 1 adds an entry to rc.local to bring the interface up in promiscuous mode with no arp or multicast response to prevent discovery of the sniffing interface.
Selecting 2 does nothing and lets you configure things on your own.
" boot_iface

	case $boot_iface in
		1 )
		print_status "Adding ifconfig line for $snort_iface to rc.local.."
        cat /etc/rc.local | grep -v exit > /root/rc.local.tmp
		echo "ifconfig $snort_iface up -arp -multicast promisc" >> /root/rc.local.tmp
		cp /root/rc.local.tmp /etc/rc.local
		print_good "$snort_iface successfully configured to up on boot."
		break
        ;;
        2 )
        print_notification "You're on your own then."
		break
        ;;
        * )
		print_notification "I didn't understand your answer. Please try again."
		continue
        ;;
	esac
done

#We ask the user if they want snort and barnyard dropped to rc.local. We also do some fault checking. If they choose to NOT have an interface up and ready for snort at boot, we don't let them start barnyard2 or snort via rc.local (they would just error out anyhow)

while true; do
	print_notification "We're almost finished! Do you want snort and barnyard to run at startup?"
	read -p "
Select 1 for entries to be added to rc.local. BEWARE: IF you selected to not have the boot interface brought up on startup, you are advised to select option two; snort and barnyard cannot run successfully without an interface to bind to on startup.
Select 2 If you do not have an interface to dedicate to sniffing traffic only or do not want snort or barnyard to run on system startup.
" startup_choice

# There's an if statement in here for a specific reason:
# If a user makes a choice that they want snort to run on bootup, but do not configure the snort interface to be up on system startup
	case $startup_choice in
		1 )
		print_status "Adding snort and barnyard2 to rc.local.."
		cp /etc/rc.local /root/rc.local.tmp
		if [ $boot_iface = "1" ]; then
			echo "#start snort as user/group snort, Daemonize it, read snort.conf and run against $snort_iface" >> /root/rc.local.tmp
			echo "/usr/local/snort/bin/snort -D -u snort -g snort -c /usr/local/snort/etc/snort.conf -i $snort_iface" >> /root/rc.local.tmp
			echo "/usr/local/bin/barnyard2 -c /usr/local/snort/etc/barnyard2.conf -d /var/log/snort -f snort.u2 -w /var/log/snort/barnyard2.waldo -D" >> /root/rc.local.tmp
			cp /root/rc.local.tmp /etc/rc.local
			rm /root/rc.local.tmp
			print_good "Snort and barnyard successfully added to /etc/rc.local."
			break
		else
			print_notification "You've specified to start barnyard and snort at boot, but do not have $snort_iface to be up and listening at boot. This is will not work! Please selection option 2 to continue."
			continue
		fi
		;;
		2 )
		print_good "Confirmed. Snort and Barnyard will NOT be configured to start on system boot."
		break
			;;
		* )
		print_notification "Invalid choice. Please try again."
		;;
	esac
done

#Perform the interface installation step here. first, we drop back to the initial working directory where autosnort was ran from.
while true; do
	print_good "Please select an output interface to install:"
	print_notification "1. Snort Report"
	print_notification "2. Aanval"
	print_notification "3. BASE"
	print_notification "4. Rsyslog"
	print_notification "5. Snorby"
	print_notification "6. no web interface or output method will be installed (Select this if you configured barnyard2 to log to a remote database, or need no output interface at this time)"
	read -p "Please choose an option: " ui_choice
	case $ui_choice in
		1)
		print_status "Running Snort Report installer.."
		bash snortreport-CentOS.sh
		if [ $? != 0 ]; then
			print_error "It looks like the installation did not go as according to plan."
			echo "Verify you have network connectiviy and try again"
			continue
		else
			print_good "Snort Report installation successful."
			print_notification "Navigate to http://[ip address] to get started."
			break
		fi
		;;
		2)
		print_status "Running Aanval installer.."
		bash aanval-CentOS.sh
		if [ $? != 0 ]; then
			print_error "It looks like the installation did not go as according to plan."
			echo "Verify you have network connectiviy and try again"
			continue
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
			break
		fi
		;;
		3)
		print_status "Running BASE installer.."
		bash base-CentOS.sh
		if [ $? != 0 ]; then
			print_error "It looks like the installation did not go as according to plan."
			echo "Verify you have network connectiviy and try again"
			continue
		else
			print_good "BASE installation successful."
			print_notification "Navigate to http://[ip address] to get started"
			print_notification "You will be asked where adodb is installed: /usr/share/php/adodb"
			print_notification "You will asked for Database information as well:"
			print_notification "Database Name: snort"
			print_notification "Datahase Host: localhost"
			print_notification "Database Port: 3306 (or leave blank)"
			print_notification "Database Username: snort"
			print_notification "Database Password: $MYSQL_PASS_1"
			print_notification "Finally, the installer will give you the option of setting authentication. That's all up to you."
			break
		fi
		;;
		4)
		echo "Running rsyslog configuration.."
		bash syslog_full-CentOS.sh
		if [ $? != 0 ]; then
			print_error "It looks like the installation did not go as according to plan."
			print_notification "Please try again"
			continue
		else
			print_good "Rsyslog output successfully configured."
			print_notification "Please ensure 514/udp outbound is open on THIS sensor."
			print_notification "Ensure 514/udp inbound is open on your syslog server/SIEM and is ready to receive events."
			break
		fi
		;;
		5)
		print_status "Running Snorby Installer.."
		bash snorby-CentOS.sh
		if [ $? != 0 ]; then
			print_error "It looks like the installation did not go as according to plan."
			echo "Please try again"
			continue
		else
			print_good "Snorby successfully installed."
			print_notification "Default credentials are user: snorby@snorby.org password: snorby"
			print_notification "Be aware that snorby uses a 'worker' process to manage import of events/alerts. It is an asynchronous process, meaning stuff might not show up immediately."
			print_notification "If the system is rebooted, or isn't displaying events properly I recommend trying the following:"
			print_notification "Log in, navigate to Administration -> Worker & Job Queue and if the worker isn't running, start it. If it is running, restart it."
			print_notification "Additionally, Navigate to the Dashboard page, click More Options and select Force Cache Update."
			break
		fi
		;;
		6)
		print_notification "You have chosen to not install any interface (Web or syslog)"
		print_notification "Either you plan on using snort for research/rule writing purposes.. or Have a remote database/C2 system you will be reporting events to."
		break
		;;
		*)
		print_notification "invalid choice. please try again."
		continue
		;;
	esac
done

#todo list: give users the ability to choose 2 interfaces or a bridge interface for inline deployments.

print_notification "Be aware that RHEL derivatives ship with iptables enabled by default. If you elected to install a web interface, use the command system-configure-firewall-tui to allow access to WWW and Secure WWW inbound on this sytem to access your web interface!"
print_notification "One last choice. A reboot is recommended, considering all the configuration files we've messed with and updates that have been applied to the system." 
print_notification "Do you want to reboot now or later? Again, 1 is yes, 2 is no."

read reboot_choice

case $reboot_choice in
	1)
	print_status "Rebooting now."
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
