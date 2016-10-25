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
print_notification "Pulledpork is located in /usr/src/pulledpork."
print_notification "By default, Autosnort runs Pulledpork with the Security over Connectivity ruleset."
print_notification "If you want to change how pulled pork operates and/or what rules get enabled/disabled, Check out the /usr/src/pulledpork/etc directory, and the .conf files contained therein."

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
echo "  0  0  *  *  7  root /usr/src/pulledpork/pulledpork.pl -c /usr/src/pulledpork/etc/pulledpork.conf" >> /etc/crontab

print_notification "crontab has been modified. If you want to modify when pulled pork runs to check rule updates, modify /etc/crontab."

}

#This script creates a lot of directories by default. This is a function that checks if a directory already exists and if it doesn't creates the directory (including parent dirs if they're missing).

########################################

function dir_check()
{

if [ ! -d $1 ]; then
	print_notification "$1 does not exist. Creating.."
	mkdir -p $1
else
	print_notification "$1 already exists."
fi

}

########################################
##BEGIN MAIN SCRIPT##

#Pre checks: These are a couple of basic sanity checks the script does before proceeding.

########################################

#These lines establish where autosnort was executed. The config file _should_ be in this directory. the script exits if the config isn't in the same directory as the autosnort-ubuntu shell script.

print_status "Checking for config file.."
execdir=`pwd`
if [ ! -f "$execdir"/full_autosnort.conf ]; then
	print_error "full_autosnort.conf was NOT found in $execdir. The script relies HEAVILY on this config file. Please make sure it is in the same directory you are executing the autosnort-ubuntu script from!"
	exit 1
else
	print_good "Found config file."
fi

source "$execdir"/full_autosnort.conf

########################################

print_status "Checking for root privs.."
if [ $(whoami) != "root" ]; then
	print_error "This script must be ran with sudo or root privileges."
	exit 1
else
	print_good "We are root."
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

print_status "Installing base packages: libdumbnet-dev ethtool build-essential libpcap0.8-dev libpcre3-dev bison flex autoconf libtool libarchive-tar-perl libcrypt-ssleay-perl libwww-perl zlib1g-dev.."

declare -a packages=( libdumbnet-dev ethtool build-essential libpcap0.8-dev libpcre3-dev bison flex autoconf libtool libarchive-tar-perl libcrypt-ssleay-perl libwww-perl zlib1g-dev );
install_packages ${packages[@]}

#Ubuntu and Debian-based distros renamed libdnet to libdumbnet due to a library conflict. We create a symlink from libdumbnet.h to libdnet.h because barnyard 2 is expecting to find dnet.h, and does NOT look for dumbnet.h 

if [ ! -h /usr/include/dnet.h ]; then
print_status "Creating symlink for libsfbpf.so.0 on default ld library path.."
ln -s /usr/include/dumbnet.h  /usr/include/dnet.h
fi

########################################
# We download the index page from snort.org
# Then using shell text manipulation tools (grep, cut, sed, head, tail) we pull:
# The snort and daq version to download
# Some text manipulation to pull a snort.conf file versions to download from labs.snort.org
# The last four supported snort rule tarball versions

print_status "Checking latest versions of Snort, Daq and Rules via snort.org..."

cd /tmp
wget https://www.snort.org -O /tmp/snort &> $logfile
error_check 'Download of snort.org index page'
wget https://www.snort.org/configurations -O /tmp/snort_conf &> $logfile
error_check 'Download of snort.conf examples page'

snorttar=`grep -o snort-[0-9]\.[0-9]\.[0-9]\.[0-9].tar.gz /tmp/snort | head -1`
daqtar=`egrep -o "daq-.*.tar.gz" /tmp/snort | head -1 | cut -d"<" -f1`
snortver=`echo $snorttar | sed 's/.tar.gz//g'`
daqver=`echo $daqtar | sed 's/.tar.gz//g'`

choice1conf=`egrep -o "snort-.*-conf" /tmp/snort_conf | sort -ru | head -1` #snort.conf download attempt 1
choice2conf=`egrep -o "snort-.*-conf" /tmp/snort_conf | sort -ru | head -2 | tail -1` #snort.conf download attempt 2
choice2=`grep snortrules-snapshot-[0-9][0-9][0-9][0-9] /tmp/snort |cut -d"-" -f3 |cut -d"." -f1 | sort -ru | head -1 | sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./'` #pp config choice 1
choice3=`grep snortrules-snapshot-[0-9][0-9][0-9][0-9] /tmp/snort |cut -d"-" -f3 |cut -d"." -f1 | sort -ru | head -2 | tail -1 | sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./'` #pp config choice 2
choice4=`grep snortrules-snapshot-[0-9][0-9][0-9][0-9] /tmp/snort |cut -d"-" -f3 |cut -d"." -f1 | sort -ru | head -3 | tail -1 | sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./'`

rm /tmp/snort
rm /tmp/snort_conf
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
dir_check $snort_basedir/lib

cd $snortver

print_status "configuring snort (options --prefix=$snort_basedir and --enable-sourcefire), making and installing. This will take a moment or two."

./configure --prefix=$snort_basedir --libdir=$snort_basedir/lib --enable-sourcefire &>> $logfile
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

print_status "Attempting to download .conf file for $snortver.."

wget https://www.snort.org/documents/$choice1conf -O $snort_basedir/etc/snort.conf --no-check-certificate &>> $logfile

if [ $? != 0 ];then
	print_error "Attempt to download $snortver conf file from snort.org failed. attempting to download $choice2conf.."
	wget https://www.snort.org/documents/$choice2conf -O $snort_basedir/etc/snort.conf --no-check-certificate &>> $logfile
	error_check 'Download of secondary snort.conf'
else
	print_good "Successfully downloaded .conf file for $snortver."
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

if [ -d /usr/src/pulledpork ]; then
	rm -rf /usr/src/pulledpork
fi

print_status "Acquiring Pulled Pork.."

git clone https://github.com/shirkdog/pulledpork.git &>> $logfile
error_check 'Download of pulledpork'

print_good "Pulledpork successfully installed to /usr/src."

print_status "Generating pulledpork.conf."

cd pulledpork/etc

#Create a copy of the original conf file (in case the user needs it), ask the user for an oink code, then fill out a really stripped down pulledpork.conf file with only the lines needed to run the perl script
cp pulledpork.conf pulledpork.conf.orig

echo "rule_url=https://www.snort.org/reg-rules/|snortrules-snapshot.tar.gz|$o_code" > pulledpork.tmp
echo "rule_url=https://www.snort.org/reg-rules/|opensource.gz|$o_code" >> pulledpork.tmp
echo "rule_url=https://snort.org/downloads/community/|community-rules.tar.gz|Community" >> pulledpork.tmp
echo "rule_url=http://talosintel.com/feeds/ip-filter.blf|IPBLACKLIST|open" >> pulledpork.tmp
echo "ignore=deleted.rules,experimental.rules,local.rules" >> pulledpork.tmp
echo "temp_path=/tmp" >> pulledpork.tmp
echo "rule_path=$snort_basedir/rules/snort.rules" >> pulledpork.tmp
echo "local_rules=$snort_basedir/rules/local.rules" >> pulledpork.tmp
echo "sid_msg=$snort_basedir/etc/sid-msg.map" >> pulledpork.tmp
echo "sid_msg_version=2" >> pulledpork.tmp
echo "sid_changelog=/var/log/sid_changes.log" >> pulledpork.tmp
echo "sorule_path=$snort_basedir/snort_dynamicrules/" >> pulledpork.tmp
echo "snort_path=$snort_basedir/bin/snort" >> pulledpork.tmp
echo "distro=Ubuntu-12-04" >> pulledpork.tmp
echo "config_path=$snort_basedir/etc/snort.conf" >> pulledpork.tmp
echo "black_list=$snort_basedir/rules/black_list.rules" >>pulledpork.tmp
echo "IPRVersion=$snort_basedir/rules/iplists" >>pulledpork.tmp	
echo "ips_policy=security" >> pulledpork.tmp
echo "version=0.7.2" >> pulledpork.tmp
cp pulledpork.tmp pulledpork.conf

#Run pulledpork. If the first rule download fails, we try again, and so on until there are no other snort rule tarballs to attempt to download.

cd /usr/src/pulledpork
	
print_status "Attempting to download rules for $snortver.."
perl pulledpork.pl -c /usr/src/pulledpork/etc/pulledpork.conf -vv &>> $logfile
if [ $? == 0 ]; then
	pp_postprocessing
else
	print_error "Rule download for $snortver has failed. Trying text-only rule download for $choice2.."
	perl pulledpork.pl -S $choice2 -c /usr/src/pulledpork/etc/pulledpork.conf -T -vv &>> $logfile
	if [ $? == 0 ]; then
		pp_postprocessing
	else
		print_error "Rule download for $choice2 has failed. Trying text-only rule download $choice3.."
		perl pulledpork.pl -S $choice3 -c /usr/src/pulledpork/etc/pulledpork.conf -T -vv &>> $logfile
		if [ $? == 0 ]; then
			pp_postprocessing
		else
			print_error "Rule download for $choice3 has failed. Trying text-only rule download for $choice4 (Final shot!)"
			perl pulledpork.pl -S $choice4 -c /usr/src/pulledpork/etc/pulledpork.conf -T -vv &>> $logfile
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

#GRO and LRO are checksum offloading techniques that some network cards use to offload checking frame, packet and/or tcp header checksums and can lead to invalid checksums. Snort doesn't like packets with invalid checksums and will ignore them. These commands disable GRO and LRO.

print_notification "Disabling offloading options on the sniffing interfaces.."
ethtool -K $snort_iface_1 rx off &>> $logfile
ethtool -K $snort_iface_1 tx off &>> $logfile
ethtool -K $snort_iface_1 sg off &>> $logfile
ethtool -K $snort_iface_1 tso off &>> $logfile
ethtool -K $snort_iface_1 ufo off &>> $logfile
ethtool -K $snort_iface_1 gso off &>> $logfile
ethtool -K $snort_iface_1 gro off &>> $logfile
ethtool -K $snort_iface_1 lro off &>> $logfile
ethtool -K $snort_iface_2 rx off &>> $logfile
ethtool -K $snort_iface_2 tx off &>> $logfile
ethtool -K $snort_iface_2 sg off &>> $logfile
ethtool -K $snort_iface_2 tso off &>> $logfile
ethtool -K $snort_iface_2 ufo off &>> $logfile
ethtool -K $snort_iface_2 gso off &>> $logfile
ethtool -K $snort_iface_2 gro off &>> $logfile
ethtool -K $snort_iface_2 lro off &>> $logfile 

########################################
#Finally got around doing service persistence the right way. We check to see if the init script is already installed. If it isn't we verify the user has the init script in the right place for us to copy, then copy it into place.

cd "$execdir"
if [ -f /etc/init.d/snortd ]; then
	print_notification "Snortd init script already installed."
else
	if [ ! -f "$execdir"/snortd ]; then
		print_error" Unable to find $execdir/snortd. Please ensure snortd file is there and try again."
		exit 1
	else
		print_good "Found snortd init script."
	fi
	
	cp snortd snortd_2 &>> $logfile
	sed -i "s#snort_basedir#$snort_basedir#g" snortd_2
	sed -i "s#snort_iface1#$snort_iface_1#g" snortd_2
	sed -i "s#snort_iface2#$snort_iface_2#g" snortd_2
	cp snortd_2 /etc/init.d/snortd &>> $logfile
	chown root:root /etc/init.d/snortd &>> $logfile
	chmod 700 /etc/init.d/snortd &>> $logfile
	update-rc.d snortd defaults &>> $logfile
	error_check 'Init Script installation'
	print_notification "Init script located in /etc/init.d/snortd"
	rm -rf snortd_2 &>> $logfile
fi

########################################

print_status "Rebooting now.."
init 6
print_notification "The log file for autosnort is located at: $logfile" 
print_good "We're all done here. Have a nice day."

exit 0