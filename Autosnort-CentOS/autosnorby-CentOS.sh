#!/bin/bash
#Snorby shell script 'module'
#Sets up snorby for Autosnort

########################################
#logging setup: Stack Exchange made this.

snorby_logfile=/var/log/snorby_install.log
mkfifo ${snorby_logfile}.pipe
tee < ${snorby_logfile}.pipe $snorby_logfile &
exec &> ${snorby_logfile}.pipe
rm ${snorby_logfile}.pipe

########################################
#Metasploit-like print statements: status, good, bad and notification. Gratuitously ganked from Darkoperator's metasploit install script.

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
#Error Checking function. Checks for exist status of last command ran. If non-zero assumes something went wrong and bails script.

function error_check
{

if [ $? -eq 0 ]; then
	print_good "$1 successfully completed."
else
	print_error "$1 failed. Please check $snorby_logfile for more details, or contact deusexmachina667 at gmail dot com for more assistance."
exit 1
fi

}

########################################
#Pre-setup. First, if the Snorby directory exists, delete it. It causes more problems than it resolves, and usually only exists if the install failed in some way. Wipe it away, start with a clean slate.
if [ -d /var/www/html/snorby ]; then
	print_notification "Snorby directory exists. Deleting to prevent issues.."
	rm -rf /var/www/html/snorby
fi

#The config file should be in the same directory that snorby script is exec'd from. This shouldn't fail, but if it does..

execdir=`pwd`
if [ ! -f $execdir/full_autosnort.conf ]; then
	print_error "full_autosnort.conf was NOT found in $execdir. This script relies HEAVILY on this config file. The main autosnort script, full_autosnort.conf and this file should be located in the SAME directory to ensure success."
	exit 1
else
	source $execdir/full_autosnort.conf
	print_good "Found config file."
fi

#Grabbing requirements to run Snorby.

print_status "Acquiring packages for Snorby (this may take a little while).."
yum -y install libyaml-devel openssl-devel git-core libxslt-devel sqlite-devel mysql++-devel httpd-devel curl-devel jre &>> $snorby_logfile
error_check 'Package installation'

########################################
#RVM is the ruby version manager. A script that finds the pre-reqs required to build and install ruby.

print_status "Acquiring RVM.."

wget https://get.rvm.io -O rvm_stable.sh &>> $snorby_logfile
error_check 'Download of RVM'

bash rvm_stable.sh &>> $snorby_logfile
error_check 'RVM installation'

print_status "Configuring RVM."

/usr/local/rvm/bin/rvm autolibs enable
source /etc/profile.d/rvm.sh

print_good "RVM configured."

########################################
#Little bit of shell magic to determine the correct version of ruby to install.

print_status "Hitting ruby-lang.org to determine the latest version of ruby 1.9.x to install.."

wget https://www.ruby-lang.org/en/downloads -O /tmp/downloads.html &>> $snorby_logfile
error_check 'Download of ruby-lang.org downloads page'

rubyver=`grep -e "ruby-1" /tmp/downloads.html | head -2 | tail -1 | cut -d"-" -f3,4 | cut -d"." -f1,2,3`
print_status "installing ruby-$rubyver (this will take a little while).."
rvm install ruby-$rubyver &>> $snorby_logfile
error_check 'Ruby installation'

########################################

print_status "Installing gems required for Snorby.."

gem install thor i18n bundler tzinfo builder memcache-client rack rack-test rack-mount rails rake rubygems-update erubis mail text-format sqlite3 daemon_controller passenger &>> $snorby_logfile

print_good "Gems installed successfully."

update_rubygems &>> $snorby_logfile

########################################

cd /var/www/html

print_status "Grabbing snorby via git.."

git clone https://github.com/Snorby/snorby.git &>> $snorby_logfile
error_check 'Snorby download'

########################################

#Now that we pulled down snorby, we have to modify the configuration files.

print_status "Configuring Snorby and pointing it to the mysql database.."

cd /var/www/html/snorby/config

cp database.yml.example database.yml #database name, user, and password
cp snorby_config.yml.example snorby_config.yml

sed -i 's#usr/local/bin#/usr/bin#' /var/www/html/snorby/config/snorby_config.yml
sed -i 's/password: "Enter Password Here" # Example: password: "s3cr3tsauce"/password:/' /var/www/html/snorby/config/database.yml
sed -i "s/password:/password: $root_mysql_pass/" /var/www/html/snorby/config/database.yml

print_good "Snorby successfully configured."

########################################

#This entire block and all the echo statements below are to install the passenger apache module, and set up snorby's virtual host. I don't know much about rails or ruby, other than passenger is considered vital to getting everything to work. This compiles passenger, adds it to apache2.conf and creates snorby's SSL vhost.

print_status "Installing mod_passenger (this will take a moment or two).."


passengerver=`ls /usr/local/rvm/gems/ruby-$rubyver/gems/ | grep passenger | cut -d"-" -f2,3`
passenger-install-apache2-module --auto &>> $snorby_logfile
error_check 'mod_passenger install'

print_status "Adding necessary passenger module and Virtual Host settings to /etc/httpd/conf/httpd.conf.."

#add to httpd.conf:

echo "# This stuff is to make Snorby work properly. mod_passenger is required for Snorby/Passenger to work." >> /etc/httpd/conf/httpd.conf
echo "LoadModule passenger_module /usr/local/rvm/gems/ruby-$rubyver/gems/passenger-$passengerver/buildout/apache2/mod_passenger.so" >> /etc/httpd/conf/httpd.conf
echo "PassengerRoot /usr/local/rvm/gems/ruby-$rubyver/gems/passenger-$passengerver" >> /etc/httpd/conf/httpd.conf
echo "PassengerDefaultRuby /usr/local/rvm/wrappers/ruby-$rubyver/ruby" >> /etc/httpd/conf/httpd.conf
echo "PassengerDefaultUser apache" >> /etc/httpd/conf/httpd.conf
echo "PassengerUser apache" >> /etc/httpd/conf/httpd.conf
echo "PassengerGroup apache" >> /etc/httpd/conf/httpd.conf
echo "" >> /etc/httpd/conf/httpd.conf
echo "<IfModule mod_ssl.c>" >> /etc/httpd/conf/httpd.conf
echo "	<VirtualHost *:443>" >> /etc/httpd/conf/httpd.conf
echo "		#SSL Settings, including support for PFS." >> /etc/httpd/conf/httpd.conf
echo "		SSLEngine on" >> /etc/httpd/conf/httpd.conf
echo "		SSLCertificateFile /etc/httpd/ssl/ids.cert" >> /etc/httpd/conf/httpd.conf
echo "		SSLCertificateKeyFile /etc/httpd/ssl/ids.key" >> /etc/httpd/conf/httpd.conf
echo "		SSLProtocol all -SSLv2 -SSLv3" >> /etc/httpd/conf/httpd.conf
echo "		SSLHonorCipherOrder on" >> /etc/httpd/conf/httpd.conf
echo "		SSLCipherSuite \"EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+aRSA+RC4 EECDH EDH+aRSA RC4 !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS\"" >> /etc/httpd/conf/httpd.conf
echo "" >> /etc/httpd/conf/httpd.conf
echo "		#Mod_Rewrite Settings. Force everything to go over SSL." >> /etc/httpd/conf/httpd.conf
echo "		RewriteEngine On" >> /etc/httpd/conf/httpd.conf
echo "		RewriteCond %{HTTPS} off" >> /etc/httpd/conf/httpd.conf
echo "		RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI}" >> /etc/httpd/conf/httpd.conf
echo "" >> /etc/httpd/conf/httpd.conf
echo "		#Now, we finally get to configuring our VHOST." >> /etc/httpd/conf/httpd.conf
echo "		ServerName snorby.localhost" >> /etc/httpd/conf/httpd.conf
echo "		DocumentRoot /var/www/html/snorby/public" >> /etc/httpd/conf/httpd.conf
echo "		<Directory /var/www/html/snorby/public>" >> /etc/httpd/conf/httpd.conf
echo "          # This relaxes Apache security settings." >> /etc/httpd/conf/httpd.conf
echo "          AllowOverride all" >> /etc/httpd/conf/httpd.conf
echo "          # MultiViews must be turned off." >> /etc/httpd/conf/httpd.conf
echo "          Options -MultiViews" >> /etc/httpd/conf/httpd.conf
echo "		</Directory>" >> /etc/httpd/conf/httpd.conf
echo "	</VirtualHost>" >> /etc/httpd/conf/httpd.conf
echo "</IfModule>" >> /etc/httpd/conf/httpd.conf

print_good "Passenger Module config and Snorby Virtual Host data added to /etc/httpd/conf/httpd.conf"

########################################

#The rest is to perform the final installation steps for snorby use bundler to grab the remaining gems needed and configure everything, then rake to make it run. 


print_status "Running bundler.."

cd /var/www/html/snorby

bundle install --deployment &>> $snorby_logfile
error_check 'bundler'

#TODO:`which pdfkit` --install-wkhtmltopdf 

print_status "Running rake.."

rake snorby:setup &>> $snorby_logfile
error_check 'rake'

########################################

#SELinux needs to be modified for CentOS to even *Try* to play nice with Snorby.

print_status "Installing audit2allow for SELinux.."
yum -y install /usr/bin/audit2allow &>> $snorby_logfile
error_check 'audit2allow install'

print_status "Modifying SELinux file permssions for contexts httpd_sys_rw_content_t and httpd_sys_script_exec_t to allow access to critical files for Snorby.."
chcon -R -t httpd_sys_rw_content_t /var/www/html/snorby/ &>> $snorby_logfile
chcon -t httpd_sys_script_exec_t /usr/local/rvm/rubies/ruby-$rubyver/bin/ruby &>> $snorby_logfile
chcon -t httpd_sys_script_exec_t /usr/local/rvm/wrappers/ruby-$rubyver/ruby &>> $snorby_logfile
chcon -t httpd_sys_script_exec_t /usr/local/rvm/rubies/ruby-$rubyver/lib/libruby.so* &>> $snorby_logfile
chcon -R -t httpd_sys_script_exec_t /usr/local/rvm/gems/ruby-$rubyver/gems/ &>> $snorby_logfile
chcon -R -t httpd_sys_script_exec_t /var/www/html/snorby/vendor/bundle/ruby/*/gems/ &>> $snorby_logfile
print_good "SELinux file permissions successfully changed."

print_status "Setting SELinux Booleans to allow httpd network connectivity and database connectivity via setsebool.."
print_notification "This will take a moment or two. I promise the script isn't hanging."
setsebool -P httpd_can_network_connect_db 1 &>> $snorby_logfile
setsebool -P httpd_can_network_connect 1 &>> $snorby_logfile
print_good "Boolean settings successfully modified"

print_status "Generating SELinux module in /usr/src/selinux-devel."
mkdir -p /usr/src/selinux-devel &>> $snorby_logfile
cd /usr/src/selinux-devel &>> $snorby_logfile
ln -s /usr/share/selinux/devel/Makefile . &>> $snorby_logfile

#Can't think of a cleaner way to do this, other than forcing the user to have another file in the same directory as the child shell script. I don't want to do that, as this is vital to make Snorby work with SELinux. This is an SELinux policy module. I went through a lot of manual testing to produce this. This is the secret sauce that allows Snorby to work with SELinux enabled.

echo "module passenger 1.0;" > passenger.te
echo "require {" >> passenger.te
echo "		type init_t;" >> passenger.te
echo "		type initrc_t;" >> passenger.te
echo "		type system_cronjob_t;" >> passenger.te
echo "		type mysqld_t;" >> passenger.te
echo "		type usr_t;" >> passenger.te
echo "		type syslogd_t;" >> passenger.te
echo "		type system_dbusd_t;" >> passenger.te
echo "		type abrt_dump_oops_t;" >> passenger.te
echo "		type dhcpc_t;" >> passenger.te
echo "		type kernel_t;" >> passenger.te
echo "		type auditd_t;" >> passenger.te
echo "		type udev_t;" >> passenger.te
echo "		type mysqld_safe_t;" >> passenger.te
echo "		type postfix_pickup_t;" >> passenger.te
echo "		type sshd_t;" >> passenger.te
echo "		type crond_t;" >> passenger.te
echo "		type getty_t;" >> passenger.te
echo "		type anon_inodefs_t;" >> passenger.te
echo "		type httpd_tmp_t;" >> passenger.te
echo "		type devpts_t;" >> passenger.te
echo "		type user_devpts_t;" >> passenger.te
echo "		type httpd_sys_script_t;" >> passenger.te
echo "		type security_t;" >> passenger.te
echo "		type httpd_t;" >> passenger.te
echo "		type unconfined_t;" >> passenger.te
echo "		type selinux_config_t;" >> passenger.te
echo "		type hi_reserved_port_t;" >> passenger.te
echo "		type httpd_sys_content_t;" >> passenger.te
echo "		type httpd_sys_rw_content_t;" >> passenger.te
echo "		type var_t;" >> passenger.te
echo "		type cert_t;" >> passenger.te
echo "		type postfix_qmgr_t;" >> passenger.te
echo "		type postfix_master_t;" >> passenger.te
echo "		class file { getattr read create append write execute execute_no_trans open };" >> passenger.te
echo "		class process { siginh signal noatsecure rlimitinh setpgid getsession };" >> passenger.te
echo "		class unix_stream_socket { read write shutdown };" >> passenger.te
echo "		class chr_file { read write append ioctl };" >> passenger.te
echo "		class capability { setuid dac_override chown fsetid setgid fowner sys_nice sys_resource sys_ptrace kill };" >> passenger.te
echo "		class fifo_file { setattr create getattr unlink };" >> passenger.te
echo "		class sock_file { write getattr setattr create unlink };" >> passenger.te
echo "		class lnk_file { read getattr };" >> passenger.te
echo "		class udp_socket name_bind;" >> passenger.te
echo "		class dir { write read search add_name getattr };" >> passenger.te
echo "}" >> passenger.te
echo "#This stuff below is more of an access control list -- these are things the contexts below are requesting to be able to do in order to run properly." >> passenger.te
echo "#============= httpd_sys_script_t ==============" >> passenger.te
echo "allow httpd_sys_script_t abrt_dump_oops_t:dir { search getattr };" >> passenger.te
echo "allow httpd_sys_script_t abrt_dump_oops_t:file { read open };" >> passenger.te
echo "allow httpd_sys_script_t anon_inodefs_t:file { read write };" >> passenger.te
echo "allow httpd_sys_script_t auditd_t:dir { search getattr };" >> passenger.te
echo "allow httpd_sys_script_t auditd_t:file { read open };" >> passenger.te
echo "allow httpd_sys_script_t cert_t:dir { search getattr };" >> passenger.te
echo "allow httpd_sys_script_t cert_t:file { read getattr };" >> passenger.te
echo "allow httpd_sys_script_t cert_t:lnk_file read;" >> passenger.te
echo "allow httpd_sys_script_t crond_t:dir { search getattr };" >> passenger.te
echo "allow httpd_sys_script_t crond_t:file { read open };" >> passenger.te
echo "allow httpd_sys_script_t devpts_t:chr_file { read write };" >> passenger.te
echo "allow httpd_sys_script_t dhcpc_t:dir { search getattr };" >> passenger.te
echo "allow httpd_sys_script_t dhcpc_t:file { read open };" >> passenger.te
echo "allow httpd_sys_script_t getty_t:dir { search getattr };" >> passenger.te
echo "allow httpd_sys_script_t getty_t:file { read open };" >> passenger.te
echo "allow httpd_sys_script_t httpd_sys_content_t:fifo_file setattr;" >> passenger.te
echo "allow httpd_sys_script_t httpd_sys_content_t:sock_file { create unlink setattr };" >> passenger.te
echo "allow httpd_sys_script_t httpd_sys_rw_content_t:file { execute execute_no_trans };" >> passenger.te
echo "allow httpd_sys_script_t httpd_t:dir { search getattr };" >> passenger.te
echo "allow httpd_sys_script_t httpd_t:file { read open };" >> passenger.te
echo "allow httpd_sys_script_t httpd_t:unix_stream_socket { read write };" >> passenger.te
echo "allow httpd_sys_script_t httpd_tmp_t:fifo_file setattr;" >> passenger.te
echo "allow httpd_sys_script_t httpd_tmp_t:sock_file { write create unlink setattr };" >> passenger.te
echo "allow httpd_sys_script_t init_t:dir { search getattr };" >> passenger.te
echo "allow httpd_sys_script_t init_t:file { read open };" >> passenger.te
echo "allow httpd_sys_script_t initrc_t:dir { search getattr };" >> passenger.te
echo "allow httpd_sys_script_t initrc_t:file { read open };" >> passenger.te
echo "allow httpd_sys_script_t kernel_t:dir { search getattr };" >> passenger.te
echo "allow httpd_sys_script_t kernel_t:file { read open };" >> passenger.te
echo "allow httpd_sys_script_t mysqld_safe_t:dir { search getattr };" >> passenger.te
echo "allow httpd_sys_script_t mysqld_safe_t:file { read open };" >> passenger.te
echo "allow httpd_sys_script_t mysqld_t:dir { search getattr };" >> passenger.te
echo "allow httpd_sys_script_t mysqld_t:file { read open };" >> passenger.te
echo "allow httpd_sys_script_t postfix_master_t:dir { search getattr };" >> passenger.te
echo "allow httpd_sys_script_t postfix_master_t:file { read open };" >> passenger.te
echo "allow httpd_sys_script_t postfix_pickup_t:dir { search getattr };" >> passenger.te
echo "allow httpd_sys_script_t postfix_pickup_t:file { read open };" >> passenger.te
echo "allow httpd_sys_script_t postfix_qmgr_t:dir { search getattr };" >> passenger.te
echo "allow httpd_sys_script_t postfix_qmgr_t:file { read open };" >> passenger.te
echo "allow httpd_sys_script_t self:capability { setuid chown fsetid setgid fowner dac_override sys_nice sys_resource sys_ptrace kill };" >> passenger.te
echo "allow httpd_sys_script_t self:process { setpgid getsession };" >> passenger.te
echo "allow httpd_sys_script_t sshd_t:dir { search getattr };" >> passenger.te
echo "allow httpd_sys_script_t sshd_t:file { read open };" >> passenger.te
echo "allow httpd_sys_script_t syslogd_t:dir { search getattr };" >> passenger.te
echo "allow httpd_sys_script_t syslogd_t:file { read open };" >> passenger.te
echo "allow httpd_sys_script_t system_cronjob_t:dir getattr;" >> passenger.te
echo "allow httpd_sys_script_t system_dbusd_t:dir { search getattr };" >> passenger.te
echo "allow httpd_sys_script_t system_dbusd_t:file { read open };" >> passenger.te
echo "allow httpd_sys_script_t udev_t:dir { search getattr };" >> passenger.te
echo "allow httpd_sys_script_t udev_t:file { read open };" >> passenger.te
echo "allow httpd_sys_script_t unconfined_t:dir { search getattr };" >> passenger.te
echo "allow httpd_sys_script_t unconfined_t:file { read open };" >> passenger.te
echo "allow httpd_sys_script_t unconfined_t:process signal;" >> passenger.te
echo "allow httpd_sys_script_t user_devpts_t:chr_file { read write append ioctl };" >> passenger.te
echo "allow httpd_sys_script_t usr_t:file execute;" >> passenger.te
echo "allow httpd_sys_script_t var_t:dir { write read add_name };" >> passenger.te
echo "allow httpd_sys_script_t var_t:file { read getattr create append };" >> passenger.te
echo "#============= httpd_t ==============" >> passenger.te
echo "allow httpd_t hi_reserved_port_t:udp_socket name_bind;" >> passenger.te
echo "allow httpd_t httpd_sys_content_t:fifo_file { create unlink getattr setattr };" >> passenger.te
echo "allow httpd_t httpd_sys_content_t:sock_file { getattr unlink setattr };" >> passenger.te
echo "allow httpd_t httpd_sys_script_t:process { siginh rlimitinh noatsecure };" >> passenger.te
echo "allow httpd_t httpd_sys_script_t:unix_stream_socket { read write shutdown };" >> passenger.te
echo "allow httpd_t httpd_tmp_t:fifo_file { create unlink getattr setattr };" >> passenger.te
echo "allow httpd_t httpd_tmp_t:sock_file { getattr unlink setattr };" >> passenger.te
echo "allow httpd_t security_t:dir search;" >> passenger.te
echo "allow httpd_t self:capability { fowner fsetid };" >> passenger.te
echo "allow httpd_t selinux_config_t:dir search;" >> passenger.te
echo "allow httpd_t var_t:file { read getattr };" >> passenger.te
echo "allow httpd_t var_t:lnk_file { read getattr };" >> passenger.te

print_good "SELinux policy module generated. Location: /usr/src/selinux-devel/passenger.te"

print_status "Checking SELinux policy module.."

checkmodule -M -m -o passenger.mod passenger.te &>> $snorby_logfile
error_check 'SELinux policy module check'

print_status "Compiling SELinux policy module.."

semodule_package -o passenger.pp -m passenger.mod &>> $snorby_logfile
error_check 'SELinux policy module compile'

print_status "Inserting SELinux policy module into current SELinux policy.."

semodule -i passenger.pp &>> $snorby_logfile
error_check 'SELinux policy installation'

print_notification "If you ever decide to uninstall snorby, you'll want to remove the passenger module. This can be done via: semodule -r passenger"

########################################

#The commands below are to drop privileges: We want to have the snort database user manage the snorby database. This is done for purposes of least privilege. You don't need root, so I'm not giving it to you.

print_status "Giving permission to snort database user to manage the snorby database (dropping privs).."

mysql -uroot -p$root_mysql_pass -e "grant create, insert, select, delete, update on snorby.* to snort@localhost identified by '$snort_mysql_pass';" &>> $snorby_logfile

print_status "Reconfiguring Snorby and Barnyard2 to work together.."

sed -i 's/username: root/username: snort/' /var/www/html/snorby/config/database.yml
sed -i 's/password: $root_mysql_pass/password: $snort_mysql_pass/' /var/www/html/snorby/config/database.yml
sed -i 's/dbname=snort/dbname=snorby/' $snort_basedir/etc/barnyard2.conf

########################################

#I'm not comfortable with the database user's creds being in a world-readable file.

print_status "Resetting permissions on database.yml and snorby_config.yml.."

chmod 400 /var/www/html/snorby/config/database.yml 
chmod 400 /var/www/html/snorby/config/snorby_config.yml

########################################

#give apache access to snorby's files and restart apache. We're done here.

print_status "Giving ownership of /var/www/html/snorby to the apache user and group.."

chown -R apache:apache /var/www/html/snorby/ &>> $snorby_logfile
error_check 'snorby file ownership reset'

service httpd restart &>> $snorby_logfile
error_check 'httpd service restart'

print_notification "The log file for this interface installation is located at: $snorby_logfile"
exit 0