#!/bin/bash
#auto-snort script v2 - Verified as working for Ubuntu 12.04
#v2 fixes: strictly calling bash to allow declare statements and arrays to work properly on Ubuntu.
#Major thanks to Kyle Johnson - Zenimax Studios sysadmin for code contributions in this version
#removed newline characters. they were pretty pointless.
#made the sshd check a bit clearer. If you have a better way of determining whether or not sshd is running, I'm all ears.
#made checks for 32 v 64-bit arch automated via uname -i (Thanks kyle!)
#v3 fixes:
#Major thanks to Andy Walker - Sourcefire VRT for code contributions to this version
#Removed sleep and clear statements from the script per discussion regarding this script, this could result in a missed prompt or missed errors. agreed to remove sleep statements for speed, and clear statements to ensure all data is captured by the user.
# purpose: from nothing to full snort in gods know how much time it takes to compile some of this shit.
#at some point, I want this script to log to something for error reporting.

#Declaring Functions - This function is an easier way to reuse the apt-get code. 
#I added a slight change to perform apt-get update to ensure we're getting the latest packages available.
install_packages()
{
 echo "Installing packages: ${@}"
 apt-get update && apt-get install -y ${@}
 if [ $? -eq 0 ]; then
  echo "Packages successfully installed."
 else
  echo "Packages failed to install!"
  exit 1
 fi
}


# We need to check OS we're installing to, net connectivity, user we are running as, ensure sshd is running and wget is available.

# checks lsb_release -r and awks the version number to verify what OS we're running.
# warns the user if we're not running on a supported OS
# asks if they want to continue.
echo "OS Version Check."
     release=`lsb_release -r|awk '{print $2}'`
     if [ $release = "12.04" -o $release = "12.10" ]
          then
			   echo "OS Check successful."
               
          else
               echo "This is not Ubuntu 12.04 or 12.10, and has NOT been tested on other platforms."
               while true; do
                   read -p "Continue? (y/n)" warncheck
                   case $warncheck in
                       [Yy]* ) break;;
                       [Nn]* ) echo "Cancelling."; exit;;
                       * ) echo "Please answer yes or no.";;
                   esac
				done
		echo " "
     fi

#Connectivity check uses icmp, pings google once and checks for exit 0 status of the command. 
#Exits script on error and notifies user connectivity check failed.
#Thinking about removing this and assuming the user has internet access?
echo "Checking internet connectivity (pinging google.com)"
     ping google.com -c1 2>&1 >> /dev/null
     if [ $? -eq 0 ]; then
          echo "Connectivity looks good!"
     else
          echo "Ping to google has failed. Please verify you have network connectivity or ICMP outbound is allowed. Seriously, what harm is it going to do?"
   	  exit 1
     fi

#assumes script is ran as root. root check performed via use of whoami. 
#checks for a response of "root" if user isn't root, script exits and notifies user it needs to be ran as root.

echo "User Check"
     if [ $(whoami) != "root" ]
          then
               echo "This script must be ran with sudo or root privileges, or this isn't going to work."
		exit 1
          else
               echo "We are root."
     fi
	 
#Checking to ensure sshd is running done by running ps-ef, grepping for sshd, using wc -l and if we have more than one line, using that as a sign that SSHD is running 
#Anyone who's used ps-ef | grep [blah] knows that it will always return 0. 
#However if it only returns one line, that means the process you are searching for is not actually running.

echo "Checking to ensure sshd is running."

	if [ $(/bin/ps -ef |/bin/grep sshd |/usr/bin/wc -l) -gt 1 ]
		then
			echo "sshd is running "
		else
			echo "sshd isn't running... The script can continue, but in most cases, sshd is use for remotely managing snort sensors."
	fi

#the below checks for the existence of wget and offers to download it via apt-get if it isn't installed.
#Wget check cleaned up, redirected to /dev/null. We look for an exit 0 status against "which wget".
#any status other than 0 results in use asking the user if they want to install wget, which is required for us to download several sourcetarballs for the script.

	/usr/bin/which wget 2>&1 >> /dev/null
		if [ $? -ne 0 ]; then
        		echo "wget not found. Install wget?"
         case $wget_install in
                                [yY] | [yY][Ee][Ss])
				install_packages wget
                                ;;
                                *)
                                echo "Either you selected no or I didn't understand. Wget is required to continue. Exiting."
                                exit 1
                                ;;
                                esac
		else
        		echo "found wget."
		fi
		
####step 2: patches and package pre-reqs####

#Here we call apt-get update and apt-get -y upgrade to ensure all repos and stock software is fully updated.
#For consistency, if the command chain exits on anything other than a 0 exit code, we notify the user that updates were not successfully installed.

echo "Performing apt-get update and apt-get upgrade (with -y switch)"

apt-get update && apt-get -y upgrade 
if [ $? -eq 0 ]; then
	echo "Packages and repos are fully updated."
else
	echo "apt-get upgrade or update failed."
fi

echo "Grabbing required packages via apt-get."

#Here we grab base install requirements for a full stand-alone snort sensor, including web server for web UI. 
#TODO: Give users a choice -- do they want to install a collector, a full stand-alone sensor, or a barebones sensor install?

declare -a packages=( ethtool nmap nbtscan apache2 php5 php5-mysql php5-gd libpcap0.8-dev libpcre3-dev g++ bison flex libpcap-ruby make autoconf libtool libwww-perl libcrypt-ssleay-perl);
install_packages ${packages[@]}

#Here we download the mysql client/server packages and notify the user that they will need to input a root user password.
#TODO: If the user is installing a barebones sensor, do not download or install mysql.

echo "Acquiring and install mysql server and client packages. You will need to assign a password to the root mysql user."

declare -a packages=(mysql-server libmysqlclient-dev)
install_packages ${packages[@]}


echo "mysql server and client installed. Make sure to store the root user password somewhere safe."

#We pull snort.org/snort-downloads and use some grep and cut-fu to determine the current stable daq and snort version and download them to /usr/src

echo "acquiring latest version of snort and daq."
echo ""

cd /tmp 1>/dev/null
wget -q http://snort.org/snort-downloads -O /tmp/snort-downloads
snortver=`cat /tmp/snort-downloads | grep snort-[0-9]|cut -d">" -f2 |cut -d"<" -f1 | head -1`
daqver=`cat /tmp/snort-downloads | grep daq|cut -d">" -f2 |cut -d"<" -f1 | head -1`
rm /tmp/snort-downloads
cd /usr/src 1>/dev/null
wget http://snort.org/dl/snort-current/$snortver -O $snortver
wget http://snort.org/dl/snort-current/$daqver -O $daqver

echo "Unpacking daq libraries"
echo ""

tar -xzvf $daqver
cd daq-*

echo "Configuring, making and compiling DAQ. This will take a moment or two."
echo ""

./configure && make && make install

echo "DAQ libraries installed."
echo ""

#download, compile and make libdnet, then link it to work properly.
#libdnet hasn't been updated since 2007. Pretty sure we won't have to worry about the filename changing.

echo "acquiring libdnet 1.12 library from googlecode."
echo ""

cd /usr/src
wget http://libdnet.googlecode.com/files/libdnet-1.12.tgz
tar -xzvf libdnet-1.12.tgz
cd libdnet-1.12

echo "configuring, making, compiling and linking libdnet. This will take a moment or two."
echo ""

#this is in regards to the fix posted in David Gullett's snort guide - /usr/local/lib isn't include in ld path by default in Ubuntu.. Backtrack is Ubuntu-based so this fix is likely still valid. Easier to link it than muck around with ld conf files

./configure && make && make install && ln -s /usr/local/lib/libdnet.1.0.1 /usr/lib/libdnet.1

echo "libdnet installed and linked."
echo ""

#now we build snort itself. The --enable-sourcefire option gives us ppm and perfstats for performance troubleshooting.

cd /usr/src
tar -xzvf $snortver
cd snort-*

echo "configuring snort (options --prefix=/usr/local/snort and --enable-sourcefire), making and installing. This will take a moment or two."
echo ""

./configure --prefix=/usr/local/snort --enable-sourcefire && make && make install


echo "snort install complete. Installed to /usr/local/snort."
echo ""

#supporting infrastructure for snort.

echo "creating directories /var/log/snort, and /var/snort."

mkdir /var/snort && mkdir /var/log/snort

echo "creating snort user and group, assigning ownership of /var/log/snort to snort user and group. \n"

#users and groups for snort to run non-priveledged. snort's login shell is set to /bin/false to enforce the fact that this is a service account.

groupadd snort
useradd -g snort snort -s /bin/false
chown snort:snort /var/log/snort

#just as the echo statement says, it's a good idea to assign a password to the snort user. I didn't see this explicitly done in the 12.04 install guide.


echo "we added the snort user and group, the snort user requires a password, please enter a password and confirm this password."

passwd snort

arch=`uname -i`

#the next bit of code gets really, really hairy so I'm going to break it down bit by bit
#to start, we ask the user if they want to use pp to download an initial rule set or if there's a tarball available on the system (We only support VRT tarballs) for us to crack open
#this entire function is encapsulated in a while/true loop, because this section is VITAL to ensure snort operates; we're grabbing config files, setting up rules, etc.
#the while/true loop encapsulation is to ensure that if ANYTHING goes wrong that the user is given another chance to try it all again.
#not sexy, but it is very functional.

while true; do
        echo "Do you want to install a rule tarball or use pulled pork?"
        read -p "
select 1 if you would like to install a VRT tarball. (Advanced Users)
select 2 for pulled pork installation and setup.
" rule_install
        case $rule_install in
# if the user selects 1, the user has selected to install a tarball that is resident on disk without pulled pork. We ask them for the directory and filename, same as always, only this time we do a check:
# does this file exist? if it doesn't we have to call the user out on it. we use the looping function to make the user try again. For the user to exit this loop they have to give is a file that exists
# when we get a file that exists, we try to untar it. if the untar fails (gives us anything but a 0 exit code), we make the user double check that it's a valid .tar.gz
# if we get a file that passes both checks, we process things as normal, like in the standard AS script.
# we don't check SO rules for compatibility for the version of snort installed currently
# why this is important and the manual workaround: http://autosnort.blogspot.com/2012/12/snort-294-release-today-and-dreaded-my.html
			1 )
            echo "chose VRT tarball"
            read -p "Please enter the directory where the rule tarball is located (no trailing slashes!) " rule_dir
            read -p "Please enter the name of the tarball (usually snortrules-snapshot-snortver.tar.gz) " rule_filename
            test -e $rule_dir/$rule_filename
                if [ $? = 0 ]; then
                    echo "tarball found"
                    tar -xzvf $rule_dir/$rule_filename -C /usr/local/snort > /dev/null 2>&1
					if [ $? != 0 ]; then
						echo "The filename you have supplied is not a tarball or could not be read by tar (.tar.gz). Please try again."
						echo ""
						continue
					else
						echo "untar successful"
						echo ""
					fi
                    mkdir -p /usr/local/snort/lib/snort_dynamicrules
                    if [ $arch = "i386" ]; then
                        echo "copying 32-bit SO rules."
                        cp /usr/local/snort/so_rules/precompiled/Ubuntu-12-04/i386/2.9.*/* /usr/local/snort/lib/snort_dynamicrules
                    elif [ $arch = "x86_64" ]; then
                        echo "copying 64-bit SO rules."
                        cp /usr/local/snort/so_rules/precompiled/Ubuntu-12-04/x86-64/2.9.*/* /usr/local/snort/lib/snort_dynamicrules
                    else
                        echo "cannot determine arch. not copying SO rules."
                    fi
					#tarball copy is successful; we copy a temporary conf file to /root for editing on the next section
					cp /usr/local/snort/etc/snort.conf /root/snort.conf.tmp
					cd /root
                    break
                else
                    echo "that file doesn't exist. try again."
                fi
			
            ;;
# Things get much more fun and much more hairy here because there are so many chances for failure
# If the user selects 2, they select to download, install and run pulled pork.
# We install all the packages necessary and download pulledpork from google code (no magic yet to automatically determine the latest version. Working on it.)
# We use a trick similar to the trick above for downloading snort and DAQ to determine the newest and second newest version of snort on the snort-rules download page
# We're setting four variables here:
# the variable currentverconf and prevverconf are the current and previous version of snort.conf without periods between the version numbers.
# why do we need this? because we're going to use these to wget the snort.conf file from labs.snort.org -- the official snort.conf the VRT usually puts up upon releasing a new version of snort.
# if its not there yet, we try to download the .conf file for the version prior. 99% chance the two are compatible.
# the other two variables, currentver and prevver are for the entire pulled pork sub section. Let me down there to explain what's going on.
			2 )
            echo "chose pp"
			mkdir -p /usr/local/snort/etc
			mkdir -p /usr/local/snort/so_rules
			mkdir -p /usr/local/snort/rules
			mkdir -p /usr/local/snort/preproc_rules
			mkdir -p /usr/local/snort/lib/snort_dynamicrules
			#download the latest snort-rules page. We're setting four variables, two for pulled pork, and two to download a valid snort.conf from labs.snort.org - we need a snort.conf in place for pulledpork to generate so rule stubs.
			wget -q http://www.snort.org/snort-rules -O /tmp/snort-rules
			currentverconf=`cat /tmp/snort-rules  | grep snortrules-snapshot-[0-9][0-9][0-9][0-9]|cut -d"-" -f3 |cut -d"." -f1 | sort -ur | head -1` #snort.conf download attempt 1
			prevverconf=`cat /tmp/snort-rules  | grep snortrules-snapshot-[0-9][0-9][0-9][0-9]|cut -d"-" -f3 |cut -d"." -f1 | sort -ur | head -2 | tail -1` #snort.conf download attempt 2
			currentver=`echo $currentverconf |sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./'|sort -ru | head -1` #pp config choice 1
			prevver=`echo $prevverconf | sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./'|sort -ru | head -2|tail -1` #pp config choice 2
			#download snort.conf
			wget http://labs.snort.org/snort/$currentverconf/snort.conf -O /usr/local/snort/etc/snort.conf
			#if we get anything other than a success exit code, we try for previous snort.conf - likely they haven't uploaded a new snort.conf yet.
			if [ $? != 0 ];then
				echo "attempt to download a $currentver snort.conf from labs.snort.org failed. attempting to download snort.conf for $prevver"
				wget http://labs.snort.org/snort/$prevverconf/snort.conf -O /usr/local/snort/etc/snort.conf
				#if this wget fails as well restart the entire loop from the top - we don't have a snort.conf in place so pulled pork isn't going to play nice.
				if [ $? != 0 ];then
					echo "this attempt to download a snort.conf has failed as well. Aborting pulledpork rule installation."
					continue 
				else
					echo "successfully downloaded snort.conf for $prevver. This will likely work for now until they upload a new snort.conf to labs.snort.org."
				fi
			else
				echo "successfully downloaded snort.conf for $currentver."
			fi
			#setting the stage for downloading and installation of pulled pork.
			cd /usr/src
			declare -a packages=( perl libarchive-tar-perl libcrypt-ssleay-perl liblwp-protocol-https-perl );
			install_packages ${packages[@]}
            wget http://pulledpork.googlecode.com/files/pulledpork-0.6.1.tar.gz -O pulledpork-0.6.1.tar.gz
            tar -xzvf pulledpork-0.6.1.tar.gz
            cd pulledpork-*/etc
			cp pulledpork.conf pulledpork.tmp
			#asking for the oinkcode
			read -p "What is your oink code?   " o_code
			#creating the temporary pulled pork file for modification. first, we add our oink code
			sed -i 's/<oinkcode>/'$o_code'/' pulledpork.tmp
			#ignore any et download links
			sed -i 's/rule\_url\=https\:\/\/rules\.emergingthreats\.net/#rule\_url\=https\:\/\/rules\.emergingthreats\.net/' pulledpork.tmp
			#set the directory where we want pp to dump our snort.rules file
			sed -i 's/rule\_path\=\/usr\/local\/etc\/snort\/rules\/snort.rules/rule\_path\=\/usr\/local\/snort\/rules\/snort.rules/' pulledpork.tmp
			#set where we want pp to drop sid-msg.map
			sed -i 's/sid\_msg\=\/usr\/local\/etc\/snort\/sid-msg.map/sid\_msg\=\/usr\/local\/snort\/etc\/sid-msg.map/' pulledpork.tmp
			#so rule path
			sed -i 's/sorule\_path\=\/usr\/local\/lib\/snort\_dynamicrules\//sorule\_path\=\/usr\/local\/snort\/lib\/snort\_dynamicrules\//' pulledpork.tmp
			#location of snort.conf
			sed -i 's/config\_path\=\/usr\/local\/etc\/snort\/snort.conf/config\_path\=\/usr\/local\/snort\/etc\/snort.conf/' pulledpork.tmp
			#location where we want the so rule stub file dropped
			sed -i 's/sostub\_path\=\/usr\/local\/etc\/snort\/rules\/so\_rules.rules/sostub\_path\=\/usr\/local\/snort\/so\_rules\/so\_rules.rules/' pulledpork.tmp
			#distro for so rule selection
			sed -i 's/distro\=FreeBSD-8.0/distro\=Ubuntu-12-04/' pulledpork.tmp
			#path to our snort binary for so rule stub generation
			sed -i 's/snort\_path\=\/usr\/local\/bin\/snort/snort\_path\=\/usr\/local\/snort\/bin\/snort/' pulledpork.tmp
			#setting the version of snort here
			sed -i 's/# snort\_version\=2.9.0.0/snort\_version\='$currentver'/' pulledpork.tmp
			#setting the policy to security over connectivity
			sed -i 's/# ips\_policy\=security/ips\_policy\=security/' pulledpork.tmp
			#we're done; copy the temp file over pulledpork.conf
			cp pulledpork.tmp pulledpork.conf
			
# Here is our pp routine
# We come out and tell the user that since we do not know how many days it has been since the newest version of snort has been released and/or we do not know whether or not
# They have a registered user or dedicated VRT subscription, we have to ask what version they want to download rules for
# We also make the recommendation that if it has been less than 30 days since the new version of snort has come out and they don't have a VRT rule subscription to try downloading rules for the previous version of snort
# We give VRT subscribers and registered users they option to download snort rules for the current version of snort as well
# If they can download snort rules with SO rules compatible with their release, we let them. and we also download SO rules for use.
# If they cannot download snort rules with SO rules compatible with their release, we download the previous version rule tarball and process text rules ONLY.
# The download phase is done in two parts to work around a small pulled pork problem:
# If the user of pp wants SO rules, they need a valid set of configuration files to build the so_rules.rules stub file (e.g. the snort rule header and metadata for snort rules) so first we set pp to only download the tarball
# then we copy the config files and run pp again and tell it to just use the tarball and md5 hash in /tmp for rule processing.
# if any of the wget operations for snort.conf from labs.snort.org fail, or pp fails to process rules properly, we loop back around instead of blindly rushing forward.
# if pp successfully manages to do its job, we comment out all other RULE_PATH and SO_RULE_PATH directives and insert our own with proper comments to explain what they are there for.

			echo "Since this script can't tell how many days it has been since snort $currentver has been released, and I don't want to waste 15 minutes of your time, what version of snort do want to download rules for?"
			read -p "
Select 1 to download rules for snort $currentver (Select this if it has been more than 30 days since snort $currentver has been released or if you have a VRT rule subscription oinkcode specified)
Select 2 to download rules for snort $prevver (Select this if it has been less than 30 days since snort $currentver has been released and you do NOT have a VRT rule subscription oinkcode specified)
" pp_choice
			cd ..
			if [ $pp_choice = 1 ]; then
				echo "attempting pulled pork for snort $currentver."
				perl pulledpork.pl -c /usr/src/pulledpork-*/etc/pulledpork.conf -g #We are just download the correct tarball. pp nukes the tarball after rule processing, so we need to do prep work then have pp do its job.
				if [ $? != 0 ]; then
					echo "rule download for $currentver snort rules has failed. Check your oinkcode, connectivity, firewall rules and/or proxies and try again. Rememeber to wait AT LEAST 15 minutes before attempting another download."
					continue
				else 
					echo "rules downloaded! post-download and pre-rule processing taking place"
					echo ""
					#special edits to make sure snort works on reboot
					cd /tmp
					tar -xzvf snortrules-snapshot-*.tar.gz
					#for-do loop to copy the other conf files that need to be present for snort/barnyard
					for conffiles in `ls -1 /tmp/etc/* | grep -v snort.conf | grep -v sid-msg.map`
					do cp $conffiles /usr/local/snort/etc
					done
					#making special edits to snort.conf if pulled pork works
					cp /usr/local/snort/etc/snort.conf /root/snort.conf.tmp
					cd /root
					#comment out all includes for *.rules, since the only .rules file we will need are snort and so_rules.rules
					sed -i 's/include \$RULE\_PATH/#include \$RULE\_PATH/' /root/snort.conf.tmp
					#we add our snort.rules include...
					echo "# unified snort.rules entry" >> /root/snort.conf.tmp
					echo "include \$RULE_PATH/snort.rules" >> /root/snort.conf.tmp
					#and our so_rules.rules stub include...
					echo "# so rule stub path" >> /root/snort.conf.tmp
					echo "include \$SO_RULE_PATH/so_rules.rules" >> /root/snort.conf.tmp
					#rule processing time
					cd /usr/src/pulledpork-*
					perl pulledpork.pl -c /usr/src/pulledpork-*/etc/pulledpork.conf -n #we have the tarball on disk in the temp directory, so we don't want to try and hit snort.org to get it again.
					
					if [ $? != 0 ]; then
						echo ""
						echo "rule processing for $currentver snort rules has failed for some reason. check the pulledpork error output and try again."
						continue
					else
						echo "rules processed successfully."
						echo ""
					fi
				fi
			elif [ $pp_choice = 2 ]; then
				echo "attempting pulled pork for snort $prevver."
				perl pulledpork.pl -S $prevver -c /usr/src/pulledpork-*/etc/pulledpork.conf -g #download only for previous version of snort rules.
				if [ $? != 0 ]; then
					echo "rule download for $currentver snort rules has failed. Check your oinkcode, connectivity, firewall rules and/or proxies and try again. Rememeber to wait AT LEAST 15 minutes before attempting another download."
					continue
				else 
					echo ""
					echo "rules downloaded!post-download and pre-rule processing taking place"
					#special edits to make sure snort works on reboot
					cd /tmp
					tar -xzvf snortrules-snapshot-*.tar.gz
					#for-do loop to copy the other conf files that need to be present for snort/barnyard
					for conffiles in `ls -1 /tmp/etc/* | grep -v snort.conf | grep -v sid-msg.map`
					do cp $conffiles /usr/local/snort/etc
					done
					#making special edits to snort.conf if pulled pork works
					cp /usr/local/snort/etc/snort.conf /root/snort.conf.tmp
					cd /root
					#comment out all includes for *.rules, since the only .rules file we will need are snort and so_rules.rules
					sed -i 's/include \$RULE\_PATH/#include \$RULE\_PATH/' /root/snort.conf.tmp
					#we add our snort.rules include...
					echo "# unified snort.rules entry" >> /root/snort.conf.tmp
					echo "include \$RULE_PATH/snort.rules" >> /root/snort.conf.tmp
					#and our so_rules.rules stub include...
					echo "# so rule stub path" >> /root/snort.conf.tmp
					echo "include \$SO_RULE_PATH/so_rules.rules" >> /root/snort.conf.tmp
					cd /usr/src/pulledpork-*
					perl pulledpork.pl -c /usr/src/pulledpork-*/etc/pulledpork.conf -S $prevver -T -n #we have the tarball on disk in the temp directory, so we don't want to try and hit snort.org to get it again. process text rules only.
					if [ $? != 0 ]; then
						echo "rule processing for $prevver snort rules has failed for some reason. check the pulledpork error output and try again."
						continue
					else
						echo "rules processed successfully."
					fi
					
					
				fi
			else
				echo "invalid choice. try again."
				continue
			fi
			# use to have a post clean-up routine here to clean out /tmp. Decided against it in case the user wants to see/use the snort tarball and/or opensource.gz for any reason.
            break
            ;;
            * )
				echo "invalid choice, try again."
			;;
        esac
done

echo "ldconfig processing and creation of whitelist/blacklist.rules files taking place."

touch /usr/local/snort/rules/white_list.rules && touch /usr/local/snort/rules/black_list.rules && ldconfig

echo "Modifying snort.conf -- specifying unified 2 output, SO whitelist/blacklist and standard rule locations."

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

#now we have to download barnyard 2 and configure all of its stuff.

echo "downloading, making and compiling barnyard2."

cd /usr/src



wget https://github.com/firnsy/barnyard2/archive/master.tar.gz -O barnyard2.tar.gz

tar -xzvf barnyard2.tar.gz

cd barnyard2*

#need to run autoreconf before we can compile it.

autoreconf -fvi -I ./m4

#remember when we checked if the user is 32 or 64-bit? Well we saved that answer and use it to help find where the mysql libs are on the system.

case $arch in
                i386)
                echo "preparing configure statement to point to 32-bit libraries."
./configure --with-mysql --with-mysql-libraries=/usr/lib/i386-linux-gnu


                ;;
                x86_64)
                echo "preparing configure statement to point to 64-bit libraries"
./configure --with-mysql --with-mysql-libraries=/usr/lib/x86_64-linux-gnu


                ;;
                *)
                echo "unable to determine architecture from your answer. The configure statement for barnyard needs to know where to find mysql libraries (--with-mysql-libraries=/my/mysqllib/path)"
		exit 1
                ;;
esac

make && make install

echo "configuring supporting infrastructure for barnyard (file ownership to snort user/group, file permissions, waldo file, etc.)"


#the statements below copy the barnyard2.conf file where we want it and establish proper rights to various barnyard2 files and directories.

cp etc/barnyard2.conf /usr/local/snort/etc
mkdir /var/log/barnyard2
chmod 666 /var/log/barnyard2
touch /var/log/snort/barnyard2.waldo
chown snort.snort /var/log/snort/barnyard2.waldo

echo "building mysql infrastructure"

# We need to ask the user to provide a password for the snort database user.
# We save the snort database user's password as an environment variable.
# This is so we can re-use this variable for child shell scripts (e.g. scripts that install the different web interfaces
# This environment variable should last the life of the shell script, but should not become a permanent environment variable.

while true; do
	echo "Please enter a password for the snort database user. This user will be used to access the intrusion event database that barnyard2 populates."
	read -s -p "Please enter the snort database user password:" MYSQL_PASS_1
	echo ""
	read -s -p "Confirm:" mysql_pass_2
	echo ""
	if [ "$MYSQL_PASS_1" == "$mysql_pass_2" ]; then
		echo "password confirmed."
		echo ""
		export MYSQL_PASS_1
		break
	else
		echo ""
		echo -e "Passwords do not match. Please try again."
		continue
	fi
done

#The next few steps build the snort database, create the database schema, and grants the snort database user permissions to fully modify contents within the database.
#We ask the user for the root mysql user's password 3 times, one for each task.

echo "the next several steps will need you to enter the mysql root user password more than once."
echo ""

#1. create the database.

while true; do
	echo "enter the mysql root user password to create the snort database."
	mysql -u root -p -e "create database snort;"
	if [ $? != 0 ]; then
		echo "the command did NOT complete successfully. (bad password?) Please try again."
		continue
	else
		echo "snort database created!"
		break
	fi
done

#2. Add the schema

while true; do
	echo "enter the mysql root user password again to create the snort database schema"
	mysql -u root -p -D snort < /usr/src/barnyard2*/schemas/create_mysql
	if [ $? != 0 ]; then
		echo "the command did NOT complete successfully. (bad password?) Please try again."
		continue
	else
		echo "snort database schema created!"
		break
	fi
done

#3. Grant the snort database user permissions to do what is necessary to maintain the database.

while true; do
	echo "you'll need to enter the mysql root user password one more time to create the snort database user and grant it permissions to the snort database."
	mysql -u root -p -e "grant create, insert, select, delete, update on snort.* to snort@localhost identified by '$MYSQL_PASS_1';"
	if [ $? != 0 ]; then
		echo "the command did NOT complete successfully. (bad password?) Please try again."
		continue
	else
		echo "snort database schema created!"
		break
	fi
done

#The next section edits the barnyard2.conf. We do this the same way we modified snort.conf
#Make a temporary copy, edit it properly, replace the original, and delete the temporary copy.
#The script automatically sets the path for reference.config, classification.config, gen-msg.map and sid-msg.map
#To /usr/local/snort/etc/.

echo "building barnyard2.conf, pointing to reference.conf, classication.conf, gen-msg and sid-msg maps, as well as use the local mysql database, snort database, and snort user."

cd /root

cp /usr/local/snort/etc/barnyard2.conf /root/barnyard2.conf.tmp

sed -i 's/config reference_file:      \/etc\/snort\/reference.config/config reference_file:      \/usr\/local\/snort\/etc\/reference.config/' /root/barnyard2.conf.tmp
sed -i 's/config classification_file: \/etc\/snort\/classification.config/config classification_file: \/usr\/local\/snort\/etc\/classification.config/' /root/barnyard2.conf.tmp
sed -i 's/config gen_file:            \/etc\/snort\/gen-msg.map/config gen_file:            \/usr\/local\/snort\/etc\/gen-msg.map/' /root/barnyard2.conf.tmp
sed -i 's/config sid_file:            \/etc\/snort\/sid-msg.map/config sid_file:             \/usr\/local\/snort\/etc\/sid-msg.map/' /root/barnyard2.conf.tmp

#todo: give the user a choice of what hostname they want to give their sensor.

sed -i 's/#config hostname:   thor/config hostname: localhost/' /root/barnyard2.conf.tmp

#Here the user must decide what interface they want snort to listen on. This information is used to modify barnyard2's config file to display what interface generated an event,
#As well as affecting which interface snort will actually be sniffing from. This interface will NOT be able to carry any other service traffic. The only thing it will be able to do
#Is sniff traffic, so make this choice carefully and be sure to remember which interface you've chosen for this task.

while true; do
	read -p "What interface will snort listen on? (please choose only one interface)
Based on output from ifconfig, here are your choices:
`ifconfig -a | grep encap | grep -v lo`
" snort_iface 
	ifconfig $snort_iface > /dev/null 2>&1
	if [ $? != 0 ]; then
		echo ""
		echo "that interface doesn't seem to exist. Please try again."
		echo ""
		continue
	else
		if [ "$snort_iface" = "lo" ]; then
			echo "nice try, but the loopback interface is not a valid interface. please select an interface on the list provided!"
			continue
		else
			echo ""
			echo ""
			echo "configuring to listen on $snort_iface"
			echo ""
			break
		fi
	fi
done
#This statement sets the interface name the snort alert comes from. Pretty sure this is just metadata for you to correlate which interface on a sensor sent events
#A To-do would be to allow the user to enter something more descriptive than 'eth0', like maybe 'DMZ interface' or 'CORE SW 1 interface'. something useful..
sed -i 's/#config interface:  eth0/config interface: '$snort_iface'/' /root/barnyard2.conf.tmp

#This line is the most important of all. This is where the magic happens. If barnyard2 doesn't have valid credentials to access the snort database, then the database doesnt' get populated and you don't
#get intrusion events on your web interface. This MUST be populated with valid credentials, the correct database name, and the correct host.
#seeing as how AS doesn't support distributed installations yet, localhost should be the only host to use, and the database name should be snort, as configured above.
sed -i 's/#   output database: log, mysql, user=root password=test dbname=db host=localhost/output database: log, mysql user=snort password='$MYSQL_PASS_1' dbname=snort host=localhost/' /root/barnyard2.conf.tmp

cp /root/barnyard2.conf.tmp /usr/local/snort/etc/barnyard2.conf

#cleaning up the temp file
rm /root/barnyard2.conf.tmp

#This is where ask the user if they want the interface up to sniff on boot. This is required if they want snort up and sniffing traffic on startup.
#I took the easy way out here. If the user says yes, I just add an entry to /etc/rc.local to bring up the interface in sniffing mode on boot.
#todo: add a proper init script.

while true; do
	read -p "Would you like to have $snort_iface configured to run in promiscuous mode on boot?
THIS IS REQUIRED if you want snort to run Daemonized on boot.
Selecting 1 adds an entry to rc.local to bring the interface up in promiscuous mode with no arp or multicast response to prevent discovery of the sniffing interface.
Selecting 2 does nothing and lets you configure things on your own.
" boot_iface

	case $boot_iface in
		1 )
        cat /etc/rc.local | grep -v exit > /root/rc.local.tmp
		echo "ifconfig $snort_iface up -arp -multicast promisc" >> /root/rc.local.tmp
		cp /root/rc.local.tmp /etc/rc.local
		ethtool -K $snort_iface gro off > /dev/null 2>&1
		ethtool -K $snort_iface lro off > /dev/null 2>&1
		echo ""
		break
        ;;
        2 )
        echo "okay then, I'll let you do things on your own."
		echo ""
		break
        ;;
        * )
		echo "I didn't understand your answer. Please try again."
		echo ""
        ;;
	esac
done

#We ask the user if they want snort and barnyard dropped to rc.local. We also do some fault checking. If they choose to NOT have an interface up and ready for snort at boot, we don't let them start barnyard2 or snort via rc.local (they would just error out anyhow)

while true; do
	read -p "
Do you want snort and barnyard to run at startup?
Select 1 for entries to be added to rc.local. BEWARE: IF you selected to not have the boot interface brought up on startup, you are advised to select option two; snort and barnyard cannot run successfully without an interface to bind to on startup.
Select 2 If you do not have an interface to dedicate to sniffing traffic only or do not want snort or barnyard to run on system startup.
" startup_choice

# There's an if statement in here for a specific reason:
# If a user makes a choice that they want snort to run on bootup, but do not configure the snort interface to be up on system startup
	case $startup_choice in
		1 )
		echo "adding snort and barnyard2 to rc.local"
		cp /etc/rc.local /root/rc.local.tmp
		if [ $boot_iface = "1" ]; then
			echo ""
			echo "#start snort as user/group snort, Daemonize it, read snort.conf and run against $snort_iface" >> /root/rc.local.tmp
			echo "/usr/local/snort/bin/snort -D -u snort -g snort -c /usr/local/snort/etc/snort.conf -i $snort_iface" >> /root/rc.local.tmp
			echo "/usr/local/bin/barnyard2 -c /usr/local/snort/etc/barnyard2.conf -G /usr/local/snort/etc/gen-msg.map -S /usr/local/snort/etc/sid-msg.map -d /var/log/snort -f snort.u2 -w /var/log/snort/barnyard2.waldo -D" >> /root/rc.local.tmp
			cp /root/rc.local.tmp /etc/rc.local
			rm /root/rc.local.tmp
			echo ""
			break
		else
			echo ""
			echo "You've specified to start barnyard and snort at boot, but do not have $snort_iface to be up and listening at boot. This is will not work! Please selection option 2 to continue."
			continue
		fi
		;;
		2 )
		echo ""
		echo "Confirmed. Snort and Barnyard will NOT be configured to start on system boot."
		echo ""
		break
			;;
		* )
		echo ""
		echo "Invalid choice. Please try again."
		echo ""
		;;
	esac
done

#Perform the interface installation step here
while true; do
	echo "Please select a web interface to install:"
	echo "1. Snort Report"
	echo "2. Aanval"
	read -p "Please choose option 1 or option 2" ui_choice
	case $ui_choice in
		1)
		echo "You have chosen to install Snort Report."
		bash snortreport-ubuntu.sh
		if [ $? != 0 ]; then
			echo "It looks like the installation did not go as according to plan."
			echo "Verify you have network connectiviy and try again"
			continue
		else
			echo "Installation successful!"
			echo "Navigate to http://[ip address]/snortreport to get started."
			break
		fi
		;;
		2)
		echo "You have chosen to install Aanval."
		bash aanval-ubuntu.sh
		if [ $? != 0 ]; then
			echo "It looks like the installation did not go as according to plan."
			echo "Verify you have network connectiviy and try again"
			continue
		else
			echo "Installation successful!"
			echo "Navigate to http://[ip address]/aanval to get started"
			echo "Aanval will ask you for username and password for the aanvaldb user."
			echo "Username: snort"
			echo "Password: $MYSQL_PASS_1"
			echo "Default web interface credentials"
			echo "Username:root"
			echo "Password:specter"
			echo "Please note that you will have to configure and enable the Aanval snort module to see events from your snort sensor."
			echo "Please check out aanval.com on how to do this. It's incredibly simple."
			break
		fi
		;;
		*)
		echo "invalid choice. please try again."
		continue
		;;
	esac
done

#todo list: give users the ability to choose 2 interfaces or a bridge interface for inline deployments. Instead of fucking around with daq, just have snort listen to a bridge interface... Well, until I learn to do this properly.

echo "One last choice. A reboot is recommended, considering all the configuration files we've messed with and updates that have been applied to the system. Do you want to reboot now or later? Again, 1 is yes, 2 is no."

read reboot_choice

case $reboot_choice in
			1)
			echo "Roger that. Rebooting now."
			init 6
			;;
			2)
			echo "Okay, I'd recommend going down for reboot before putting this thing in production, however."
			;;
			*)
			echo "I didn't understand your choice, so I'm going to assume you're not ready to reboot the system. when you are, just run the reboot or init 6 command (prepended by sudo if you're not running as root) and you're done here."
			;;
esac

echo "We're all done here. Have a nice day."

exit 0
