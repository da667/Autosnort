#!/bin/bash
#Snorby shell script 'module'
#Sets up sguil for Autosnort

########################################
#logging setup: Stack Exchange made this.

sguil_logfile=/var/log/sguil_install.log
mkfifo ${sguil_logfile}.pipe
tee < ${sguil_logfile}.pipe $sguil_logfile &
exec &> ${sguil_logfile}.pipe
rm ${sguil_logfile}.pipe

########################################
#Metasploit-like print statements: status, good, bad and notification. Gratouitiously ganked from Darkoperator's metasploit install script.

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
#directory checking function. if the directory doesn't exist, it creates it.
function dir_check()
{

if [ ! -d $1 ]; then
	print_notification "$1 does not exist. Creating.."
	mkdir -p $1
else
	print_notification "$1 already exists. (No problem, We'll use it anyhow)"
fi

}

########################################
#Error Checking function. Checks for exist status of last command ran. If non-zero assumes something went wrong and bails script.

function error_check
{

if [ $? -eq 0 ]; then
	print_good "$1 successfully completed."
else
	print_error "$1 failed. Please check $sguil_logfile for more details, or contact deusexmachina667 at gmail dot com for more assistance."
exit 1
fi

}

########################################
#The config file should be in the same directory that snorby script is exec'd from. This shouldn't fail, but if it does..

execdir=`pwd`
if [ ! -f "$execdir"/full_autosnort.conf ]; then
	print_error "full_autosnort.conf was NOT found in $execdir. This script relies HEAVILY on this config file. The main autosnort script, full_autosnort.conf and this file should be located in the SAME directory."
	exit 1
else
	source "$execdir"/full_autosnort.conf
	print_good "Found config file."
fi

########################################
#sguil requires that TCL be compiled WITHOUT threading support. You don't want to know how I feel about this.
#also, due to strange bugs in tcltls, and inability of upstream to update their packages in a timely manner to resolve bugs in openssl, /that/ needs to be compiled from source too. For now.
#oh, and we have to recompile barnyard2. to have tcl support. with the non-threaded tcl package we just made.

print_status "Installing Sguil/TCL pre-reqs.."
apt-get install -y tcllib tclx mysqltcl dpkg-dev devscripts libssl-dev &>> $sguil_logfile
cd /usr/src
apt-get -y source tcl8.5-dev &>> $sguil_logfile
apt-get -y build-dep tcl8.5-dev &>> $sguil_logfile
print_status "Building TCL 8.5 source package (without threading)"
cd tcl8.5-*
sed -i '/--enable-threads \\/d' debian/rules &>> $sguil_logfile
debuild -us -uc &>> $sguil_logfile
error_check 'Build of TCL deb package'
cd /usr/src
print_status "Installing TCL 8.5.."
dpkg -i libtcl8.5_*_amd64.deb  tcl8.5_*_amd64.deb tcl8.5-dev_*_amd64.deb &>> $sguil_logfile
error_check 'Install of TCL 8.5'

#these are clean-up items to make sure the system uses are doctored TCL interpreter.
rm -rf /usr/bin/tclsh
ln -s /usr/bin/tclsh8.5 /usr/bin/tclsh
#this is a cleanup item to ensure the system does NOT update our tcl packages
apt-mark hold libtcl8.5 tcl8.5 tcl8.5-dev &>> $sguil_logfile
print_notification "Please note that the packages tcl8.5 tcl8.5-dev and libtcl8.5 have been marked as held back. Otherwise, when the system tries to update them, the version with threading support will be installed over the version sguil requires (without threading)."

print_status "Downloading and compiling tcltls.."
cd /usr/src
wget http://sourceforge.net/projects/tls/files/latest/download?source=files -O tcltls.tar.gz &>> $sguil_logfile
error_check 'download of tcltls source'
tar -xzvf tcltls.tar.gz &>> $sguil_logfile
cd tls*
./configure --with-tcl=/usr/lib/tcl8.5 &>> $sguil_logfile
error_check 'tcltls configure'
make &>> $sguil_logfile
error_check 'tcltls make'
make install &>> $sguil_logfile
error_check 'tcltls installation'

print_status "Recompiling Barnyard2, this time with TCL support.."
mysqllibloc=`find /usr/lib -name libmysqlclient.so`
cd /usr/src/barnyard2*
make clean &>> $sguil_logfile
error_check 'Make clean of Barnyard2'
./configure --with-mysql --with-mysql-libraries=`dirname $mysqllibloc` --with-tcl=/usr/lib/tcl8.5 &>> $sguil_logfile
error_check 'Configure of Barnyard2'
make &>> $sguil_logfile
error_check 'Make of Barnyard2'
make install &>> $sguil_logfile
error_check 'Installation of Barnyard2'

########################################
#Download sguil, prepare the database, then create a sguil user to drive sguild privs to.

cd /opt

#If the sguil directory exists, delete it. It causes more problems than it resolves, and usually only exists if the install failed in some way. Wipe it away, start with a clean slate.
if [ -d /opt/sguil ]; then
	print_notification "Sguil directory exists. Deleting to prevent issues.."
	rm -rf /opt/sguil
fi

git clone https://github.com/bammv/sguil.git &>> $sguil_logfile

mysql -uroot -p$root_mysql_pass -e "drop database if exists sguil; create database if not exists sguil; show databases;" &>> $sguil_logfile
mysql -uroot -p$root_mysql_pass -e "grant all privileges on sguil.* to snort@localhost identified by '$snort_mysql_pass';" &>> $sguil_logfile
mysql -uroot -p$snort_mysql_pass -D sguil < /opt/sguil/server/sql_scripts/create_sguildb.sql &>> $sguil_logfile
mysql -uroot -p$snort_mysql_pass -D sguil < /opt/sguil/server/create_ruledb.sql &>> $sguil_logfile

print_status "Checking for snort user and group.."

getent passwd sguil &>> $sguil_logfile
if [ $? -eq 0 ]; then
	print_notificiation "sguil user exists. Verifying group exists.."
	id -g sguil &>> $sguil_logfile
	if [ $? -eq 0 ]; then
		print_notification "sguil group exists."
	else
		print_noficiation "sguil group does not exist. Creating.."
		groupadd sguil &>> $sguil_logfile
		usermod -G sguil sguil &>> $sguil_logfile
	fi
else
	print_status "Creating sguil user and group.."
	groupadd sguil &>> $sguil_logfile
	useradd -g sguil sguil -s /bin/false &>> $sguil_logfile	
fi

print_status "Tightening permissions to /opt/sguil.."
chown -R sguil:sguil /opt/sguil
cd /opt/sguil

########################################
#creating a skeleton sguild.conf

print_status "creating sguild.conf.."

mv /opt/sguil/server/sguild.conf /opt/sguil/server/sguild.conf.orig
echo "#sguild.conf skeleton - generated by autosguil-ubuntu" > /opt/sguil/server/sguild.conf
echo "#need a description of these options? see /opt/sguil/server/sguild.conf.orig" >> /opt/sguil/server/sguild.conf 
echo "set USER sguil" >> /opt/sguil/server/sguild.conf 
echo "set GROUP sguil" >> /opt/sguil/server/sguild.conf 
echo "set SGUILD_LIB_PATH /opt/sguil/server/lib" >> /opt/sguil/server/sguild.conf 
echo "set DEBUG 2" >> /opt/sguil/server/sguild.conf 
echo "set DAEMON 1" >> /opt/sguil/server/sguild.conf 
echo "set SYSLOGFACILITY daemon" >> /opt/sguil/server/sguild.conf 
echo "set SENSOR_AGGREGATION_ON 1" >> /opt/sguil/server/sguild.conf 
echo "set SERVERPORT 7734" >> /opt/sguil/server/sguild.conf 
echo "set SENSORPORT 7736" >> /opt/sguil/server/sguild.conf 
echo "set RULESDIR /opt/sguil" >> /opt/sguil/server/sguild.conf 
echo "set TMPDATADIR /tmp" >> /opt/sguil/server/sguild.conf 
echo "set DBNAME sguil" >> /opt/sguil/server/sguild.conf 
echo "set DBPASS $snort_mysql_pass" >> /opt/sguil/server/sguild.conf 
echo "set DBHOST localhost" >> /opt/sguil/server/sguild.conf 
echo "set DBPORT 3306" >> /opt/sguil/server/sguild.conf 
echo "set DBUSER snort" >> /opt/sguil/server/sguild.conf 
echo "set LOCAL_LOG_DIR /opt/sguil/server/archive" >> /opt/sguil/server/sguild.conf 
echo "set TMP_LOAD_DIR /opt/sguil/server/load" >> /opt/sguil/server/sguild.conf 
echo "set P0F 0" >> /opt/sguil/server/sguild.conf 
chmod 700 /opt/sguil/server/sguild.conf
error_check 'creation of sguild.conf'

#creating a symlink from $snort_basedir/rules to /opt/sguil/<hostname> and supporting directories listed above.
ln -s $snort_basedir/rules /opt/sguil/`hostname`
dir_check /opt/sguil/server/archive 
dir_check /opt/sguil/server/load

########################################
#creating a skeleton snort_agent.conf
mv /opt/sguil/sensor/snort_agent.conf /opt/sguil/sensor/snort_agent.conf.orig
echo "#snort_agent.conf skeleton - generated by autosguil-ubuntu" > /opt/sguil/sensor/snort_agent.conf
echo "#need a description of these options? see /opt/sguil/sensor/snort_agent.conf.orig" >> /opt/sguil/sensor/snort_agent.conf
echo "set DEBUG 1" >> /opt/sguil/sensor/snort_agent.conf
echo "set DAEMON 1" >> /opt/sguil/sensor/snort_agent.conf
echo "set SERVER_HOST localhost" >> /opt/sguil/sensor/snort_agent.conf
echo "set SERVER_PORT 7736" >> /opt/sguil/sensor/snort_agent.conf
echo "set BY_PORT 7735" >> /opt/sguil/sensor/snort_agent.conf
echo "set HOSTNAME `hostname`" >> /opt/sguil/sensor/snort_agent.conf
echo "set NET_GROUP Ext_Net" >> /opt/sguil/sensor/snort_agent.conf
echo "set LOG_DIR /opt/sguil/sensor/logs" >> /opt/sguil/sensor/snort_agent.conf
echo "set PORTSCAN 0" >> /opt/sguil/sensor/snort_agent.conf
echo "set PORTSCAN_DIR ${LOG_DIR}/portscans" >> /opt/sguil/sensor/snort_agent.conf
echo "set SNORT_PERF_STATS 0" >> /opt/sguil/sensor/snort_agent.conf
echo "set SNORT_PERF_FILE ${LOG_DIR}/perfstats/snort.stats" >> /opt/sguil/sensor/snort_agent.conf
echo "set WATCH_DIR \${LOG_DIR}" >> /opt/sguil/sensor/snort_agent.conf
echo "set PS_CHECK_DELAY_IN_MSECS 10000" >> /opt/sguil/sensor/snort_agent.conf
echo "set DISK_CHECK_DELAY_IN_MSECS 1800000" >> /opt/sguil/sensor/snort_agent.conf
echo "set PING_DELAY 300000" >> /opt/sguil/sensor/snort_agent.conf
chmod 700 /opt/sguil/sensor/snort_agent.conf
error_check 'creation of snort_agent.conf'

dir_check /opt/sguil/sensor/logs/portscans 
dir_check /opt/sguil/sensor/logs/perfstats/
touch /opt/sguil/sensor/logs/perfstats/snort.stats

########################################
#ssl configuration
dir_check /opt/sguil/ssl
chmod 700 /opt/sguil/ssl
cd /opt/sguil/ssl

openssl req -x509 -newkey rsa:4096 -days 365 -nodes -subj "/C=US/ST=Nevada/L=LasVegas/O=Security/CN=`hostname`" -keyout sguild.pem -out sguild.pem &>> $sguil_logfile
ln -s /opt/sguil/ssl/sguild.pem /opt/sguil/ssl/sguild.key
chmod 600 /opt/sguil/ssl/sguild.pem
#final preparations. ensure that the sguil user has permissions to access the data in /opt/sguil and reconfigure Barnyard2 to output to our sguil sensor.
#Also: /var/log/sguild and the files agent.log and user.log have to exist and be accessible by sguild. Wish I would've known that sooner.

print_status "Tightening permissions to /opt/sguil.."
chown -R sguil:sguil /opt/sguil

dir_check /var/log/sguild
touch /var/log/sguild/agent.log
touch /var/log/sguild/user.log
chown -R sguil:sguil /var/log/sguild
sed -i 's#output database.*#output sguil: agent_port=7735#' $snort_basedir/etc/barnyard2.conf

#Installing persistence
cd "$execdir"
if [ -f /etc/init.d/initsguil ]; then
	print_notification "Snortbarn init script already installed."
else
	if [ ! -f "$execdir"/initsguil ]; then
		print_error" Unable to find $execdir/initsguil. Please ensure the initsguil file is there and try again."
		exit 1
	else
		print_good "Found initsguil init script."
	fi
	
	cp initsguil /etc/init.d/initsguil &>> $sguil_logfile
	chown root:root /etc/init.d/initsguil &>> $sguil_logfile
	chmod 700 /etc/init.d/initsguil &>> $sguil_logfile
	update-rc.d initsguil defaults &>> $sguil_logfile
	error_check 'Sguil init script installation'
	print_notification "Init script located in /etc/init.d/initsguil"
fi