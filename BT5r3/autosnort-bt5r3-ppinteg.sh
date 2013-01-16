#!/bin/bash
# auto-snort for Backtrack 5r3
# purpose: update the old version of snort on BT5.
# installs daqlibs and REQUIRES a snort.org/VRT tarball to finish properly.
# Contact info:
# @da_667 via twitter
# deusexmachina667@gmail.com

# You'll notice that a lot of the functions for this script are disabled.
# Why is that? Check out the README that came with this script, I explain thoroughly why I did it this way.
# So if you want mysql, httpd, snortreport (the default front-end), and jpgraph installed, you'll have to uncomment
# the necessary lines below.
# the script is easy to read, and the comments should be easy to follow.


#Declaring Function
#this function is just a quick way to call apt-get install

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

###Step 0: OS Check. ###
# The commands below check that we're running backtrack in what's really a terrible way. 
# There's gotta be a better way to make sure we're running backtrack. 
# If the check fails, we give the user the option as to whether or not they want to continue, regardless.
echo "OS Version Check."
echo ""
release=`cat /etc/issue | awk '{ print $1 $2 $3 }'`
if [ $release != "BackTrack5R3" ]
	then
        echo " "
		echo "Unable to determine if this is Backtrack 5 R3. Be warned this script has not been tested on other platforms."
            while true; do
               read -p "Continue? (y/n)" warncheck
                  case $warncheck in
                       [Yy]*) break;;
                       [Nn]*) echo "Cancelling."; exit 0;;
                       *) echo "Please answer yes or no.";;
                   esac
				done
	else
        echo "Verified as Backtrack 5 R3. Good to go."
		echo " "
    fi
	 
###Step 1: Removing the old installation ###
# We ask the user if they want to remove the old snort installation or not. 
# The packages below are default in a BT5 R3 fresh install, and the locations in the rm -rf statement were all 
# derived via locate, utilizing "updatedb" and "locate snort". 
# This removes all references to snort on the system (except for metasploit references)

while true; do
	read -p "Would you like to remove the current snort installation? y/n (yes recommended) " snort_remove
        case $snort_remove in
            [Yy]*) 
				apt-get remove -y snort snort-rules-default snort-common snort-common-libraries libprelude2 oinkmaster
				rm -rf /etc/snort /etc/init.d/snort /etc/cron.daily/5snort /etc/default/snort /etc/ppp/ip*/snort /etc/init.d/snort /etc/logrotate.d/snort /var/lib/dpkg/info/snort* /var/lib/update-rc.d/is\snort /var/lib/update-rc.d/snort /var/log/snort/* /usr/share/applications/backtrack-snort*
				break
				;;
            [Nn]*) echo "continuing"
				break
				;;
            *) echo "Please answer yes or no.";;
        esac

done

###Step 2: Connectivity Check. ###	 
# We check for internet connectivity. 
# Connectivity check uses icmp, pings google once and checks for exit 0 status of the command. 
# If the ICMP check fails, and the user knows for certain they have internet access, we give them the option to skip this step.


echo "Checking internet connectivity (pinging google.com)"
echo ""
     ping google.com -c1 &> /dev/null
     if [ $? -eq 0 ]; then
        echo "Connectivity looks good!"
     else
        read -p "Ping to google has failed. Do you have internet access? Would you like to continue? (y/n)" pingfail
		  case $pingfail in
            [Yy}*) break;;
            [Nn]* ) echo "Cancelling."; exit 0;;
             * ) echo "Please answer yes or no.";;
		  esac
     fi



	

####step 3: patches and package pre-reqs####

# Here we call apt-get update and apt-get -y upgrade to ensure all repos and stock software is fully updated.
# For consistency, if the command chain exits on anything other than a 0 exit code, we notify the user that updates were not successfully installed.

echo "Installing system updates."
echo ""

apt-get update && apt-get -y upgrade 
if [ $? -eq 0 ]; then
	echo "Packages and repos are fully updated."
else
	echo "apt-get upgrade or update failed."
fi

echo "Grabbing required packages via apt-get."

# This is where we would normally grab packages to install a full snort sensor with a web front-end. I'm only installing libpcre3-dev here, and only because snort requires it.


 declare -a packages=(libpcre3-dev);
 install_packages ${packages[@]}



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
echo ""

mkdir /var/snort && mkdir /var/log/snort

echo "creating snort user and group, assigning ownership of /var/log/snort to snort user and group."
echo ""

#users and groups for snort to run non-priveledged.

groupadd snort
useradd -g snort snort -s /bin/false
chown snort:snort /var/log/snort

#just as the echo statement says, it's a good idea to assign a password to the snort user.
#TODO: make the snort user a service account - set its login shell to /bin/false maybe?

echo "we added the snort user and group, the snort user requires a password, please enter a password and confirm this password."

passwd snort

arch=`uname -a | cut -d" " -f12`

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
                    mkdir /usr/local/snort/lib/snort_dynamicrules
                    if [ $arch = "i686" ]; then
                        echo "copying 32-bit SO rules."
                        cp /usr/local/snort/so_rules/precompiled/Debian-6-0/i386/2.9.*/* /usr/local/snort/lib/snort_dynamicrules
                    elif [ $arch = "x86_64" ]; then
                        echo "copying 64-bit SO rules."
                        cp /usr/local/snort/so_rules/precompiled/Debian-6-0/x86-64/2.9.*/* /usr/local/snort/lib/snort_dynamicrules
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
			mkdir /usr/local/snort/etc
			mkdir /usr/local/snort/so_rules
			mkdir /usr/local/snort/rules
			mkdir /usr/local/snort/preproc_rules
			mkdir /usr/local/snort/lib/snort_dynamicrules
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
			declare -a packages=( libarchive-tar-perl libcrypt-ssleay-perl libwww-perl );
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
					echo "# so rule stub path" >> snort.conf.tmp
					echo "include \$SO_RULE_PATH/so_rules.rules" >> /root/snort.conf.tmp
					#rule processing time
					cd /usr/src/pulledpork-*
					perl pulledpork.pl -c /usr/src/pulledpork-*/etc/pulledpork.conf -n #we have the tarball on disk in the temp directory, so we don't want to try and hit snort.org to get it again.
					perl pulledpork.pl -c /usr/src/pulledpork-*/etc/pulledpork.conf -n
					
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
echo ""

touch /usr/local/snort/rules/white_list.rules && touch /usr/local/snort/rules/black_list.rules && ldconfig

echo "Modifying snort.conf -- specifying unified 2 output, SO whitelist/blacklist and standard rule locations."

#here we take the copy of snort.conf from /usr/local/snort/etc, copy it to root's home directory and perform some sed-foo on the file, then copy it back.

cd /root



#this sets the dynamic preprocessor directory

sed -i 's/dynamicpreprocessor directory \/usr\/local\/lib\/snort_dynamicpreprocessor\//dynamicpreprocessor directory \/usr\/local\/snort\/lib\/snort_dynamicpreprocessor\//' snort.conf.tmp

#this sets where libsf_engine.so is located

sed -i 's/dynamicengine \/usr\/local\/lib\/snort_dynamicengine\/libsf_engine.so/dynamicengine \/usr\/local\/snort\/lib\/snort_dynamicengine\/libsf_engine.so/' snort.conf.tmp

#now for the actual SO rules directory.

sed -i 's/dynamicdetection directory \/usr\/local\/lib\/snort_dynamicrules/dynamicdetection directory \/usr\/local\/snort\/lib\/snort_dynamicrules/' snort.conf.tmp

#setting unified2 as the output type.
#TODO: set the output type to syslog for a barebones install.

sed -i 's/# output unified2: filename merged.log, limit 128, nostamp, mpls_event_types, vlan_event_types/output unified2: filename snort.u2, limit 128/' snort.conf.tmp

#remember how we added blacklist and whitelist.rules files earlier? we have to point snort to those files now.

sed -i 's/var WHITE_LIST_PATH ..\/rules/var WHITE_LIST_PATH \/usr\/local\/snort\/rules/' snort.conf.tmp

sed -i 's/var BLACK_LIST_PATH ..\/rules/var BLACK_LIST_PATH \/usr\/local\/snort\/rules/' snort.conf.tmp

cp snort.conf.tmp /usr/local/snort/etc/snort.conf

#we clean up after ourselves...

rm snort.conf.tmp



echo ""
echo "Snort has been installed to /usr/local/snort/bin/. snort.conf is located in /usr/local/snort/etc"

# We ask the user if they want to reboot. I consider it good practice to perform a system reboot after pulling down a multitude of updates.

echo ""
echo "A reboot is recommended, considering all the configuration files we've messed with and updates that have been applied to the system. Do you want to reboot now? 1 is yes, 2 is no."

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

echo ""
echo "We're all done here. Have a nice day."

exit 0