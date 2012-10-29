#!/bin/bash
#auto-snort script for CentOS 6.3
#Thanks to Kyle Johnson and Andy Walker for their code contributions on the initial Ubuntu release.
#Purpose: Stand up a snort sensor in as much time as it takes to compile this stuff and modify the files as necessary.

#Declaring Functions - This function is an easier way to reuse the yum code. 
install_packages()
{
 echo "Installing packages: ${@}"
 yum -y update && yum -y install ${@}
 if [ $? -eq 0 ]; then
  echo "Packages successfully installed."
 else
  echo "Packages failed to install!"
  exit 1
 fi
}

####step 1: pre-reqs.#### 
# We need to check OS we're installing to, net connectivity, user we are running as, ensure sshd is running and wget is available.

#assumes CentOS 6.3 checks lsb_release -r and awks the version number to verify what OS we're running.
#this method is more reliable than my catting /etc/motd.
#warns the user if we're not running CentOS 6.3 that this script has not been tested on other platforms/distros
#asks if they want to continue.
echo "OS Version Check."
     release=`cat /etc/redhat-release|awk '{print $3}'`
     if [ $release != "6.3" ]
          then
               echo "This is not CentOS 6.3. This script has not been tested on other platforms."
               while true; do
                   read -p "Continue? (y/n)" warncheck
                   case $warncheck in
                       [Yy]* ) break;;
                       [Nn]* ) echo "Cancelling."; exit;;
                       * ) echo "Please answer yes or no.";;
                   esac
done
          else
               echo "Version is 6.3. Good to go."
		
     fi

#assumes internet connectivity. Connectivity check uses icmp, pings google once and checks for exit 0 status of the command. Exits script on error and notifies user connectivity check failed.
#ICMP check made cleaner. The user doesn't need to see the errors for the connectivity check. We notify them that it fails if it does.
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
               echo "This script must be ran with root priveleges either as the root user or via sudo."
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

#the below checks for the existence of wget and offers to download it via yum if it isn't installed.
#Wget check cleaned up, redirected to /dev/null. We look for an exit 0 status against "which wget".
#any status other than 0 results in use asking the user if they want to install wget, which is required for us to download several sourcetarballs for the script.

/usr/bin/which wget 2>&1 >> /dev/null
if [ $? -ne 0 ] 
	then echo "wget not found. Install wget?"
		case $wget_install in
			[yY] | [yY][Ee][Ss])
				install_packages wget
				;;
			* )
				echo "Either you selected no or I didn't understand. Wget is required to continue. Aborting."
                exit 1
                ;;
        esac
	else
        echo "found wget."
fi
		
####step 2: patches and package pre-reqs####

#Here we call yum -y upgrade to ensure all repos and stock software is fully updated.
#For consistency, if the command chain exits on anything other than a 0 exit code, we notify the user that updates were not successfully installed.

echo "Performing yum upgrade (with -y switch)"

yum -y upgrade 
if [ $? -eq 0 ]; then
	echo "Packages and repos are fully updated."
else
	echo "yum upgrade failed."
fi

echo "Installing EPEL repos for required packages."
wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-7.noarch.rpm
rpm -Uvh epel-release-6-7.noarch.rpm


echo "Grabbing required packages via yum."

#Here we grab base install requirements for a full stand-alone snort sensor, including web server for web UI. 
#nbtscan, libnet, libdnet and adodb are manual installs. Why
#TODO: Give users a choice -- do they want to install a collector, a full stand-alone sensor, or a barebones sensor install?

declare -a packages=(nmap httpd make gcc libtool pcre-devel libnet-devel libdnet-devel libpcap-devel mysql mysql-bench mysql-devel mysql-server php php-common php-gd php-cli php-mysql php-pear.noarch php-pear-DB.noarch php-pear-File.noarch flex bison kernel-devel libxml2-devel );
install_packages ${packages[@]}

echo "starting apache and mysql, and adding them to runlevel 3 via chkconfig"
service mysqld start
service httpd start
chkconfig mysqld --add
chkconfig httpd --add
chkconfig mysqld --level 3 on
chkconfig httpd --level 3 on


#Here we download the mysql client/server packages and notify the user that they will need to input a root user password.
#TODO: If the user is installing a barebones sensor, do not download or install mysql.

echo "Running the mysql_secure_install script. Follow the prompts and everything will be fine."

/usr/bin/mysql_secure_installation
if [ $? -eq 0 ]; then
	echo "Mysql updated and secured. Be sure to store the root mysql user password somewhere safe."
else
	echo "Something went wrong somewhere. Re-run the script /usr/bin/mysql_secure_installation then run this script again. Aborting. "
	exit 1
fi

echo "Getting, unpacking and installing nbtscan."

mkdir /usr/src/nbtscan-src
cd /usr/src/nbtscan-src
wget http://www.unixwiz.net/tools/nbtscan-source-1.0.35.tgz -O nbtscan-1.0.35.tgz
tar -xzvf nbtscan-1.0.35.tgz
make

#Grab jpgraph and throw it in /var/www/html
#Required to display graphs in snort report UI

echo "Downloading and installing jpgraph."

cd /usr/src
wget http://hem.bredband.net/jpgraph/jpgraph-1.27.1.tar.gz
mkdir /var/www/html/jpgraph
tar -xzvf jpgraph-1.27.1.tar.gz
cp -r jpgraph-1.27.1/src /var/www/html/jpgraph

echo "jpgraph downloaded to /usr/src. installed to /var/www/jpgraph."

#now to install snort report.
#TODO: I want to give the user a choice between snort report, BASE, snorby, etc. if a web front-end is to be installed.
#TODO: install apache mod_ssl. Configure redirects from port 80 to 443 (force SSL) require users to review snortreport over HTTPS for added security.

echo "downloading and installing snort report"

cd /usr/src
wget http://www.symmetrixtech.com/ids/snortreport-1.3.3.tar.gz
tar -xzvf snortreport-1.3.3.tar.gz -C /var/www/html

#this portion of the script gives the user a choice to modify srconf.php automatically or doing it themselves. 
#For snortreport to work it needs the username and password for the snort mysql user.

echo "You will need to Enter the mysql database password for the database user \"snort\" (we have not created the regular snort user or snort database user yet, we will be doing so shortly) in the file /var/www/snortreport-1.3.3/srconf.php on the line \"\$pass = \"YOURPASS\";"
echo "I will give you the choice of doing this yourself, or having me do it for you."
echo "Enter 1 to input the mysql snort user password and have the line autopopulated."
echo "Enter 2 to modify srconf.php yourself"
read srconf_choice

case $srconf_choice in
						1 )
                        echo "I need the password, please."
							while true
								do
									read -s -p "Please enter the snort database user password:" mysql_pass_1
									echo
									read -s -p "Confirm:" mysql_pass_2
									echo
										if [ "$mysql_pass_1" == "$mysql_pass_2" ]
										then
											break
										else
											echo -e "Passwords do not match."
										fi
								done
                        echo "modifying srconf.php..."
#copying srconf.php to the root directory, modifying it via sed, replacing it, them removing it.
			sed s/YOURPASS/$mysql_pass_1/ /var/www/html/snortreport-1.3.3/srconf.php >/root/srconf.php.tmp && mv /root/srconf.php.tmp /var/www/html/snortreport-1.3.3/srconf.php && rm /root/srconf.php.tmp
			echo "password insertion complete."
			
						;;
                        * )
                        echo "Very Well. The file is srconf.php, located in /var/www/snort-report-1.3.3. Remember to look for the line \$pass = \"YOURPASS\"; and input the correct password."
                        ;;        
esac

#get daq libraries from snort.org, drop them in /usr/src, untar, then build them.
#if a new version of daq comes out, the only thing that needs to be modified here is the download link.

echo "acquiring Data Acquistion Libraries version 1.1.1 (DAQ) from snort.org..."

cd /usr/src

#change this download link to get the latest version of daq.snort.org/downloads. right click copy link location. paste below. Profit. Need to find a way to automatically download the latest daq

wget http://www.snort.org/downloads/1850 -O daqlibs.tar.gz
tar -xzvf daqlibs.tar.gz
cd daq-*



echo "Configuring, making and compiling. This will take a moment or two."

./configure && make && make install

echo "DAQ libraries installed."

#commenting out the libdnet installation since CENTOS repos seem to have libdnet. Want to see if the version they have works.
#libdnet hasn't been updated since 2007. Pretty sure we won't have to worry about the filename changing.

#echo "acquiring libdnet 1.12 library from googlecode.com..."

#cd /usr/src
#wget http://libdnet.googlecode.com/files/libdnet-1.12.tgz
#tar -xzvf libdnet-1.12.tgz
#cd libdnet-1.12

#echo "configuring, making, compiling and linking libdnet. This will take a moment or two."

#this is in regards to the fix posted in David Gullett's snort guide, having to link libdnet to get snort to work correctly.

#./configure && make && make install && ln -s /usr/local/lib/libdnet.1.0.1 /usr/lib/libdnet.1

#echo "libdnet installed and linked."

#now we download and build snort itself. The --enable-sourcefire option gives us ppm and perfstats for performance troubleshooting.
#same as with daq, the download link needs to change if a new version of snort comes out. Go to snort.org/downloads, "copy link location" paste link below into wget statement. Profit.
#TODO: future-proof this the same way I did above with daq. cd snort-# change the -O statement to snort.tar.gz

echo "acquiring snort from snort.org..."

cd /usr/src
wget http://www.snort.org/downloads/1862 -O snort-2.9.3.1.tar.gz
tar -xzvf snort-2.9.3.1.tar.gz
cd snort-2.9.3.1

echo "configuring snort (options --prefix=/usr/local/snort and --enable-sourcefire), making and installing. This will take a moment or two."

./configure --prefix=/usr/local/snort --enable-sourcefire && make && make install

echo "snort install complete. Installed to /usr/local/snort."

#supporting infrastructure for snort.

echo "creating directories /var/log/snort, and /var/snort."

mkdir /var/snort && mkdir /var/log/snort

echo "creating snort user and group, assigning ownership of /var/log/snort to snort user and group. \n"

#users and groups for snort to run non-priveledged.

groupadd snort
useradd -g snort snort
chown snort:snort /var/log/snort

#just as the echo statement says, it's a good idea to assign a password to the snort user. I didn't see this explicitly done in the 6.3 install guide.

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

tar -xzvf $rule_directory/$rule_filename -C /usr/local/snort
mkdir /usr/local/snort/lib/snort_dynamicrules

# We're running uname -i to determine if the user is running a 32 or 64 bit arch to determine which SO rules to copy.
# TODO: futureproof the cp statement (e.g. cp 2.9.*/* instead of 2.9.3.0/*)

arch=`uname -i`
case $arch in
		i386 )
		echo "copying 32-bit SO-rules from CentOS 10.04 precompiled directory."
		cp /usr/local/snort/so_rules/precompiled/CentOS-5-4/i386/2.9.3.1/* /usr/local/snort/lib/snort_dynamicrules
		;;
		x86_64 )
		echo "copying 64-bit SO-rules from CentOS 10.04 precompiled directory."
		cp /usr/local/snort/so_rules/precompiled/CentOS-5-4/x86-64/2.9.3.1/* /usr/local/snort/lib/snort_dynamicrules
		;;
		* )
		echo "unable to determine architecture. SO rules have not been copied and will not work until copied. If you would like to do this manually, navigate to /usr/local/snort/so_rules/precompiled, select your distro and arch, and copy the 2.9.3.0/* directories to /usr/local/snort/lib/snort_dynamicrules then run the ldconfig command."
		;;
esac

echo "ldconfig processing and creation of whitelist/blacklist.rules files taking place."

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

#now we have to download barnyard 2 and configure all of its stuff.

echo "downloading, making and compiling barnyard2."

wget https://nodeload.github.com/firnsy/barnyard2/tarball/master -O barnyard2.tar.gz

tar -xzvf barnyard2.tar.gz

cd firnsy-barnyard2*

sh autogen.sh

#remember when we checked if the user is 32 or 64-bit? Well we saved that answer and use it to help find where the mysql libs are on the system.

case $arch in
                i386)
                echo "preparing configure statement to point to 32-bit libraries."
				./configure --with-mysql --with-mysql-libraries=/usr/lib/mysql


                ;;
                x86_64)
                echo "preparing configure statement to point to 64-bit libraries"
				./configure --with-mysql --with-mysql-libraries=/usr/lib64/mysql


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


#we ask the user for a password for snort report earlier. here's where we build the mysql database and give rights to the snort user to manage the database.

echo "the next several steps will need you to enter the mysql root user password more than once."

echo "enter the mysql root user password to create the snort database."
mysql -u root -p -e "create database snort;"
echo "enter the mysql root user password again to create the snort database schema"
mysql -u root -p -D snort < ./schemas/create_mysql
echo "you'll need to enter the mysql root user password one more time to create the snort database user and grant it permissions to the snort database."
#the snort user's mysql password (dumped into srconf earlier) is set here. 
#Create the snort database user with rights to modify all this stuff.

mysql -u root -p -e "grant create, insert, select, delete, update on snort.* to snort@localhost identified by '$mysql_pass_1';"

#now we modify the barnyard2 conf file, same way we set up the snort.conf file -- make a temp copy in root's home, sed-foo it, then replace it. Voila!

echo "building barnyard2.conf, pointing to reference.conf, classication.conf, gen-msg and sid-msg maps, as well as use the local mysql database, snort database, and snort user."

cd /root

cp /usr/local/snort/etc/barnyard2.conf barnyard2.conf.tmp

sed -i 's/config reference_file:      \/etc\/snort\/reference.config/config reference_file:      \/usr\/local\/snort\/etc\/reference.config/' barnyard2.conf.tmp

sed -i 's/config classification_file: \/etc\/snort\/classification.config/config classification_file: \/usr\/local\/snort\/etc\/classification.config/' barnyard2.conf.tmp

sed -i 's/config gen_file:            \/etc\/snort\/gen-msg.map/config gen_file:            \/usr\/local\/snort\/etc\/gen-msg.map/' barnyard2.conf.tmp

sed -i 's/config sid_file:            \/etc\/snort\/sid-msg.map/config sid_file:             \/usr\/local\/snort\/etc\/sid-msg.map/' barnyard2.conf.tmp 

sed -i 's/#config hostname:   thor/config hostname: localhost/' barnyard2.conf.tmp

echo "what interface will snort be listening on? (choose one interface. While it isn't necessary it is highly recommend you make this a separate interface from the interface you will be managing this sensor (e.g. using ssh to connect to this device) from:"

read snort_iface

sed -i 's/#config interface:  eth0/config interface: '$snort_iface'/' barnyard2.conf.tmp

sed -i 's/#   output database: log, mysql, user=root password=test dbname=db host=localhost/output database: log, mysql user=snort password='$mysql_pass_1' dbname=snort host=localhost/' barnyard2.conf.tmp

cp barnyard2.conf.tmp /usr/local/snort/etc/barnyard2.conf

#cleaning up the temp file

rm barnyard2.conf.tmp

echo "Would you like to have $snort_iface configured to be up at boot? (useful if you want snort to run on startup.)"
echo "Select 1 for yes, or 2 for no"

#The choice above determines whether or not we'll be adding an entry to /etc/sysconfig/network-scripts for the snort interface and adding the rc.local hack to bring snort's sniffing interface up at boot.

read boot_iface 

case $boot_iface in
                1 )
                echo "creating /etc/sysconfig/network-scripts/ifcfg-$snort_iface"
				touch /root/ifcfg-$snort_iface.tmp
				echo "#Settings for snort sensing interface" >> /root/ifcfg-$snort_iface.tmp
				echo "DEVICE=\"$snort_iface\"" >> /root/ifcfg-$snort_iface.tmp
				echo "BOOTPROTO=\"none\"" >> /root/ifcfg-$snort_iface.tmp
				echo "NM_CONTROLLED=\"no\"" >> /root/ifcfg-$snort_iface.tmp
				echo "ONBOOT=\"yes\"" >> /root/ifcfg-$snort_iface.tmp
				echo "TYPE=\"Ethernet\"" >> /root/ifcfg-$snort_iface.tmp
				echo "#this line is to make sure snort's sniffing interface comes up at boot in promiscuous mode. we turn off arp and multicast response, because a sniffing interface should not respond to ARP or multicast traffic." >> /etc/rc.local
				echo "ifconfig $snort_iface up -arp -multicast promisc" >> /etc/rc.local
				cp /root/ifcfg-$snort_iface.tmp /etc/sysconfig/network-scripts/ifcfg-$snort_iface
				rm /root/ifcfg-$snort_iface.tmp
                ;;
                2 )
                echo "okay then, I'll let you do things on your own."
                ;;
                * )
				echo "I didn't understand your answer"
                ;;
esac

echo "Almost there! Do you want snort and barnyard to run at startup? 1 for yes, 2 for no."
read startup_choice

case $startup_choice in
			1 )
			echo "adding snort and barnyard2 to rc.local"
			cp /etc/rc.local /root/rc.local.tmp
#this is a hack to make the snort interface come up on boot. adding that PROMISC=yes option in ifcfg-[interface]
#in /etc/sysconfig/network-scripts doesn't work, in spite of everyone saying it should.

			echo "#start snort as user/group snort, Daemonize it, read snort.conf and run against $snort_iface" >> /root/rc.local.tmp
			echo "/usr/local/snort/bin/snort -D -u snort -g snort -c /usr/local/snort/etc/snort.conf -i $snort_iface" >> /root/rc.local.tmp
			echo "/usr/local/bin/barnyard2 -c /usr/local/snort/etc/barnyard2.conf -G /usr/local/snort/etc/gen-msg.map -S /usr/local/snort/etc/sid-msg.map -d /var/log/snort -f snort.u2 -w /var/log/snort/barnyard2.waldo -D" >> /root/rc.local.tmp
			
			cp /root/rc.local.tmp /etc/rc.local
			rm /root/rc.local.tmp
			;;
			2 )
			echo "okay then."
			;;
			* )
			echo "I didn't understand your choice. If you want snort and barnyard 2 to run at boot, add them to /etc/rc.local"
			;;
esac

#todo list: give users the ability to choose 2 interfaces or a bridge interface for inline deployments. Instead of fucking around with daq, just have snort listen to a bridge interface... Well, until I learn to do this properly.

echo "NOTE: the password chosen for the snort user earlier ($mysql_pass_1) will be used to give snort report the ability to read data from the database. record this password for safekeeping!"

echo "One last choice. A reboot is recommended, considering all the configuration files we've messed with and updates that have been applied to the system. Do you want to reboot now or later? Again, 1 is yes, 2 is no."

read reboot_choice

case $reboot_choice in
			1 )
			echo "Roger that. Rebooting now."
			init 6
			;;
			2 )
			echo "Okay, I'd recommend going down for reboot before putting this thing in production, however."
			;;
			* )
			echo "I didn't understand your choice, so I'm going to assume you're not ready to reboot the system. when you are, just run the reboot or init 6 command (prepended by sudo if you're not running as root) and you're done here."
			;;
esac

echo "We're all done here. Have a nice day."

exit 0