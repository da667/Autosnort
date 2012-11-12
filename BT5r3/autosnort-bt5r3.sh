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
# derived via locate, utilizing "updatedb" and "locate snort. 
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


###Step 3: SSH Check. ###


# Checking to ensure sshd is running done by running ps-ef, grepping for sshd, using wc -l and if we have more than one line, using that as a sign that SSHD is running 
# Anyone who's used ps-ef | grep [blah] knows that it will always return 0. 
# However if it only returns one line, that means the process you are searching for is not actually running.
# If YOU have a more reliable method of checking via a command that sshd is running, I'm all ears.

# disabling this check for backtrack. Snort is not being installed as a sensor. If you really want a full-blown sensor install, uncomment the lines below.

#echo "Checking to ensure sshd is running."

#	if [ $(/bin/ps -ef |/bin/grep sshd |/usr/bin/wc -l) -gt 1 ]
#		then
#			echo "sshd is running "
#		else
#			echo "sshd isn't running... The script can continue, but in most cases, sshd is use for remotely managing snort sensors."
#			while true; do
#               read -p "Continue? (y/n)" sshwarn
#                   case $sshwarn in
#                       [Yy]* ) break;;
#                       [Nn]* ) echo "Cancelling."; exit 0;;
#                       * ) echo "Please answer yes or no.";;
#                   esac
#			done
#	fi
	

####step 4: patches and package pre-reqs####

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

# Here is where we'd normally acquire mysql server and client. bt5 has these installed by default. 
# Doing mysql_secure_installation would make sense here, to ensure that the mysql install is secured.
# Disabling for backtrack. uncomment to configure mysql for a snort unified file database backend.

# echo "Running mysql_secure_installation. Follow the prompts and everything will be fine."
#service mysql start
#/usr/bin/mysql_secure_installation
#if [ $? -eq 0 ]; then
#	echo "Mysql updated and secured. Be sure to store the root mysql user password somewhere safe."
#	echo ""
#	while true; do
#                read -p "Would you like to have mysqld run at startup? (y/n)" mysql_auto
#                   case $mysql_auto in
#                       [Yy]* ) 	update-rc.d mysql defaults
#							break
#							;;
#                       [Nn]* ) echo "Continuing."
#							break
#							;;
#							   
#                       * ) echo "Please answer yes or no."
#							;;
#                   esac
#	done
#else
#	echo "Something went wrong somewhere. Re-run the script /usr/bin/mysql_secure_installation then run this script again. Aborting. "
#	exit 1
#fi

# disabled for backtrack 5
# Grab jpgraph and throw it in /var/www
# Required to display graphs in snort report UI

#echo "Downloading and installing jpgraph."

#cd /usr/src
#wget http://hem.bredband.net/jpgraph/jpgraph-1.27.1.tar.gz
#mkdir /var/www/jpgraph
#tar -xzvf jpgraph-1.27.1.tar.gz
#cp -r jpgraph-1.27.1/src /var/www/jpgraph

#echo "jpgraph downloaded to /usr/src. installed to /var/www/jpgraph."

# this is usually where we install snort report.

#echo "downloading and installing snort report"

#cd /usr/src
#wget http://www.symmetrixtech.com/ids/snortreport-1.3.3.tar.gz
#tar -xzvf snortreport-1.3.3.tar.gz -C /var/www/

# this portion of the script gives the user a choice to modify srconf.php automatically or doing it themselves. 
# For snortreport to work it needs the username and password for the snort mysql user.

#echo "You will need to Enter the mysql database password for the database user \"snort\" (we have not created the regular snort user or snort database user yet, we will be doing so shortly) in the file /var/www/snortreport-1.3.3/srconf.php on the line \"\$pass = \"YOURPASS\";"
#echo "I will give you the choice of doing this yourself, or having me do it for you."
#echo "Enter 1 to input the mysql snort user password and have the line autopopulated."
#echo "Enter 2 to modify srconf.php yourself"
#read srconf_choice

#case $srconf_choice in
#						1)
#                        echo "I need the password, please."
#							while true
#								do
#									read -s -p "Please enter the snort database user password:" mysql_pass_1
#									echo
#									read -s -p "Confirm:" mysql_pass_2
#									echo
#										if [ "$mysql_pass_1" == "$mysql_pass_2" ]
#										then
#											break
#										else
#											echo -e "Passwords do not match."
#										fi
#								done
#                       echo "modifying srconf.php..."
#copying srconf.php to the root directory, modifying it via sed, replacing it, them removing it.
#			sed s/YOURPASS/$mysql_pass_1/ /var/www/snortreport-1.3.3/srconf.php >/root/srconf.php.tmp && mv /root/srconf.php.tmp /var/www/snortreport-1.3.3/srconf.php && rm /root/srconf.php.tmp
#			echo "password insertion complete."
			
#						;;
#                        *)
#                        echo "Very Well. The file is srconf.php, located in /var/www/snort-report-1.3.3. Remember to look for the line \$pass = \"YOURPASS\"; and input the correct password."
#                        ;;        
#esac

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

#now we download and build snort itself. The --enable-sourcefire option gives us ppm and perfstats for performance troubleshooting.
#same as with daq, the download link needs to change if a new version of snort comes out. Go to snort.org/downloads, "copy link location" paste link below into wget statement. Profit.
#TODO: future-proof this the same way I did above with daq. cd snort-# change the -O statement to snort.tar.gz

echo "acquiring snort from snort.org..."
echo ""

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
useradd -g snort snort
chown snort:snort /var/log/snort

#just as the echo statement says, it's a good idea to assign a password to the snort user.
#TODO: make the snort user a service account - set its login shell to /bin/false maybe?

echo "we added the snort user and group, the snort user requires a password, please enter a password and confirm this password."

passwd snort

#here we ask the user where the snortrules snapshot is for us to untar and move it in place.
#TODO: pulled pork integration

echo "The next portion of the script requires the snort rules tarball to be present on the system, and will prompt for the directory path and filename. If you have not done so already, copy the snort rules tarball to this system, note the directory path and file name, then press enter here to continue."

echo "Directory where snort rules are located: (no trailing slashes)"
read rule_directory
echo "Rules file name:"
read rule_filename

echo "unpacking rules file from $rule_directory/$rule_filename and moving to /usr/local/snort"
echo ""

tar -xzvf $rule_directory/$rule_filename -C /usr/local/snort
mkdir /usr/local/snort/lib/snort_dynamicrules

# We're running uname -a to determine if the user is running a 32 or 64 bit arch to determine which SO rules to copy.
# TODO: futureproof the cp statement (e.g. cp 2.9.*/* instead of 2.9.3.0/*)

arch=`uname -a | cut -d" " -f12`
case $arch in
		i[36]86)
		echo "copying 32-bit SO-rules from Ubuntu 10.04 precompiled directory."
		cp /usr/local/snort/so_rules/precompiled/Ubuntu-10-4/i386/2.9.*/* /usr/local/snort/lib/snort_dynamicrules
		;;
		x86_64)
		echo "copying 64-bit SO-rules from Ubuntu 10.04 precompiled directory."
		cp /usr/local/snort/so_rules/precompiled/Ubuntu-10-4/x86-64/2.9.*/* /usr/local/snort/lib/snort_dynamicrules
		;;
		*)
		echo "unable to determine architecture from your answer. SO rules have not been copied and will not work until copied. If you would like to do this manually, navigate to /usr/local/snort/so_rules/precompiled, select your distro and arch, and copy the 2.9.3.0/* directories to /usr/local/snort/lib/snort_dynamicrules then run the ldconfig command."
		;;
esac

echo "ldconfig processing and creation of whitelist/blacklist.rules files taking place."
echo ""

touch /usr/local/snort/rules/white_list.rules && touch /usr/local/snort/rules/black_list.rules && ldconfig

echo "Modifying snort.conf -- specifying unified 2 output, SO whitelist/blacklist and standard rule locations."

#here we take the copy of snort.conf from /usr/local/snort/etc, copy it to root's home directory and perform some sed-foo on the file, then copy it back.

cd /root

cp /usr/local/snort/etc/snort.conf /root/snort.conf.tmp

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

#Disabling the download of barnyard2

#echo "downloading, making and compiling barnyard2."

#wget http://www.securixlive.com/download/barnyard2/barnyard2-1.9.tar.gz -O barnyard2.tar.gz

#tar -xzvf barnyard2.tar.gz

#cd barnyard2*

#autoreconf -fvi -I ./m4
#determining arch for backtrack, at least for the barnyard install is pointless; libmysqlclient.so is in /usr/lib in both 32 and 64-bit.
#./configure --with-mysql && make && make install

#echo "configuring supporting infrastructure for barnyard (file ownership to snort user/group, file permissions, waldo file, etc.)"


#the statements below copy the barnyard2.conf file where we want it and establish proper rights to various barnyard2 files and directories.

#cp etc/barnyard2.conf /usr/local/snort/etc
#mkdir /var/log/barnyard2
#chmod 666 /var/log/barnyard2
#touch /var/log/snort/barnyard2.waldo
#chown snort.snort /var/log/snort/barnyard2.waldo

#echo "building mysql infrastructure"


#we ask the user for a password for snort report earlier. here's where we build the mysql database and give rights to the snort user to manage the database.

#echo "the next several steps will need you to enter the mysql root user password more than once."

#echo "enter the mysql root user password to create the snort database."
#mysql -u root -p -e "create database snort;"
#echo "enter the mysql root user password again to create the snort database schema"
#mysql -u root -p -D snort < ./schemas/create_mysql
#echo "you'll need to enter the mysql root user password one more time to create the snort database user and grant it permissions to the snort database."
#the snort user's mysql password (dumped into srconf earlier) is set here. 
#Create the snort database user with rights to modify all this stuff.

#mysql -u root -p -e "grant create, insert, select, delete, update on snort.* to snort@localhost identified by '$mysql_pass_1';"

#now we modify the barnyard2 conf file, same way we set up the snort.conf file -- make a temp copy in root's home, sed-foo it, then replace it. Voila!

#echo "building barnyard2.conf, pointing to reference.conf, classication.conf, gen-msg and sid-msg maps, as well as use the local mysql database, snort database, and snort user."

#cd /root

#cp /usr/local/snort/etc/barnyard2.conf barnyard2.conf.tmp

#sed -i 's/config reference_file:      \/etc\/snort\/reference.config/config reference_file:      \/usr\/local\/snort\/etc\/reference.config/' barnyard2.conf.tmp

#sed -i 's/config classification_file: \/etc\/snort\/classification.config/config classification_file: \/usr\/local\/snort\/etc\/classification.config/' barnyard2.conf.tmp

#sed -i 's/config gen_file:            \/etc\/snort\/gen-msg.map/config gen_file:            \/usr\/local\/snort\/etc\/gen-msg.map/' barnyard2.conf.tmp

#sed -i 's/config sid_file:            \/etc\/snort\/sid-msg.map/config sid_file:             \/usr\/local\/snort\/etc\/sid-msg.map/' barnyard2.conf.tmp 

#sed -i 's/#config hostname:   thor/config hostname: localhost/' barnyard2.conf.tmp

#echo "what interface will snort be listening on? (choose one interface. While it isn't necessary it is highly recommend you make this a separate interface from the interface you will be managing this sensor (e.g. using ssh to connect to this device) from:"

#read snort_iface

#sed -i 's/#config interface:  eth0/config interface: '$snort_iface'/' barnyard2.conf.tmp

#sed -i 's/#   output database: log, mysql, user=root password=test dbname=db host=localhost/output database: log, mysql user=snort password='$mysql_pass_1' dbname=snort host=localhost/' barnyard2.conf.tmp

#cp barnyard2.conf.tmp /usr/local/snort/etc/barnyard2.conf

#cleaning up the temp file
#rm barnyard2.conf.tmp

#echo "Would you like to have $snort_iface configured to be up at boot? (useful if you want snort to run on startup.)"
#echo "Select 1 for yes, or 2 for no"

#this choice determines whether we'll be hacking /etc/network/interfaces to have the interface started at boot.

#read boot_iface 

#case $boot_iface in
#                1)
#                echo "appending to /etc/network/interfaces"
#		cp /etc/network/interfaces /root/interfaces.tmp
#		echo "#appending $snort_iface to start at boot to run snort on boot on $snort_iface." >> /root/interfaces.tmp
#		echo "auto $snort_iface" >> /root/interfaces.tmp
#		echo "iface $snort_iface inet promisc manual" >> /root/interfaces.tmp
#		echo "up ifconfig $snort_iface up" >> /root/interfaces.tmp
#		cp /root/interfaces.tmp /etc/network/interfaces
#		rm /root/interfaces.tmp
#                ;;
#                2)
#                echo "okay then, I'll let you do things on your own."
#                ;;
#                *)
#		echo "I didn't understand your answer, so I'll tell you what to do: if you want snort to run on an interface that is not a bridge interface, the interface needs to be up. To have this done automatically at boot time, you have to modify /etc/network/interfaces and input the following:
#auto [iface name]
#iface [iface name] inet manual
#up ifconfig [iface name] up. For bridge interfaces.... well, they aren't supported by this script... yet."
#                ;;
#esac

#echo "Almost there! Do you want snort and barnyard to run at startup? 1 for yes, 2 for no."
#read startup_choice

#case $startup_choice in
#			1)
#			echo "adding snort and barnyard2 to rc.local"
#			cp /etc/rc.local /root/rc.local.tmp
#			sed -i 's/exit 0/ /' /root/rc.local.tmp
#			echo "#start snort as user/group snort, Daemonize it, read snort.conf and run against $snort_iface" >> /root/rc.local.tmp
#			echo "/usr/local/snort/bin/snort -D -u snort -g snort -c /usr/local/snort/etc/snort.conf -i $snort_iface" >> /root/rc.local.tmp
#			echo "/usr/local/bin/barnyard2 -c /usr/local/snort/etc/barnyard2.conf -G /usr/local/snort/etc/gen-msg.map -S /usr/local/snort/etc/sid-msg.map -d /var/log/snort -f snort.u2 -w /var/log/snort/barnyard2.waldo -D" >> /root/rc.local.tmp
#			echo "exit 0" >> /root/rc.local.tmp
#			cp /root/rc.local.tmp /etc/rc.local
#			rm /root/rc.local.tmp
#			;;
#			2)
#			echo "okay then."
#			;;
#			*)
#			echo "I didn't understand your choice. If you want snort and barnyard 2 to run at boot, add them to /etc/rc.local"
#			;;
#esac

#echo "NOTE: the password chosen for the snort user earlier ($mysql_pass_1) will be used to give snort report the ability to read data from the database. record this password for safekeeping!"

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