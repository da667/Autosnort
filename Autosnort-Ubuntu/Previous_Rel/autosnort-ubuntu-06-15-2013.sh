#!/bin/bash
#Autosnort script for Ubuntu 12.04+

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
#This is a function to make the whole pulled pork section _MUCH_ easier to read. This same code gets re-used a few times.

function pp_preconfig()
{
print_status "moving config files"
cd /tmp
tar -xzvf snortrules-snapshot-*.tar.gz &>> $logfile
for conffiles in `ls -1 /tmp/etc/* | grep -v snort.conf | grep -v sid-msg.map`; do 
	cp $conffiles /usr/local/snort/etc
done
cp /usr/local/snort/etc/snort.conf /root/snort.conf.tmp
cd /root
print_good "config files moved."
print_status "adding snort.rules and so_rules.rules to snort.conf"
sed -i 's/include \$RULE\_PATH/#include \$RULE\_PATH/' /root/snort.conf.tmp
echo "# unified snort.rules entry" >> /root/snort.conf.tmp
echo "include \$RULE_PATH/snort.rules" >> /root/snort.conf.tmp
echo "# so rule stub path" >> /root/snort.conf.tmp
echo "include \$SO_RULE_PATH/so_rules.rules" >> /root/snort.conf.tmp
cd /usr/src/pulledpork-*
}
########################################
#This is another chunk of code that gets re-used heavily during the pulled pork rule processing section.

function pp_postcheck()
{
if [ $? != 0 ]; then	
	print_error "rule processing for snort rules has failed. check /var/log/autosnort_installer.log for details."
	continue
else
	print_good "Rules processed successfully. Rules located in /usr/local/snort/rules and /usr/local/snort/so_rules."
	print_notification "Pulledpork is located in /usr/src/pulledpork-[pulledpork version]."
	print_notification "By default, Autosnort runs Pulledpork with the Security over Connectivity ruleset."
	print_notification "If you want to change how pulled pork operates and/or what rules get enabled/disabled, Check out the etc directory, and the .conf files contained therein."
	echo ""
fi
}
########################################

##BEGIN MAIN SCRIPT##

#Pre checks: These are a couple of basic sanity checks the script does before proceeding.

########################################

print_status "OS Version Check."
release=`lsb_release -r|awk '{print $2}'`
     if [ $release = "12.04" -o $release = "12.10" -o "13.04" ]
          then
			   print_good "OS is Ubuntu. Good to go."
               
          else
               print_notification "This is not Ubuntu 12.04 or 12.10, and has NOT been tested on other platforms."
               while true; do
                   read -p "Continue? (y/n)" warncheck
                   case $warncheck in
                       [Yy]* ) break;;
                       [Nn]* ) print_error "Bailing."; exit;;
                       * ) print_notification "Please answer yes or no.";;
                   esac
				done
		echo " "
     fi
	 
########################################

print_status "Checking for root privs."
     if [ $(whoami) != "root" ]
          then
               print_error "This script must be ran with sudo or root privileges, or this isn't going to work."
		exit 1
          else
               print_good "We are root."
     fi
	 
########################################	 

print_status "Checking to ensure sshd is running."

service ssh status

########################################

print_status "Wget check."

/usr/bin/which wget 2>&1 >> /dev/null
if [ $? -ne 0 ]; then
    print_error "Wget not found." 
	print_notification "Installing wget."
	install_packages wget
else
    print_good "Found wget."
fi

########################################

# System updates
print_status "Performing apt-get update and upgrade (May take a while if this is a fresh install)"
apt-get update &>> $logfile && apt-get -y upgrade &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Apt-get update and upgrade failed. Please check /var/log/autosnort_install.log for details."
	exit 1	
else
    print_good "Updates Installed."
fi

########################################

#These packages are required at a minimum to build snort and barnyard + their component libraries

print_status "Installing base packages: ethtool build-essential libpcap0.8-dev libpcre3-dev bison flex libpcap-ruby autoconf libtool libmysqlclient-dev"

declare -a packages=( ethtool build-essential libpcap0.8-dev libpcre3-dev bison flex libpcap-ruby autoconf libtool libmysqlclient-dev );
install_packages ${packages[@]}

########################################

#This is where the user decides whether or not they want a full stand-alone sensor or a barebones/distributed installation sensor.

while true; do
	print_notification "Do you plan on installing a web interface to review intrusion events, such as snortreport, aanval or base? (If in doubt, select option 1)"
	read -p "
1 is yes
2 is no
" ui_inst
	case $ui_inst in
	1)
	print_status "Acquiring and installing mysql and apache2. You will need to assign a password to the root mysql user. Remember the password you set, you'll need it later."
	apt-get install -y mysql-server
	if [ $? -ne 0 ]; then
		print_error "apt-get update and upgrade failed. Please check /var/log/autosnort_install.log for details."
		exit 1	
	fi
	apt-get install -y apache2 &>> $logfile
	if [ $? -ne 0 ]; then
		print_error "Apt-get update and upgrade failed. Please check /var/log/autosnort_install.log for details."
		exit 1	
	else
		print_good "Apache and Mysql Installed."
	fi
	break
	;;
	2)
	print_notification "You've chose to not install a mysql server or apache. This means you will NOT be able to install a web interface on this sensor."
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
#After that we pull snort, daq, and libnet them compile them.

print_status "Acquiring latest version of snort and daq."


cd /tmp
wget http://snort.org/snort-downloads -O /tmp/snort-downloads &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to contact snort.org. Please check $logfile for details."
	exit 1	
fi

########################################

print_status "using shell kung-fu to determine last snort and daq versions."
snorttar=`cat /tmp/snort-downloads | grep snort-[0-9]|cut -d">" -f2 |cut -d"<" -f1 | head -1`
daqtar=`cat /tmp/snort-downloads | grep daq|cut -d">" -f2 |cut -d"<" -f1 | head -1`
snortver=`echo $snorttar | sed 's/.tar.gz//g'`
daqver=`echo $daqtar | sed 's/.tar.gz//g'`

rm /tmp/snort-downloads
cd /usr/src

wget http://snort.org/dl/snort-current/$snorttar -O $snorttar &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to download $snorttar. Please check $logfile for details."
	exit 1	
else
    print_good "Downloaded $snorttar to /usr/src."
fi

########################################

wget http://snort.org/dl/snort-current/$daqtar -O $daqtar &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to download $daqtar. Please check $logfile for details."
	exit 1	
else
    print_good "Downloaded $daqtar to /usr/src."
fi

########################################

print_status "Unpacking daq libraries"
tar -xzvf $daqtar &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to untar $daqtar. Please check $logfile for details."
	exit 1	
fi

########################################

cd $daqver

print_status "Configuring, making and compiling DAQ. This will take a moment or two."

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

ln -s /usr/local/lib/libsfbpf.so.0 /usr/lib/libsfbpf.so.0

print_good "DAQ libraries successfully installed."

########################################

#libdnet hasn't been updated since 2007. Pretty sure we won't have to worry about the filename changing.

print_status "Acquiring libdnet."

cd /usr/src
wget http://libdnet.googlecode.com/files/libdnet-1.12.tgz &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to download libdnet from libdnet.googlecode.com. Please check $logfile for details."
	exit 1	
else
    print_good "Downloaded libdnet to /usr/src."
fi

########################################

tar -xzvf libdnet-1.12.tgz &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to untar libdnet. Please check $logfile for details."
	exit 1	
fi

########################################

cd libdnet-1.12

print_status "Configuring, making, compiling and linking libdnet. This will take a moment or two."

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

#this is in regards to the fix posted in David Gullett's snort guide - /usr/local/lib isn't include in ld path by default in Ubuntu. Don't know if this is relevant for Debian, but I'm including it since Ubuntu and Debian are practically kissing cousins.

ln -s /usr/local/lib/libdnet.1.0.1 /usr/lib/libdnet.1

print_good "Libdnet successfully installed."

########################################

# The --enable-sourcefire option gives us ppm and perfstats for performance troubleshooting.

cd /usr/src
tar -xzvf $snorttar &>> $logfile
if [ $? -ne 0 ]; then
    print_error "Failed to untar $snorttar. Please check $logfile for details."
	exit 1	
fi

########################################

cd $snortver

print_status "configuring snort (options --prefix=/usr/local/snort and --enable-sourcefire), making and installing. This will take a moment or two."

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

arch=`arch`

#This block if code gets very very hairy, very very fast.
#What it boils down to, is that the user is given a choice:
#Install rules via a rule tarball they provide (advanced/heroic/hardcore mode)
#Use pulled pork to provide the default security over connectivity ruleset (easy mode)

# If the user selects option 1, we do a couple of sanity checks to make sure the user gave us a valid file that is a tarball.
# Then we process it and move the rules where snort expects to find them.
# Three things --
# 1. This method only supports VRT rule tarballs
# 2. This method does NOT verify the so rules of the rule tarball are compatible with the version of snort installed.
# 3. The user will need to use some way to create a sid-msg.map (such as oink master's create-sidmap.pl script), the sid-msg.map included in the snortrules tarball is NOT up to date.

# If the user selects option 2, we do necessary to give the user a base security over connectivity ruleset via pulled pork, and a reference snort.conf from labs.snort.org:
# 1. pull packages via apt
# 2. download pulled pork
# 3. modify config files
# 4. download, unpack and configure a security over connectivity ruleset for the user

while true; do
        print_notification "Do you want to install a rule tarball or use pulled pork?"
        read -p "
Select 1 if you would like to install a VRT tarball. (Advanced Users)
Select 2 for pulled pork installation and setup.
" rule_install
        case $rule_install in
			1 )
            print_status "Chose VRT tarball."
            read -p "Please enter the directory where the rule tarball is located (no trailing slashes!) " rule_dir
            read -p "Please enter the name of the tarball (usually snortrules-snapshot-snortver.tar.gz) " rule_filename
            test -e $rule_dir/$rule_filename
                if [ $? = 0 ]; then
                    echo "Tarball found"
                    tar -xzvf $rule_dir/$rule_filename -C /usr/local/snort > /dev/null 2>&1
					if [ $? != 0 ]; then
						print_notification "The filename you have supplied is not a tarball or could not be read by tar (.tar.gz). Please try again."
						continue
					else
						print_good "untar successful"
					fi
                    mkdir /usr/local/snort/lib/snort_dynamicrules
                    if [ $arch = "i686" ]; then
                        print_status "copying 32-bit SO rules."
                        cp /usr/local/snort/so_rules/precompiled/Ubuntu-12-04/i386/2.9.*/* /usr/local/snort/lib/snort_dynamicrules
                    elif [ $arch = "x86_64" ]; then
                        print_status "copying 64-bit SO rules."
                        cp /usr/local/snort/so_rules/precompiled/Ubuntu-12-04/x86-64/2.9.*/* /usr/local/snort/lib/snort_dynamicrules
                    else
                        print_error "cannot determine arch. not copying SO rules. This shouldn't happen. Make sure the arch command is installed."
                    fi
					#tarball copy is successful; we copy a temporary conf file to /root for editing on the next section
					cp /usr/local/snort/etc/snort.conf /root/snort.conf.tmp
					print_good "Rule installation succesful."
					echo ""
					print_notification "WARNING: You will want to generate a new sid-msg.map, the one included in the rule tarball is likely old and incomplete. Use a tool like oinkmaster's create-sidmap.pl to do this."
					echo ""
					cd /root
                    break
                else
                    print_notification "That file doesn't exist. try again."
                fi			
            ;;
			
			2 )
            print_status "Chose Pulledpork."
			
			mkdir -p /usr/local/snort/etc
			mkdir -p /usr/local/snort/so_rules
			mkdir -p /usr/local/snort/rules
			mkdir -p /usr/local/snort/preproc_rules
			mkdir -p /usr/local/snort/lib/snort_dynamicrules
			
			#we wget the snort-rules page off  snort.org, do a lot of text manipulation from the html file downloaded, and set variables: two variables for attempting to downloading the VRT example snort.conf from labs.snort.org, and four variables for the version of snort to download rules for via pulledpork.
			print_status "Checking current rule releases on snort.org."
			
			wget http://www.snort.org/snort-rules -O /tmp/snort-rules &>> $logfile
			if [ $? -ne 0 ]; then
				print_error "Failed to contact snort.org. Please check $logfile for details."
				continue	
			fi
			
			choice1conf=`cat /tmp/snort-rules  | grep snortrules-snapshot-[0-9][0-9][0-9][0-9]|cut -d"-" -f3 |cut -d"." -f1 | sort -ur | head -1` #snort.conf download attempt 1
			choice2conf=`cat /tmp/snort-rules  | grep snortrules-snapshot-[0-9][0-9][0-9][0-9]|cut -d"-" -f3 |cut -d"." -f1 | sort -ur | head -2 | tail -1` #snort.conf download attempt 2
			choice1=`echo $choice1conf |sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./'|sort -ru | head -1` #pp config choice 1
			choice2=`echo $choice2conf | sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./'|sort -ru | head -2|tail -1` #pp config choice 2
			choice3=`cat /tmp/snort-rules  | grep snortrules-snapshot-[0-9][0-9][0-9][0-9]|cut -d"-" -f3 |cut -d"." -f1 | sort -ru | head -3 | tail -1 | sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./'`
			choice4=`cat /tmp/snort-rules  | grep snortrules-snapshot-[0-9][0-9][0-9][0-9]|cut -d"-" -f3 |cut -d"." -f1 | sort -ru | head -4| tail -1 | sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./'`
			
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
			
			#setting the stage for downloading and installation of pulled pork.
			
			cd /usr/src
			
			print_status "Acquiring packages for pulled pork"
			
			declare -a packages=( perl libarchive-tar-perl libcrypt-ssleay-perl liblwp-protocol-https-perl );
			install_packages ${packages[@]}
			
			print_status "Acquiring Pulled Pork."
			
            wget http://pulledpork.googlecode.com/files/pulledpork-0.6.1.tar.gz -O pulledpork-0.6.1.tar.gz &>> $logfile
            
			if [ $? -ne 0 ]; then
				print_error "Failed to acquire pulledpork. Please check $logfile for details."
				continue	
			fi
			
			tar -xzvf pulledpork-0.6.1.tar.gz &>> $logfile
			
			if [ $? -ne 0 ]; then
				print_error "Failed to untar pulledpork. Please check $logfile for details."
				continue	
			fi
			
			print_good "Pulledpork successfully installed to /usr/src"
            
			cd pulledpork-*/etc
			
			#Create a copy of the original conf file (in case the user needs it), ask the user for an oink code, then fill out a really stripped down pulledpork.conf file with only the lines needed to run the perl script
			
			cp pulledpork.conf pulledpork.conf.orig
			
			read -p "What is your oink code?   " o_code
			echo "rule_url=https://www.snort.org/reg-rules/|snortrules-snapshot.tar.gz|$o_code" > pulledpork.tmp
			echo "rule_url=https://www.snort.org/reg-rules/|opensource.gz|$o_code" >> pulledpork.tmp
			echo "ignore=deleted.rules,experimental.rules,local.rules" >> pulledpork.tmp
			echo "temp_path=/tmp" >> pulledpork.tmp
			echo "rule_path=/usr/local/snort/rules/snort.rules" >> pulledpork.tmp
			echo "local_rules=/usr/local/snort/rules/local.rules" >> pulledpork.tmp
			echo "sid_msg=/usr/local/snort/etc/sid-msg.map" >> pulledpork.tmp
			echo "sid_changelog=/var/log/sid_changes.log" >> pulledpork.tmp
			echo "sorule_path=/usr/local/snort/lib/snort_dynamicrules/" >> pulledpork.tmp
			echo "snort_path=/usr/local/snort/bin/snort" >> pulledpork.tmp
			echo "config_path=/usr/local/snort/etc/snort.conf" >> pulledpork.tmp
			echo "sostub_path=/usr/local/snort/so_rules/so_rules.rules" >> pulledpork.tmp
			echo "distro=Ubuntu-12-04" >> pulledpork.tmp
			echo "ips_policy=security" >> pulledpork.tmp
			echo "version=0.6.0" >> pulledpork.tmp
			cp pulledpork.tmp pulledpork.conf
			

			
#the actual PP routine: give them a choice to try and download rules for the four most recent versions of snort. run PP twice for each case statement - the first time downloads the rules to /tmp so we can copy configuration files to /usr/local/snort/etc. The second time actually processes the rules. If the user cannot download the snort rules tarball for the most recent snort release (no VRT subscription), and has to download rules for any previous version of snort, pulledpork is configured to process text rules only; this is to ensure SO rule compatibility problems don't occur and break snort entirely.			
			
			print_notification "Since this script can't tell how many days it has been since snort $currentver has been released, and I don't want to waste 15 minutes of your time, what version of snort do want to download rules for?"
			read -p "
Select 1 to download rules for snort $choice1 (Select this if it has been more than 30 days since snort $currentver has been released or if you have a VRT rule subscription oinkcode)
Select 2 to download rules for snort $choice2 (Select this if it has been less than 30 days since snort $currentver has been released and you do NOT have a VRT rule subscription oinkcode)
Select 3 to download rules for snort $choice3 (Select this if it has been less than 30 days since snort $choice1 AND $choice2 have been released and you do not have a VRT rule subscription oinkcode)
Select 4 to download rules for snort $choice4 (Select this as a last resort, if all other options do not work.)
" pp_choice
			cd ..
				case $pp_choice in
					1)
					print_status "download rules for $choice1"
					perl pulledpork.pl -c /usr/src/pulledpork-*/etc/pulledpork.conf -g &>> $logfile
					if [ $? != 0 ]; then
						print_error "rule download for $currentver snort rules has failed. Check $logfile for details. Rememeber to wait AT LEAST 15 minutes before attempting another download."
						continue
					else 
						pp_preconfig
						perl pulledpork.pl -c /usr/src/pulledpork-*/etc/pulledpork.conf -n &>> $logfile
						pp_postcheck
					fi
					break
					;;
					2)
					print_status "download rules for $choice2"
					perl pulledpork.pl -S $choice2 -c /usr/src/pulledpork-*/etc/pulledpork.conf -g &>> $logfile
					if [ $? != 0 ]; then
						print_error "rule download for $currentver snort rules has failed. Check $logfile for details. Rememeber to wait AT LEAST 15 minutes before attempting another download."
						continue
					else 
						pp_preconfig
						perl pulledpork.pl -S $choice2 -c /usr/src/pulledpork-*/etc/pulledpork.conf -T -n &>> $logfile
						pp_postcheck
					fi
					break
					;;
					3)
					print_status "download rules for $choice3"
					perl pulledpork.pl -S $choice3 -c /usr/src/pulledpork-*/etc/pulledpork.conf -g &>> $logfile
					if [ $? != 0 ]; then
						print_error "rule download for $currentver snort rules has failed. Check $logfile for details. Rememeber to wait AT LEAST 15 minutes before attempting another download."
						continue
					else 
						pp_preconfig
						perl pulledpork.pl -S $choice3 -c /usr/src/pulledpork-*/etc/pulledpork.conf -T -n &>> $logfile
						pp_postcheck
					fi
					break
					;;
					4)
					print_status "download rules for $choice4"
					perl pulledpork.pl -S $choice4 -c /usr/src/pulledpork-*/etc/pulledpork.conf -g &>> $logfile
					if [ $? != 0 ]; then
						print_error "rule download for $currentver snort rules has failed. Check $logfile for details. Rememeber to wait AT LEAST 15 minutes before attempting another download."
						continue
					else 
						pp_preconfig
						perl pulledpork.pl -S $choice4 -c /usr/src/pulledpork-*/etc/pulledpork.conf -T -n &>> $logfile
						pp_postcheck
					fi
					break
					;;
					*)
					print_notification "Invalid selection. Please try again."
					continue
					;;
				esac
            ;;
            * )
				print_notification "invalid choice, try again."
				continue
			;;
        esac
done

########################################

print_status "ldconfig processing and creation of whitelist/blacklist.rules files taking place."

touch /usr/local/snort/rules/white_list.rules && touch /usr/local/snort/rules/black_list.rules && ldconfig

########################################

print_status "Modifying snort.conf -- specifying unified 2 output, SO whitelist/blacklist and standard rule locations."

#here we take the copy of snort.conf.tmp, perform some sed-foo on the file, then copy it back to /usr/local/snort/etc.

cd /root

#this sets the dynamic preprocessor directory

sed -i 's/dynamicpreprocessor directory \/usr\/local\/lib\/snort_dynamicpreprocessor\//dynamicpreprocessor directory \/usr\/local\/snort\/lib\/snort_dynamicpreprocessor\//' /root/snort.conf.tmp

#this sets where libsf_engine.so is located

sed -i 's/dynamicengine \/usr\/local\/lib\/snort_dynamicengine\/libsf_engine.so/dynamicengine \/usr\/local\/snort\/lib\/snort_dynamicengine\/libsf_engine.so/' /root/snort.conf.tmp

#now for the actual SO rules directory.

sed -i 's/dynamicdetection directory \/usr\/local\/lib\/snort_dynamicrules/dynamicdetection directory \/usr\/local\/snort\/lib\/snort_dynamicrules/' /root/snort.conf.tmp

#setting unified2 as the output type.
#TODO: set the output type to syslog for a barebones install.

sed -i 's/# output unified2: filename merged.log, limit 128, nostamp, mpls_event_types, vlan_event_types/output unified2: filename snort.u2, limit 128/' /root/snort.conf.tmp

#remember how we added blacklist and whitelist.rules files earlier? we have to point snort to those files now.

sed -i 's/var WHITE_LIST_PATH ..\/rules/var WHITE_LIST_PATH \/usr\/local\/snort\/rules/' /root/snort.conf.tmp

sed -i 's/var BLACK_LIST_PATH ..\/rules/var BLACK_LIST_PATH \/usr\/local\/snort\/rules/' /root/snort.conf.tmp

cp /root/snort.conf.tmp /usr/local/snort/etc/snort.conf

#we clean up after ourselves...

rm /root/snort.conf.tmp

print_good "snort.conf configured. location: /usr/local/snort/etc/snort.conf"

########################################

#now we have to download barnyard 2 and configure all of its stuff.

print_status "downloading, making and compiling barnyard2."

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

print_status "configuring supporting infrastructure for barnyard (file ownership to snort user/group, file permissions, waldo file, configuration, etc.)"


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
	print_status "Integrating mysql with barnyard2"
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
			print_notification -e "Passwords do not match. Please try again."
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
	ifconfig $snort_iface > /dev/null 2>&1
	if [ $? != 0 ]; then
		print_notification "that interface doesn't seem to exist. Please try again."
		continue
	else
		if [ "$snort_iface" = "lo" ]; then
			print_notification "And what, dear user, do you expect to find on the loopback interface? Try again."
			continue
		else
			print_status "configuring to monitor on $snort_iface"
			break
		fi
	fi
done

echo "config interface: $snort_iface" >> /root/barnyard2.conf.tmp
echo "input unified2" >> /root/barnyard2.conf.tmp


cp /root/barnyard2.conf.tmp /usr/local/snort/etc/barnyard2.conf

#cleaning up the temp file

rm /root/barnyard2.conf.tmp

print_good "Barnyard2 configuration complated."

########################################

#The choice above determines whether or not we'll be adding an entry to /etc/sysconfig/network-scripts  for the snort interface and adding the rc.local hack to bring snort's sniffing interface up at boot. We also run ethtool to disable checksum offloading and other nice things modern NICs like to do; per the snort manual, leaving these things enabled causes problems with rules not firing properly. We give the user the choice of not doing this, in the case that they may not have two dedicated network interfaces available.


while true; do
	print_notification "Would you like to have $snort_iface configured to run in promiscuous mode on boot? THIS IS REQUIRED if you want snort to run Daemonized on boot."
	print_notification "BE AWARE: If you choose this option, $snort_iface will not resond to any traffic on its interface. If $snort_iface is the only interface on your system, this isn't a good idea."
	read -p "
Selecting 1 adds an entry to rc.local to bring the interface up in promiscuous mode with no arp or multicast response to prevent discovery of the sniffing interface.
Selecting 2 does nothing and lets you configure things on your own.
" boot_iface

	case $boot_iface in
		1 )
		print_status "Adding ifconfig line for $snort_iface to rc.local"
        cat /etc/rc.local | grep -v exit > /root/rc.local.tmp
		echo "ifconfig $snort_iface up -arp -multicast promisc" >> /root/rc.local.tmp
		cp /root/rc.local.tmp /etc/rc.local
		ethtool -K $snort_iface gro off > /dev/null 2>&1
		ethtool -K $snort_iface lro off > /dev/null 2>&1
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
		print_status "adding snort and barnyard2 to rc.local"
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
	print_notification "6. no web interface or output method will be installed (Select this if didn't install apache or mysql and do NOT have an SIEM set up to report events to)"
	read -p "Please choose an option: " ui_choice
	case $ui_choice in
		1)
		print_status "Installing Snort Report."
		bash snortreport-ubuntu.sh
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
		print_status "You have chosen to install Aanval."
		bash aanval-ubuntu.sh
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
		print_status "You have chosen to install BASE."
		bash base-ubuntu.sh
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
		echo "You have chosen to install rsyslog."
		bash syslog_full-ubuntu.sh
		if [ $? != 0 ]; then
			print_error "It looks like the installation did not go as according to plan."
			echo "Please try again"
			continue
		else
			print_good "Rsyslog output successfully configured."
			print_notification "Please ensure 514/udp outbound is open on THIS sensor."
			print_notification "Ensure 514/udp inbound is open on your syslog server/SIEM and is ready to recieve events."
			break
		fi
		;;
		5)
		print_status "You have chosen to install snorby."
		bash snorby-ubuntu.sh
		if [ $? != 0 ]; then
			print_error "It looks like the installation did not go as according to plan."
			echo "Please try again"
			continue
		else
			print_good "Snorby successfully installed."
			print_notification "Default credentials are user: snorby@snorby.org password: snorby"
			print_notification "I tried implementing a method to start the delayed_job and/or cache jobs on system start... but it appears to not work at all."
			print_notification "If your system is rebooted for any reason, on restart, you will need to run:"
			print_notification "cd /var/www/snorby && ruby script/delayed_job start"
			print_notification "followed by:"
			print_notification "cd /var/www/snorby && rails runner 'Snorby::Jobs::SensorCacheJob.new(false).perform; Snorby::Jobs::DailyCacheJob.new(false).perform'"
			print_notification "Copy this down, because I also advise rebooting this system before putting it into production; you'll need to run those two commands if you want snorby to be functional!"
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