#!/bin/bash
#####################################################################################################################################
#####################################################################################################################################
# Autosnort offline installer. This is considered "Stage 2". The "Stage 1" script,ran on a system with internet access downloads the#
# the required packages for a full offline install. This should be a given, but offline and online distro,  arch (x86/x64) and ver. #
# absolutely must match. Be forewarned, this script is stripped down. If you run into problems, report them!                        #
# twitter: @da_667                                                                                                                  #
# email: deusexmachina667@gmail.com                                                                                                 #
# Shouts to UAS and Forgottensec. I'm never there, but I'm always there.                                                            #
#####################################################################################################################################
#####################################################################################################################################

# determine arch
arch=`uname -a | cut -d " " -f12`
# Determine OS. not the cleanest method, but will do for now.
OS=`cat /etc/issue.net | cut -d " " -f1`

# First things first, we need the stage 1 installer tarball. This tarball has all of the packages .deb and .tar.gz needed for us to
# get this pig to fly. We ask the user where the autosnort offline tarfile is located, test to make sure it exists, then make sure
# tar unpacked it without errors. If the user gives us a filename that doesn't exist, or tar was unable to unpack it, then we inform
# the user and tell them to review the tar output to figure out what went wrong. This portion of the script runs until the installer
# tarball is successfully unpacked.



while true; do
	read -p "Please enter the directory where the installer tarball is located (no trailing slashes!) " installer_dir
    read -p "Please enter the name of the tarball (usually AS_offline_$OS$arch.tar.gz) " installer_filename
    test -e $installer_dir/$installer_filename
    if [ $? = 0 ]; then
        echo "tarball found"
        tar -xzvf $installer_dir/$installer_filename
		if [ $? != 0 ]; then
			echo "Tar reported errors extracting the tarball. Please review the output above. Usually this is because the file is corrupt, or the filename specified does not exist in the directory you specified. Please try again."
			echo ""
			continue
		else
			echo "untar successful"
			cd $installer_dir
			echo ""
			break;
		fi
                    
    else
		echo "that file doesn't exist. try again."
    fi
done

# At this point, the entire tarball should be exploded out, and we should be in the directory were the tarball was blown up. We CD into
# AS_offline_$OS$arch/apt_pkgs/archives/ and use the dpkgorder.txt and a for loop to install ALL the packages in the CORRECT order;
# The packages MUST be installed in a certain order for everything to work properly. afterwards, we go into the sources directory and
# start inflating the source tarballs and installing everything. the order here doesn't generally matter, I don't think. special note:
# two libraries libdnet and libsfbpf need symlinks from usr/local/lib to /usr/lib otherwise snort will crash and burn on ubuntu operating systems.

# this may take a little bit of time. You'll be prompted for a mysql root username here. also, you'll probably see errors for g++ when it installs.
# don't worry about the errors.
# this is a while/read/do loop instead of the average for/cat/do loop. This is to get around some package weirdness with Debian.

cd AS_offline_$OS$arch/apt_pkgs/archives
while read packages; do dpkg -i $packages; done < dpkgorder$OS$arch.txt


cd ../../sources

#first up, jpgraph.
mkdir /var/www/jpgraph
tar -xzvf jpgraph-1.27.1.tar.gz
cp -r jpgraph-1.27.1/src /var/www/jpgraph

#second up, snort report.
tar -xzvf snortreport-1.3.3.tar.gz -C /var/www/
mv /var/www/snortreport-1.3.3 /var/www/snortreport

# srconf.php holds the database name, database username and password required to present alerts to the web UI. Its important that, either via the
# script or by hand that you specify these items correctly if you want intrusion events on the web UI.

echo "You will need to Enter the mysql database password for the database user \"snort\" (we have not created the regular snort user or snort database user yet, we will be doing so shortly) in the file /var/www/snortreport-1.3.3/srconf.php on the line \"\$pass = \"YOURPASS\";"
echo "I will give you the choice of doing this yourself, or having me do it for you."
echo ""

# adding a bit of fault tolerance here by dropping this entire section into a while true loop.
# this entire section gives the user a choice to modify srconf.php, a key file for snort report configuration manually or have the script do it via a 
# password that they supply and we confirm before modifying the file via sed-foo.

while true; do
	read -p "
Select 1 for autosnort to configure a password you supply for the snort database user, the user that will be used to display alerts on the snort report web UI. 
Select 2 if you wish to perform this task manually (Note: this means that the snort mysql user will NOT have a password - you will need to add a password for the snort database user manually as well!)
" srconf_choice

	case $srconf_choice in
		1 )
        echo "I need the password, please."
		read -s -p "Please enter the snort database user password:" mysql_pass_1
		echo ""
		read -s -p "Confirm:" mysql_pass_2
		echo ""
		if [ "$mysql_pass_1" == "$mysql_pass_2" ]; then
			echo "password confirmed."
			echo "modifying srconf.php..."
			cp /var/www/snortreport/srconf.php /root/srconf.php.tmp
			sed -i 's/YOURPASS/'$mysql_pass_1'/' /root/srconf.php.tmp
			cp /root/srconf.php.tmp /var/www/snortreport/srconf.php
			rm /root/srconf.php.tmp
			echo "password insertion complete."
			echo ""
			break
		else
			echo ""
			echo -e "Passwords do not match. Please try again."
			continue
		fi
			
		;;
        2 )
        echo "Very Well. Moving on."
		echo ""
		break
        ;; 
		* )
		echo "Invalid choice. Please try again."
		;;
	esac
done

#Doing an OS check here. The next bit of code is Debian-specific.

if [ $OS = "Debian" ]; then

# known problem with snort report 1.3.3 not playing nice on systems that have the short_open_tag directive in php.ini set to off. Give the user a choice if they want the script 
# to automatically resolve this, or if they plan on adding in proper php open tags on their own.

	echo ""
	echo "Would you like me to to set the short_open_tag directive in php.ini to on for snort report?"
	echo "Please see http://autosnort.blogspot.com/2012/11/how-to-fix-problems-with-snort-report.html as to why this is important"
	echo ""
	while true; do
		read -p "
Select 1 for autosnort to enable short_open_tag
Select 2 to continue if you plan on reconfiguring the php scripts with short open tags manually
" srecon
		case $srecon in
			1 )
			echo "Reconfiguring php.ini..."
			echo ""
			sed -i 's/short\_open\_tag \= Off/short\_open\_tag \= On/' /etc/php5/apache2/php.ini
			echo ""
			echo "We're all done here."
			break
			;;
			2 )
			echo ""
			echo "Right then, moving on."
			break
			;;
			* )
			echo ""
			echo "Invalid choice. Select 1 or 2 as your options, please."
			;;
		esac
	done
else
	echo "Not Debian. Continuing."
	echo ""
fi

# next up, data acquisition library (DAQ)
tar -xzvf daq-*.tar.gz
cd daq-*
./configure && make && make install
cd ..

# libdnet. another required library for snort.
tar -xzvf libdnet-1.12.tgz
cd libdnet-1.12
./configure && make && make install
cd ..

# as part of snort install:
# need to symlink these two libraries on ubuntu. snort doesn't know where to find them by default. at least on ubuntu.
ln -s /usr/local/lib/libdnet.1.0.1 /usr/lib/libdnet.1
ln -s /usr/local/lib/libsfbpf.so.0 /usr/lib/libsfbpf.so.0

# now, for the pig itself
tar -xzvf snort-*.tar.gz
cd snort-*
./configure --prefix=/usr/local/snort --enable-sourcefire && make && make install

#supporting infrastructure for snort.

echo "creating directories /var/log/snort, and /var/snort."

mkdir /var/snort && mkdir /var/log/snort

echo "creating snort user and group, assigning ownership of /var/log/snort to snort user and group. \n"

#users and groups for snort to run non-priveledged. snort's login shell is set to /bin/false to enforce the fact that this is a service account.

groupadd snort
useradd -g snort snort -s /bin/false
chown snort:snort /var/log/snort

#this part of the script needs a snort rules tarball to work properly. it works similarly to part of the script used to unpack the stage 1 tarball.

while true; do
	read -p "Please enter the directory where the snort rule tarball is located (no trailing slashes!) " rule_dir
    read -p "Please enter the name of the tarball (usually snortrules-snapshot-snortver.tar.gz) " rule_filename
    test -e $rule_dir/$rule_filename
    if [ $? = 0 ]; then
        echo "tarball found"
        tar -xzvf $rule_dir/$rule_filename -C /usr/local/snort > /dev/null 2>&1
		if [ $? != 0 ]; then
			echo "Tar reported errors extracting the tarball. Please review the output above. Usually this is because the file is corrupt, or the filename specified does not exist in the directory you specified. Please try again."
			echo ""
			continue
		else
			echo "untar successful"
			echo ""
			break;
		fi
                    
    else
		echo "that file doesn't exist. try again."
    fi
done

# Use the $OS and $arch variables to determine what SO rules to copy for use with the snort installation. 
# If we can't determine arch/os combination, we default to not installing the SO rules at all. Also grabs a copy of snort.conf for some sed-foo modifications.

mkdir /usr/local/snort/lib/snort_dynamicrules
if [ $arch = "x86_64" ] && [ $OS = "Debian" ]; then
	echo "copying $OS 64-bit SO rules."
	cp /usr/local/snort/so_rules/precompiled/Debian-6-0/x86-64/2.9.*/* /usr/local/snort/lib/snort_dynamicrules
elif [ $arch = "i686" ] && [ $OS = "Debian" ]; then
	echo "copying $OS 32-bit SO rules."
	cp /usr/local/snort/so_rules/precompiled/Debian-6-0/i386/2.9.*/* /usr/local/snort/lib/snort_dynamicrules
elif [ $arch = "x86_64" ] && [ $OS = "Ubuntu" ]; then
    echo "copying $OS 64-bit SO rules."
    cp /usr/local/snort/so_rules/precompiled/Ubuntu-12-04/x86-64/2.9.*/* /usr/local/snort/lib/snort_dynamicrules
elif [ $arch = "i686" ] && [ $OS = "Ubuntu" ]; then
    echo "copying $OS 32-bit SO rules."
    cp /usr/local/snort/so_rules/precompiled/Ubuntu-12-04/i386/2.9.*/* /usr/local/snort/lib/snort_dynamicrules
else
    echo "cannot determine arch. not copying SO rules."
fi
cp /usr/local/snort/etc/snort.conf /root/snort.conf.tmp

cd /root


touch /usr/local/snort/rules/white_list.rules && touch /usr/local/snort/rules/black_list.rules && ldconfig

echo "Modifying snort.conf -- specifying unified 2 output, SO whitelist/blacklist and standard rule locations."

#here we take the copy of snort.conf.tmp, perform some sed-foo on the file, then copy it back to /usr/local/snort/etc.


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

#barnyard 2 installation time. From this point on, the script is mostly the same as an online autosnort install.

cd $installer_dir/AS_offline_$OS$arch/sources

tar -xzvf barnyard2.tar.gz

cd barnyard2*

# remember when we checked if the user is 32 or 64-bit? Well we saved that answer and use it to help find where the mysql libs are on the system.
# also going to do a quick OS check here. this allows me to re-use 99% of the code for AS-offline for ubuntu for debian as well.

if [ $OS = "Debian" ]; then

# this is really just about the only difference between Ubuntu and debian builds. Debian drops the mysql libs in /usr/lib. Ubuntu has to be fancy
# about it.

	./configure --with-mysql && make && make install
	
else

	case $arch in
		i686)
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
fi

make && make install

#the statements below copy the barnyard2.conf file where we want it and establish proper rights to various barnyard2 files and directories.

cp etc/barnyard2.conf /usr/local/snort/etc
mkdir /var/log/barnyard2
chmod 666 /var/log/barnyard2
touch /var/log/snort/barnyard2.waldo
chown snort.snort /var/log/snort/barnyard2.waldo

echo "building mysql infrastructure"

#we ask the user for a password for snort report earlier. here's where we build the mysql database and give rights to the snort user to manage the database. all of these are now encapsulated in while true loops for better fault tolerance.

echo "the next several steps will need you to enter the mysql root user password more than once."
echo ""
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
while true; do
	echo "enter the mysql root user password again to create the snort database schema"
	mysql -u root -p -D snort < schemas/create_mysql
	if [ $? != 0 ]; then
		echo "the command did NOT complete successfully. (bad password?) Please try again."
		continue
	else
		echo "snort database schema created!"
		break
	fi
done
while true; do
	echo "you'll need to enter the mysql root user password one more time to create the snort database user and grant it permissions to the snort database."
	#the snort user's mysql password (dumped into srconf earlier) is set here. the password isn't set if the user didn't modify srconf.php the snort database user will have no password - we warn the user about this now.
	#Create the snort database user with rights to modify all this stuff.

	mysql -u root -p -e "grant create, insert, select, delete, update on snort.* to snort@localhost identified by '$mysql_pass_1';"
	if [ $? != 0 ]; then
		echo "the command did NOT complete successfully. (bad password?) Please try again."
		continue
	else
		echo "snort database schema created!"
		break
	fi
done

#now we modify the barnyard2 conf file, same way we set up the snort.conf file -- make a temp copy in root's home, sed-foo it, then replace it. Voila!

echo "building barnyard2.conf, pointing to reference.conf, classication.conf, gen-msg and sid-msg maps, as well as use the local mysql database, snort database, and snort user."



cp etc/barnyard2.conf /root/barnyard2.conf.tmp

sed -i 's/config reference_file:      \/etc\/snort\/reference.config/config reference_file:      \/usr\/local\/snort\/etc\/reference.config/' /root/barnyard2.conf.tmp

sed -i 's/config classification_file: \/etc\/snort\/classification.config/config classification_file: \/usr\/local\/snort\/etc\/classification.config/' /root/barnyard2.conf.tmp

sed -i 's/config gen_file:            \/etc\/snort\/gen-msg.map/config gen_file:            \/usr\/local\/snort\/etc\/gen-msg.map/' /root/barnyard2.conf.tmp
sed -i 's/config sid_file:            \/etc\/snort\/sid-msg.map/config sid_file:             \/usr\/local\/snort\/etc\/sid-msg.map/' /root/barnyard2.conf.tmp

sed -i 's/#config hostname:   thor/config hostname: localhost/' /root/barnyard2.conf.tmp

cp /root/barnyard2.conf.tmp /usr/local/snort/etc/barnyard2.conf

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

sed -i 's/#config interface:  eth0/config interface: '$snort_iface'/' /root/barnyard2.conf.tmp

sed -i 's/#   output database: log, mysql, user=root password=test dbname=db host=localhost/output database: log, mysql user=snort password='$mysql_pass_1' dbname=snort host=localhost/' /root/barnyard2.conf.tmp

cp /root/barnyard2.conf.tmp /usr/local/snort/etc/barnyard2.conf

#cleaning up the temp file
rm /root/barnyard2.conf.tmp

#The choice above determines whether or not we'll be adding an entry to /etc/sysconfig/network-scripts  for the snort interface and adding the rc.local hack to bring snort's sniffing interface up at boot. We also run ethtool to disable checksum offloading and other nice things modern NICs like to do; per the snort manual, leaving these things enabled causes problems with rules not firing properly. We give the user the choice of not doing this, in the case that they may not have two dedicated network interfaces available.

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
We're almost finished! Do you want snort and barnyard to run at startup?
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

#create an updated sid-msg.map with all snort rules in it.

perl $installer_dir/AS_offline_$OS$arch/sources/create-sidmap.pl /usr/local/snort/rules/ /usr/local/snort/so_rules > /usr/local/snort/etc/sid-msg.map

echo "NOTE: the password chosen for the snort user earlier ($mysql_pass_1) will be used to give snort report the ability to read data from the database. record this password for safekeeping!"

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

#bugs: sed isn't replacing the proper lines out of barnyard2.conf. the command arguments are actually handling this.

