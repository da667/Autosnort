#!/bin/sh
#auto-snort script v1 - Verified as working for Ubuntu 12.04
# purpose: from nothing to full snort in gods know how much time it takes to compile some of this shit.
#at some point, I want this script to log to something for error reporting.
####step 1: pre-reqs.#### 
# We need to check OS we're installing to, net connectivity, user we are running as, ensure sshd is running and wget is available.

#assumes ubuntu 12.04 checks /etc/motd and cuts the version number to verify what OS we're running. Note: need a more reliable method to verify OS version.

echo "OS Version Check.\n"
     release=`lsb_release -r|awk '{print $2}'`
     if [ $release != "12.04" ]
          then
               echo "This is not Ubuntu 12.04. This script has not been tested on other platforms. If you would like to continue, please wait. Otherwise please enter ctrl+c now."
               sleep 10
          else
               echo "Version is 12.04. Good to go.\n"
		echo " "
     fi

sleep 2

#assumes internet connectivity. Connectivity check uses icmp, pings google once, greps for "recieved," to verify successful ping.

echo "Checking internet connectivity (pinging google.com) \n"
     ping google.com -c1 2>&1 >> /dev/null
     if [ $? == 0 ]; then
          echo "Connectivity looks good!\n"
     else
          echo "Ping to google has failed. Please verify you have network connectivity or ICMP outbound is allowed. Seriously, what harm is it going to do? \n"
   	  exit 1
     fi

sleep 2


#assumes script is ran as root. root check performed via use of whoami

echo "User Check \n"
     if [ $(whoami) != "root" ]
          then
               echo "This script must be ran with sudo or root privileges, or this isn't going to work. \n"
		exit 1
          else
               echo "We are root. Gods of this system. \n"
		echo " "
     fi

sleep 2

#checking to ensure sshd is running done by running ps-ef, grepping for sshd, and pulling the 25th line via cut with space as the delimiter.

echo "\n"
echo "Checking to ensure sshd is running. \n"

	if [ $(ps -ef | grep sshd | head -1 | cut -f25 -d " ") != "/usr/sbin/sshd" ]
		then
			echo "sshd isn't running or isn't located in sbin. \n"
		else
			echo "sshd is up and running... \n"
	fi

sleep 2
#the below checks for the existence of wget and offers to download it via apt-get if it isn't installed.
	/usr/bin/which wget
		if [ $? -ne 0 ] 
			then
        		echo "wget not found. Install wget?"
         case $wget_install in
                                [yY] | [yY][Ee][Ss])
                                echo "installing wget. \n"
                                apt-get install -y wget
                                echo "wget installed. \n"
                                ;;
                                *)
                                echo "Either you selected no or I didn't understand. Wget is required to continue"
                                exit 1
                                ;;
                                esac
		else
        		echo "found wget. \n"
		fi
		
sleep 2
####step 2: patches and package pre-reqs####

#Here we call apt-get update and apt-get -y upgrade to ensure all repos and stock software is fully updated.

echo "Performing apt-get update and apt-get upgrade (with -y switch)\n"
sleep 2
apt-get update && apt-get -y upgrade 
echo "\n"
echo "Packages and repos are fully updated."

sleep 2

echo " "
echo "Grabbing required packages via apt-get.\n"

sleep 2

#Here we grab base install requirements for a full stand-alone snort sensor, including web server for web UI. Maybe in a later version of the script, we can include a select statement where there user states this is a stand-alone sensor, whether or not they want web access (e.g. just send alert messages via syslog to a SIEM) or if this is part of a distributed install (mysql client + stunnel, configure to tunnel back to master UI server.) For now, I want to focus on getting the user a stand-alone snort box with a basic web UI. The packages below are recommended for that purpose.

apt-get -y install nmap nbtscan apache2 php5 php5-mysql php5-gd libpcap0.8-dev libpcre3-dev g++ bison flex libpcap-ruby make autoconf libtool
echo "\n"
echo "base packages acquired \n"

sleep 2

#Here we download the mysql client/server packages and notify the user that they will need to input a root user password.

echo "Acquiring and install mysql server and client packages. You will need to assign a password to the root mysql user. \n"

sleep 4

apt-get -y install mysql-server libmysqlclient-dev

echo "\n"
echo "mysql server and client installed. Make sure to store the root user password somewhere safe. \n"

sleep 2

#Grab jpgraph and throw it in /var/www

echo "Downloading and installing jpgraph.\n"

sleep 2

cd /usr/src
wget http://hem.bredband.net/jpgraph/jpgraph-1.27.1.tar.gz
mkdir /var/www/jpgraph
tar -xzvf jpgraph-1.27.1.tar.gz
cp -r jpgraph-1.27.1/src /var/www/jpgraph

echo "jpgraph downloaded to /usr/src. installed to /var/www/jpgraph.\n"


sleep 2

#now to install snort report. In the future, I want to give the user a choice between snort report, BASE, snorby, or no web interface at all (barebones/distributed install)

echo "downloading and installing snort report"

cd /usr/src
wget http://www.symmetrixtech.com/ids/snortreport-1.3.3.tar.gz
tar -xzvf snortreport-1.3.3.tar.gz -C /var/www/

clear

#this portion of the script gives the user a choice to modify srconf.php automatically or doing it themselves. For snortreport to work it needs the username and password for the snort mysql user.

echo "You will need to Enter the mysql database password for the user \"snort\" (we have not created the snort user yet, we will be doing so shortly) in the file /var/www/snortreport-1.3.3/srconf.php on the line \"\$pass = \"YOURPASS\";"
echo "I will give you the choice of doing this yourself, or having me do it for you."
echo "\n"
echo "Enter 1 to input the mysql snort user password and have the line autopopulated."
echo "Enter 2 to modify srconf.php yourself"
echo "\n"
read srconf_choice

case $srconf_choice in
			[1] | [Oo][Nn][Ee])
                        echo "I need the password, please. \n"
			read mysql_pass
                        echo "modifying srconf.php... \n"
#copying srconf.php to the root directory, modifying it via sed, replacing it, them removing it.
			sed s/YOURPASS/$mysql_pass/ /var/www/snortreport-1.3.3/srconf.php >/root/srconf.php.tmp && mv /root/srconf.php.tmp /var/www/snortreport-1.3.3/srconf.php && rm /root/srconf.php.tmp
			echo "password insertion complete.\n"
			clear
			;;
                        *)
                        echo "Very Well. The file is srconf.php, located in /var/www/snort-report-1.3.3. Remember to look for the line \$pass = \"YOURPASS\"; and input the correct password."
                        ;;        
esac

sleep 2

#get daq libraries from snort.org, then build them.

echo "acquiring Data Acquistion Libraries version 1.1.1 (DAQ) from snort.org...\n"

cd /usr/src

#change this download link to get the latest version of daq.snort.org/downloads. right click copy link location. paste below. Profit. Need to find a way to automatically download the latest daq

wget http://www.snort.org/downloads/1806 -O daqlibs.tar.gz
tar -xzvf daqlibs.tar.gz
cd daq-*

sleep 2

echo "Configuring, making and compiling. This will take a moment or two.\n"

sleep 2

./configure && make && make install

echo "DAQ libraries installed.\n"

#download, compile and make libdnet, then link it to work properly.

echo "acquiring libdnet 1.12 library from googlecode.com...\n"

cd /usr/src
wget http://libdnet.googlecode.com/files/libdnet-1.12.tgz
tar -xzvf libdnet-1.12.tgz
cd libdnet-1.12
sleep 2

echo "configuring, making, compiling and linking libdnet. This will take a moment or two.\n"

sleep 2

./configure && make && make install && ln -s /usr/local/lib/libdnet.1.0.1 /usr/lib/libdnet.1

echo "libdnet installed and linked.\n"

#now we download and build snort itself. The --with-sourcefire option gives us ppm and perfstats for performance troubleshooting.
#same as with daq, the download link needs to change if a new version of snort comes out. Go to snort.org/downloads, "copy link location" paste link below into wget statement. Profit.

echo "acquiring snort 2.9.3 from snort.org...\n"

cd /usr/src
wget http://www.snort.org/downloads/1814 -O snort-2.9.3.tar.gz
tar -xzvf snort-2.9.3.tar.gz
cd snort-2.9.3

sleep 2

echo "configuring snort (options --prefix=/usr/local/snort and --enable-sourcefire), making and installing. This will take a moment or two.\n"

sleep 2

./configure --prefix=/usr/local/snort --enable-sourcefire && make && make install

echo "snort install complete.\n"

sleep 2

#supporting infrastructure for snort.

echo "creating directories /var/log/snort, and /var/snort \n"

sleep 2

mkdir /var/snort && mkdir /var/log/snort

echo "creating snort user and group, assigning ownership of /var/log/snort to snort user and group. \n"

sleep 2

#users and groups for snort to run non-priveledged.

groupadd snort
useradd -g snort snort
chown snort:snort /var/log/snort

clear

echo "we added the snort user and group, the snort user requires a password, please enter a password."

passwd snort

clear

echo "The next portion of the script requires the snort rules tarball to be present on the system, and will prompt for the directory path and filename. If you have not done so already, copy the snort rules tarball to this system, note the directory path and file name, then press enter here to continue."

echo "Directory where snort rules are located: (no trailing slashes)  \n"
read rule_directory
echo "Rules file name:\n"
read rule_filename

echo "unpacking rules file from $rule_directory/$rule_filename and moving to /usr/local/snort \n"

tar -xzvf $rule_directory/$rule_filename -C /usr/local/snort
mkdir /usr/local/snort/lib/snort_dynamicrules

sleep 2

# We have to ask the user if they are using 32-bit or a 64-bit distro to copy the SO_rules from the correct directory, otherwise SO rules will not work, then we're creating whitelist.rules and blacklist.rules and letting ldconfig do its voodoo.

clear

arch=`uname -p`
case $arch in
		1)
		echo "copying 32-bit SO-rules from Ubuntu 10.04 precompiled directory."
		cp /usr/local/snort/so_rules/precompiled/Ubuntu-10-4/i386/2.9.3.0/* /usr/local/snort/lib/snort_dynamicrules
		;;
		2)
		echo "copying 64-bit SO-rules from Ubuntu 10.04 precompiled directory."
		cp /usr/local/snort/so_rules/precompiled/Ubuntu-10-4/x86-64/2.9.3.0/* /usr/local/snort/lib/snort_dynamicrules
		;;
		*)
		echo "unable to determine architecture from your answer. SO rules have not been copied and will not work until copied. If you would like to do this manually, navigate to /usr/local/snort/so_rules/precompiled, select your distro and arch, and copy the 2.9.3.0/* directories to /usr/local/snort/lib/snort_dynamicrules then run the ldconfig command."
		;;
esac

echo "ldconfig processing and creation of whitelist/blacklist.rules files taking place."
sleep 2

touch /usr/local/snort/rules/white_list.rules && touch /usr/local/snort/rules/black_list.rules && ldconfig

echo "Modifying snort.conf -- specifying unified 2 output, SO whitelist/blacklist and standard rule locations."

sleep 2

#here we take the copy of snort.conf from /usr/local/snort/etc, copy it to root's home directory and perform shitloads of sed-foo on the file, then copy it back. It's maaaagic.

cd /root

cp /usr/local/snort/etc/snort.conf /root/snort.conf.tmp

#this sets the dynamic preprocessor directory

sed -i 's/dynamicpreprocessor directory \/usr\/local\/lib\/snort_dynamicpreprocessor\//dynamicpreprocessor directory \/usr\/local\/snort\/lib\/snort_dynamicpreprocessor\//' snort.conf.tmp

#this sets where libsf_engine.so is located

sed -i 's/dynamicengine \/usr\/local\/lib\/snort_dynamicengine\/libsf_engine.so/dynamicengine \/usr\/local\/snort\/lib\/snort_dynamicengine\/libsf_engine.so/' snort.conf.tmp

#now for the actual SO rules directory.

sed -i 's/dynamicdetection directory \/usr\/local\/lib\/snort_dynamicrules/dynamicdetection directory \/usr\/local\/snort\/lib\/snort_dynamicrules/' snort.conf.tmp

#setting unified2 as the output type. perhaps in the future, set the output type to syslog for a barebones install.

sed -i 's/# output unified2: filename merged.log, limit 128, nostamp, mpls_event_types, vlan_event_types/output unified2: filename snort.u2, limit 128/' snort.conf.tmp

#remember how we added blacklist and whitelist.rules files earlier? we have to point snort to those files now.

sed -i 's/var WHITE_LIST_PATH ..\/rules/var WHITE_LIST_PATH \/usr\/local\/snort\/rules/' snort.conf.tmp

sed -i 's/var BLACK_LIST_PATH ..\/rules/var BLACK_LIST_PATH \/usr\/local\/snort\/rules/' snort.conf.tmp

cp snort.conf.tmp /usr/local/snort/etc/snort.conf
#we clean up after ourselves...
rm snort.conf.tmp

#now we have to download barnyard 2 and configure all of its stuff.

echo "downloading, making and compiling barnyard2."
sleep 2

wget https://nodeload.github.com/firnsy/barnyard2/tarball/master -O barnyard2-2.10.tar.gz

tar -xzvf barnyard2-2.10.tar.gz

cd firnsy-barnyard2*

autoreconf -fvi -I ./m4

#remember when we asked the user if they are 32 or 64-bit? Well we saved that answer and use it to help find where the mysql libs are on the system, instead of having to ask them again.

case $arch in
                1)
                echo "preparing configure statement to point to 32-bit libraries."
./configure --with-mysql --with-mysql-libraries=/usr/lib/i386-linux-gnu

sleep 2
                ;;
                2)
                echo "preparing configure statement to point to 64-bit libraries"
./configure --with-mysql --with-mysql-libraries=/usr/lib/x86_64-linux-gnu

sleep 2
                ;;
                *)
                echo "unable to determine architecture from your answer. The configure statement for barnyard needs to know where to find mysql libraries (--with-mysql-libraries=/my/mysqllib/path)"
		exit 1
                ;;
esac

make && make install

echo "configuring supporting infrastructure for barnyard (file ownership to snort user/group, file permissions, waldo file, etc.)"
sleep 2

#the statements below copy the barnyard2.conf file where we want it and establish proper rights to various barnyard2 files and directories.

cp etc/barnyard2.conf /usr/local/snort/etc
mkdir /var/log/barnyard2
chmod 666 /var/log/barnyard2
touch /var/log/snort/barnyard2.waldo
chown snort.snort /var/log/snort/barnyard2.waldo

echo "building mysql infrastructure"
sleep 2

#we ask the user for a password for snort report earlier. here's where we build the mysql database and give rights to the snort user to manage the database.

echo "the next several steps will need you to enter the mysql root user passwordmore than once."

sleep 4
echo "enter the mysql root user password to create the snort database."
mysql -u root -p -e "create database snort;"
echo "enter the mysql root user password again to create the snort database schema"
mysql -u root -p -D snort < ./schemas/create_mysql

#we warn the user that the snort user's password, created earlier when configuring snort report will be used to access data from the database for the web ui. we show them the password again for a few seconds, and clear the screen.

clear

echo "the password chosen for the snort user earlier ($mysql_pass) will be used to give snort report the ability to read data from the database. record this password for safekeeping!"

sleep 6

clear

echo "you'll need to enter the mysql root user password one more time to create the snort database user and grant it permissions to the snort database."

#just as stated above, the snort user's mysql password (dumped into srconf earlier) is set here. We remind the user that we set this password earlier and create the snort database user with rights to modify all this stuff.

mysql -u root -p -e "grant create, insert, select, delete, update on snort.* to snort@localhost identified by '$mysql_pass';"

#now we modify the barnyard2 conf file, same way we set up the snort.conf file -- make a temp copy in root's home, sed-foo it, then replace it. Voila!

echo "building barnyard2.conf, point to reference.conf, classication.conf, gen-msg and sid-msg maps, as well as use the local mysql database, snort database, and snort user."

sleep 2

cd /root

cp /usr/local/snort/etc/barnyard2.conf barnyard2.conf.tmp

sed -i 's/config reference_file:      \/etc\/snort\/reference.config/config reference_file:      \/usr\/local\/snort\/etc\/reference.config/' barnyard2.conf.tmp

sed -i 's/config classification_file: \/etc\/snort\/classification.config/config classification_file: \/usr\/local\/snort\/etc\/classification.config/' barnyard2.conf.tmp

sed -i 's/config gen_file:            \/etc\/snort\/gen-msg.map/config gen_file:            \/usr\/local\/snort\/etc\/gen-msg.map/' barnyard2.conf.tmp

sed -i 's/config sid_file:            \/etc\/snort\/sid-msg.map/config sid_file:             \/usr\/local\/snort\/etc\/sid-msg.map/' barnyard2.conf.tmp 

sed -i 's/#config hostname:   thor/config hostname: localhost/' barnyard2.conf.tmp

echo "What interface is going to be your \"management\" interface? (e.g. what interface will be used to interact with a management workstation? This will be barnyard 2's config interface.)"

read mgmt_interface

sed -i 's/#config interface:  eth0/config interface: '$mgmt_interface'/' barnyard2.conf.tmp

sed -i 's/#   output database: log, mysql, user=root password=test dbname=db host=localhost/output database: log, mysql user=snort password='$mysql_pass' dbname=snort host=localhost/' barnyard2.conf.tmp

cp barnyard2.conf.tmp /usr/local/snort/etc/barnyard2.conf

#cleaning up the temp file again

rm barnyard2.conf.tmp

echo "what interface will snort be listening on? (choose one interface, please make it a separate interface from the management interface ($mgmt_interface)"

read snort_iface

echo "Would you like to have this interface configured to be up at boot? (useful if you want snort to run on startup.)"
echo "Select 1 for yes, or 2 for no"
#this choice determines whether we'll be hacking /etc/network/interfaces to have the interface started at boot.
read boot_iface 

case $boot_iface in
                1)
                echo "appending to /etc/network/interfaces"
		cp /etc/network/interfaces /root/interfaces.tmp
		echo "#appending $snort_iface to start at boot to run snort on boot on $snort_iface." >> /root/interfaces.tmp
		echo "auto $snort_iface" >> /root/interfaces.tmp
		echo "iface $snort_iface inet promisc manual" >> /root/interfaces.tmp
		echo "up ifconfig $snort_iface up" >> /root/interfaces.tmp
		cp /root/interfaces.tmp /etc/network/interfaces
		rm /root/interfaces.tmp
                ;;
                2)
                echo "okay then, I'll let you do things on your own."
                ;;
                *)
		echo "I didn't understand your answer, so I'll tell you what to do: if you want snort to run on an interface that is not a bridge interface, the interface needs to be up. To have this done automatically at boot time, you have to modify /etc/network/interfaces and input the following:
auto [iface name]
iface [iface name] inet manual
up ifconcig [iface name] up. For bridge interfaces.... well, they aren't supported by this script... yet."
                ;;
esac

echo "Almost there! Do you want snort and barnyard to run at startup? 1 for yes, 2 for no."
read startup_choice

case $startup_choice in
			1)
			echo "adding snort and barnyard2 to rc.local"
			cp /etc/rc.local /root/rc.local.tmp
			sed -i 's/exit 0/ /' /root/rc.local.tmp
			echo "#start snort as user/group snort, Daemonize it, read snort.conf and run against $snort_iface" >> /root/rc.local.tmp
			echo "/usr/local/snort/bin/snort -D -u snort -g snort -c /usr/local/snort/etc/snort.conf -i $snort_iface" >> /root/rc.local.tmp
			echo "/usr/local/bin/barnyard2 -c /usr/local/snort/etc/barnyard2.conf -G /usr/local/snort/etc/gen-msg.map -S /usr/local/snort/etc/sid-msg.map -d /var/log/snort -f snort.u2 -w /var/log/snort/barnyard2.waldo -D" >> /root/rc.local.tmp
			echo "exit 0" >> /root/rc.local.tmp
			cp /root/rc.local.tmp /etc/rc.local
			rm /root/rc.local.tmp
			;;
			2)
			echo "okay then."
			;;
			*)
			echo "I didn't understand your choice. If you want snort and barnyard 2 to run at boot, add them to /etc/rc.local"
			;;
esac

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
