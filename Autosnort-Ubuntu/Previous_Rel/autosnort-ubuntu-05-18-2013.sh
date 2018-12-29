#!/bin/bash
#auto-snort script v2 - Verified as working for Ubuntu 12.04
#v2 fixes: strictly calling bash to allow declare statements and arrays to work properly on Ubuntu.
#Major thanks to Kyle Johnson - Zenimax Studios sysadmin for code contributions in this version
#removed newline characters. they were pretty pointless.
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

#This is a function to make the whole pulled pork section _MUCH_ easier to read. This same code gets re-used a few times.

pp_preconfig()
{
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
}

#This is another chunk of code that gets re-used heavily during the pulled pork rule processing section.

pp_postcheck()
{
if [ $? != 0 ]; then
	echo ""
	echo "rule processing for snort rules has failed for some reason. check the pulledpork error output."
	continue
else
	echo "rules processed successfully."
	echo ""
fi
}

#Pre checks: These are a couple of basic sanity checks the script does before proceeded.
#1. Set the working directory that autosnort was ran out of
#2. OS version check
#3. root privs check
#4. quick sshd check
#5. wget check. wget is used quite extensively by this script. Ubuntu should have it by default.

 hp=`pwd`

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


echo "User Check"
     if [ $(whoami) != "root" ]
          then
               echo "This script must be ran with sudo or root privileges, or this isn't going to work."
		exit 1
          else
               echo "We are root."
     fi
	 

echo "Checking to ensure sshd is running. If sshd is NOT running, it would be a good idea to start it."

/sbin/status ssh

/usr/bin/which wget 2>&1 >> /dev/null
if [ $? -ne 0 ]; then
    echo "wget not found. Installing."
	install_packages wget
else
    echo "found wget."
fi
		
# System Update and package installation
# This system perform an apt repo update and a system upgrade (read: installs patches)
# The next section only installs what I consider "core" packages required to build DAQ, libdnet and snort
# The section afterward verifies whether or not the user plans to build a full stand-alone sensor with a web interface. If yes, we install mysqld and apache.


echo "Performing apt-get update and apt-get upgrade (with -y switch)"

apt-get update && apt-get -y upgrade 
if [ $? -eq 0 ]; then
	echo "Packages and repos are fully updated."
else
	echo "apt-get upgrade or update failed."
fi

echo "Grabbing required packages via apt-get."

#These packages are required at a minimum to build snort and barnyard + their component libraries

declare -a packages=( ethtool build-essential libpcap0.8-dev libpcre3-dev bison flex libpcap-ruby autoconf libtool libmysqlclient-dev );
install_packages ${packages[@]}

while true; do
	echo "Do you plan on installing a web interface to review intrusion events, such as snortreport, aanval or base (If in doubt, select option 1)"
	read -p "
1 is yes
2 is no
" ui_inst
	case $ui_inst in
	1)
	echo "Acquiring and installing mysql and apache2. You will need to assign a password to the root mysql user. Remember the root password! You're gonna need it!"
	declare -a packages=( mysql-server apache2 )
	install_packages ${packages[@]}
	echo ""
	break
	;;
	2)
	echo "Moving to snort installation"
	echo ""
	break
	;;
	*)
	echo "Invalid choice, please enter 1 or 2."
	continue
	;;
	esac
done

#This section is a hack I implemented using wget, grep and cut. We pull the downloads page from snort.org and cut out some strings to determine the version of snort and/or daq to pull.
#After that we pull snort, daq, and libnet them compile them.

echo "acquiring latest version of snort and daq."
echo ""

cd /tmp 1>/dev/null
wget -q http://snort.org/snort-downloads -O /tmp/snort-downloads
snorttar=`cat /tmp/snort-downloads | grep snort-[0-9]|cut -d">" -f2 |cut -d"<" -f1 | head -1`
daqtar=`cat /tmp/snort-downloads | grep daq|cut -d">" -f2 |cut -d"<" -f1 | head -1`
snortver=`echo $snorttar | sed 's/.tar.gz//g'`
daqver=`echo $daqtar | sed 's/.tar.gz//g'`
rm /tmp/snort-downloads
cd /usr/src 1>/dev/null
wget http://snort.org/dl/snort-current/$snorttar -O $snorttar
wget http://snort.org/dl/snort-current/$daqtar -O $daqtar

echo "Unpacking daq libraries"
echo ""

tar -xzvf $daqtar
cd $daqver

echo "Configuring, making and compiling DAQ. This will take a moment or two."
echo ""

./configure && make && make install && ln -s /usr/local/lib/libsfbpf.so.0 /usr/lib/libsfbpf.so.0

echo "DAQ libraries installed."
echo ""

#libdnet hasn't been updated since 2007. Pretty sure we won't have to worry about the filename changing.

echo "acquiring libdnet."
echo ""

cd /usr/src
wget http://libdnet.googlecode.com/files/libdnet-1.12.tgz
tar -xzvf libdnet-1.12.tgz
cd libdnet-1.12

echo "configuring, making, compiling and linking libdnet. This will take a moment or two."
echo ""

#this is in regards to the fix posted in David Gullett's snort guide - /usr/local/lib isn't include in ld path by default in Ubuntu.

./configure && make && make install && ln -s /usr/local/lib/libdnet.1.0.1 /usr/lib/libdnet.1

echo "libdnet installed and linked."
echo ""

# The --enable-sourcefire option gives us ppm and perfstats for performance troubleshooting.

cd /usr/src
tar -xzvf $snorttar
cd $snortver

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



arch=`uname -i`

#This block if code gets very very hairy, very very fast.
#What it boils down to, is that the user is given a choice:
#Install rules via a rule tarball they provide (advanced/heroic/hardcore mode)
#Use pulled pork to provide the default security over connectivity ruleset (easy mode)

while true; do
        echo "Do you want to install a rule tarball or use pulled pork?"
        read -p "
select 1 if you would like to install a VRT tarball. (Advanced Users)
select 2 for pulled pork installation and setup.
" rule_install
        case $rule_install in
# If the user selects option 1, we do a couple of sanity checks to make sure the user gave us a valid file that is a tarball.
# Then we process it and move the rules where snort expects to find them.
# Three things --
# 1. This method only supports VRT rule tarballs
# 2. This method does NOT verify the so rules of the rule tarball are compatible with the version of snort installed.
# 3. The user will need to use some way to create a sid-msg.map (such as oink master's create-sidmap.pl script), the sid-msg.map included in the snortrules tarball is NOT up to date.
			1 )
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
					echo "Rule installation succesful. WARNING: You will want to generate a new sid-msg.map, the one included in the rule tarball is likely old and incomplete. Use a tool like oinkmaster's create-sidmap.pl to do this."
					cd /root
                    break
                else
                    echo "that file doesn't exist. try again."
                fi
			
            ;;

			2 )
			# If the user selects option 2, we do necessary to give the user a base security over connectivity ruleset via pulled pork, and a reference snort.conf from labs.snort.org:
			# 1. pull packages via apt
			# 2. download pulled pork
			# 3. modify config files
			# 4. download, unpack and configure a security over connectivity ruleset for the user
            echo "chose pp"
			
			mkdir /usr/local/snort/etc
			mkdir /usr/local/snort/so_rules
			mkdir /usr/local/snort/rules
			mkdir /usr/local/snort/preproc_rules
			mkdir /usr/local/snort/lib/snort_dynamicrules
			
			#we wget the snort-rules page off  snort.org, do a lot of text manipulation from the html file downloaded, and set variables: two variables for attempting to downloading the VRT example snort.conf from labs.snort.org, and four variables for the version of snort to download rules for via pulledpork.
			wget -q http://www.snort.org/snort-rules -O /tmp/snort-rules
			choice1conf=`cat /tmp/snort-rules  | grep snortrules-snapshot-[0-9][0-9][0-9][0-9]|cut -d"-" -f3 |cut -d"." -f1 | sort -ur | head -1` #snort.conf download attempt 1
			choice2conf=`cat /tmp/snort-rules  | grep snortrules-snapshot-[0-9][0-9][0-9][0-9]|cut -d"-" -f3 |cut -d"." -f1 | sort -ur | head -2 | tail -1` #snort.conf download attempt 2
			choice1=`echo $choice1conf |sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./'|sort -ru | head -1` #pp config choice 1
			choice2=`echo $choice2conf | sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./'|sort -ru | head -2|tail -1` #pp config choice 2
			choice3=`cat /tmp/snort-rules  | grep snortrules-snapshot-[0-9][0-9][0-9][0-9]|cut -d"-" -f3 |cut -d"." -f1 | sort -ru | head -3 | tail -1 | sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./'`
			choice4=`cat /tmp/snort-rules  | grep snortrules-snapshot-[0-9][0-9][0-9][0-9]|cut -d"-" -f3 |cut -d"." -f1 | sort -ru | head -4| tail -1 | sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./'`
			
			wget http://labs.snort.org/snort/$choice1conf/snort.conf -O /usr/local/snort/etc/snort.conf

			if [ $? != 0 ];then
				echo "attempt to download a $currentver snort.conf from labs.snort.org failed. attempting to download snort.conf for $prevver"
				wget http://labs.snort.org/snort/$choice2conf/snort.conf -O /usr/local/snort/etc/snort.conf
				if [ $? != 0 ];then
					echo "this attempt to download a snort.conf has failed as well. Aborting pulledpork rule installation."
					continue 
				else
					echo "successfully downloaded snort.conf for $prevver. This will likely work for now until they upload a new snort.conf to labs.snort.org."
				fi
			else
				echo "successfully downloaded snort.conf for $currentver."
			fi
			
			#download required packages, and pulledpork for rule processing.
			cd /usr/src
			declare -a packages=( perl libarchive-tar-perl libcrypt-ssleay-perl liblwp-protocol-https-perl );
			install_packages ${packages[@]}
            wget http://pulledpork.googlecode.com/files/pulledpork-0.6.1.tar.gz -O pulledpork-0.6.1.tar.gz
            tar -xzvf pulledpork-0.6.1.tar.gz
            cd pulledpork-*/etc
			
			#Create a copy of the original conf file (in case the user needs it), ask the user for an oink code, then fill out a really stripped down pulledpork.conf file with only the lines needed to run the perl script
			cp pulledpork.conf pulledpork.conf.orig
			
			read -p "What is your oink code?   " o_code
			q
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
			echo ""
			echo "Since this script can't tell how many days it has been since snort $currentver has been released, and I don't want to waste 15 minutes of your time, what version of snort do want to download rules for?"
			read -p "
Select 1 to download rules for snort $choice1 (Select this if it has been more than 30 days since snort $currentver has been released or if you have a VRT rule subscription oinkcode)
Select 2 to download rules for snort $choice2 (Select this if it has been less than 30 days since snort $currentver has been released and you do NOT have a VRT rule subscription oinkcode)
Select 3 to download rules for snort $choice3 (Select this if it has been less than 30 days since snort $choice1 AND $choice2 have been released and you do not have a VRT rule subscription oinkcode)
Select 4 to download rules for snort $choice4 (Select this as a last resort, if all other options do not work.)
" pp_choice
			cd ..
				case $pp_choice in
					1)
					perl pulledpork.pl -c /usr/src/pulledpork-*/etc/pulledpork.conf -g 
					if [ $? != 0 ]; then
						echo "rule download for $currentver snort rules has failed. Check your oinkcode, connectivity, firewall rules and/or proxies and try again. Rememeber to wait AT LEAST 15 minutes before attempting another download."
						continue
					else 
						pp_preconfig
						perl pulledpork.pl -c /usr/src/pulledpork-*/etc/pulledpork.conf -n 
						pp_postcheck
					fi
					break
					;;
					2)
					perl pulledpork.pl -S $choice2 -c /usr/src/pulledpork-*/etc/pulledpork.conf -g
					if [ $? != 0 ]; then
						echo "rule download for $currentver snort rules has failed. Check your oinkcode, connectivity, firewall rules and/or proxies and try again. Rememeber to wait AT LEAST 15 minutes before attempting another download."
						continue
					else 
						pp_preconfig
						perl pulledpork.pl -S $choice2 -c /usr/src/pulledpork-*/etc/pulledpork.conf -T -n 
						pp_postcheck
					fi
					break
					;;
					3)
					perl pulledpork.pl -S $choice3 -c /usr/src/pulledpork-*/etc/pulledpork.conf -g
					if [ $? != 0 ]; then
						echo "rule download for $currentver snort rules has failed. Check your oinkcode, connectivity, firewall rules and/or proxies and try again. Rememeber to wait AT LEAST 15 minutes before attempting another download."
						continue
					else 
						pp_preconfig
						perl pulledpork.pl -S $choice3 -c /usr/src/pulledpork-*/etc/pulledpork.conf -T -n 
						pp_postcheck
					fi
					break
					;;
					4)
					perl pulledpork.pl -S $choice4 -c /usr/src/pulledpork-*/etc/pulledpork.conf -g
					if [ $? != 0 ]; then
						echo "rule download for $currentver snort rules has failed. Check your oinkcode, connectivity, firewall rules and/or proxies and try again. Rememeber to wait AT LEAST 15 minutes before attempting another download."
						continue
					else 
						pp_preconfig
						perl pulledpork.pl -S $choice4 -c /usr/src/pulledpork-*/etc/pulledpork.conf -T -n 
						pp_postcheck
					fi
					break
					;;
					*)
					echo "Invalid selection. Please try again."
					continue
					;;
				esac
            ;;
            * )
				echo "invalid choice, try again."
				continue
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

#keep an original copy of the by2.conf in case the user needs to change settings.
cp /usr/local/snort/etc/barnyard2.conf /usr/local/snort/etc/barnyard2.conf.orig

echo "config reference_file:	/usr/local/snort/etc/reference.config" >> /root/barnyard2.conf.tmp
echo "config classification_file:	/usr/local/snort/etc/classification.config" >> /root/barnyard2.conf.tmp
echo "config gen_file:	/usr/local/snort/etc/gen-msg.map" >> /root/barnyard2.conf.tmp
echo "config sid_file:	/usr/local/snort/etc/sid-msg.map" >> /root/barnyard2.conf.tmp
echo "config hostname: localhost" >> /root/barnyard2.conf.tmp

# The if/then check here is to make sure the user chose to install a web interface. If they chose no, they chose not to install mysql server, so we can skip all this.

if [ $ui_inst = 1 ]; then
	echo "building mysql infrastructure"
	# We need to ask the user to provide a password for the snort database user.
	# We save the snort database user's password as an environment variable, and in the barnyard2.conf.tmp file
	# This is so we can re-use this variable for child shell scripts (e.g. scripts that install the different web interfaces)
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
			echo "output database: log,mysql, user=snort password=$MYSQL_PASS_1 dbname=snort host=localhost" >> /root/barnyard2.conf.tmp
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
else
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
				echo "password confirmed."
				echo ""
			else
				echo ""
				echo -e "Passwords do not match. Please try again."
				continue
			fi
			echo "output database: log,mysql, user=$rdb_user password=$rdb_pass_1 dbname=$rdb_name host=$rdb_host" >> /root/barnyard2.conf.tmp
			break
			;;
			2)
			echo "You have indicated that you do not have a remote have a remote database to report events to."
			echo "You have also indicated you have no desire to install a local database or webUI for local events"
			echo "The only valid output options you will have available will be syslog or no output!"
			break
			;;
			*)
			echo "Invalid choice, please try again."
			continue
			;;
		esac
	done
fi

	
cd /root



#We have the user decide what interface snort will be listening on. This is setup for the next couple of statements (e.g. if they want the interface up and sniffing at boot, etc.). The first choice here is to pretty up barnyard 2 output)

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

echo "config interface: $snort_iface" >> /root/barnyard2.conf.tmp
echo "input unified2" >> /root/barnyard2.conf.tmp


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
		continue
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
			echo "/usr/local/bin/barnyard2 -c /usr/local/snort/etc/barnyard2.conf -d /var/log/snort -f snort.u2 -w /var/log/snort/barnyard2.waldo -D" >> /root/rc.local.tmp
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

#Perform the interface installation step here. first, we drop back to the initial working directory where autosnort was ran from.
while true; do
	echo "Please select an output interface to install:"
	echo "1. Snort Report"
	echo "2. Aanval"
	echo "3. BASE"
	echo "4. rsyslog"
	echo "5. Snorby"
	echo "6. no web interface or output method will be installed"
	read -p "Please choose an option." ui_choice
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
			echo "Please check out aanval.com on how to do this. Its incredibly simple."
			break
		fi
		;;
		3)
		echo "You have chosen to install BASE."
		bash base-ubuntu.sh
		if [ $? != 0 ]; then
			echo "It looks like the installation did not go as according to plan."
			echo "Verify you have network connectiviy and try again"
			continue
		else
			echo "Installation successful!"
			echo "Navigate to http://[ip address]/base to get started"
			echo "You will be asked for the username and password for the snort database."
			echo "Username: snort"
			echo "Password: $MYSQL_PASS_1"
			break
		fi
		;;
		4)
		echo "You have chosen to install rsyslog."
		bash syslog_full-ubuntu.sh
		if [ $? != 0 ]; then
			echo "It looks like the installation did not go as according to plan."
			echo "Please try again"
			continue
		else
			echo "Installation successful!"
			echo "Please ensure 514/udp outbound is open on THIS sensor."
			echo "Ensure 514/udp inbound is open on your syslog server/SIEM and is ready to recieve events."
			break
		fi
		;;
		5)
		echo "You have chosen to install snorby."
		bash snorby-ubuntu.sh
		if [ $? != 0 ]; then
			echo "It looks like the installation did not go as according to plan."
			echo "Please try again"
			continue
		else
			echo "Installation successful!"
			echo "Default credentials are user: snorby@snorby.org password: snorby"
			echo "I tried implementing a method to start the delayed_job and/or cache jobs on system start... but it appears to not work at all."
			echo "If your system is rebooted for any reason, on restart, you will need to run:"
			echo "cd /var/www/snorby && ruby script/delayed_job start"
			echo "followed by:"
			echo "cd /var/www/snorby && rails runner 'Snorby::Jobs::SensorCacheJob.new(false).perform; Snorby::Jobs::DailyCacheJob.new(false).perform'"
			echo "Copy this down, because I also advise rebooting this system before putting it into production; you'll need to run those two commands if you want snorby to be functional!"
			echo ""
			break
		fi
		;;
		6)
		echo "You have chosen to not install any interface (Web or syslog)"
		echo "Either you plan on using snort for research/rule writing purposes.. or Have a remote database/C2 system you will be reporting events to."
		echo "I hope you know what you are doing!"
		break
		;;
		*)
		echo "invalid choice. please try again."
		continue
		;;
	esac
done

#todo list: give users the ability to choose 2 interfaces or a bridge interface for inline deployments.

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