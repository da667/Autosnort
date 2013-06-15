#!/bin/bash
#BASE shell script 'module'
#Sets up BASE for for Autosnort


echo "grabbing packages for BASE"
#grab packages for BASE. Most of the primary required packages are pulled by  the main AS script.
apt-get install -y libphp-adodb ca-certificates php-pear libwww-perl php5 php5-mysql php5-gd

#These are php-pear config commands Seen in the 2.9.4.0 install guide for Debian.
pear config-set preferred_state alpha
pear channel-update pear.php.net
pear install --alldeps Image_Color Image_Canvas Image_Graph


#The BASE tarball creates a directory for us, all we need to do is move to webroot.
cd /var/www/
#Have to adjust PHP logging otherwise BASE will barf on startup.
sed -i 's/error_reporting \= E_ALL \& ~E_DEPRECATED/error_reporting \= E_ALL \& ~E_NOTICE/' /etc/php5/apache2/php.ini

# We need to grab BASE from sourceforge. If this fails, we exit the script with a status of 1
# A check is built into the main script to verify this script exits cleanly. If it doesn't,
# The user should be informed and brought back to the main interface selection menu.
echo "grabbing BASE."
 wget http://sourceforge.net/projects/secureideas/files/BASE/base-1.4.5/base-1.4.5.tar.gz -O base-1.4.5.tar.gz
if [ $? != 0 ];then
	echo "Attempt to pull down BASE failed. Please verify network connectivity and try again."
	exit 1
else
	echo "Successfully downloaded the BASE tarball."
fi
tar -xzvf base-1.4.5.tar.gz
rm base-1.4.5.tar.gz
mv base-* base

#BASE requires the /var/www/ directory to be owned by www-data
chown -R www-data:www-data /var/www

exit 0