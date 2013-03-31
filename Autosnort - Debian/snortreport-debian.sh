#!/bin/bash
#Aanval shell script 'module'
#Sets up snort report for Autosnort

#Grab jpgraph and throw it in /var/www
#Required to display graphs in snort report UI

echo "Downloading and installing jpgraph."

cd /usr/src
wget http://hem.bredband.net/jpgraph/jpgraph-1.27.1.tar.gz
if [ $? != 0 ];then
	echo "Attempt to pull down jpgraph failed. Please verify network connectivity and try again."
	exit 1
else
	echo "Successfully downloaded the aanval tarball."
fi
mkdir /var/www/jpgraph
tar -xzvf jpgraph-1.27.1.tar.gz
cp -r jpgraph-1.27.1/src /var/www/jpgraph

echo "jpgraph downloaded to /usr/src. installed to /var/www/jpgraph."

#now to install snort report.

echo "downloading and installing snort report"

cd /usr/src
wget http://www.symmetrixtech.com/ids/snortreport-1.3.3.tar.gz
if [ $? != 0 ];then
	echo "Attempt to pull down snortreport failed. Please verify network connectivity and try again."
	exit 1
else
	echo "Successfully downloaded the aanval tarball."
fi

tar -xzvf snortreport-1.3.3.tar.gz -C /var/www/
mv /var/www/snortreport-1.3.3 /var/www/snortreport

#Decided to change the script: the main script should make the user create a snort database user and assign it password.
#At this point, we should automatically drop this password into srconf.php instead of asking the user if they want to.
#If the user wants this to work, they have to do it anyhow.

cp /var/www/snortreport/srconf.php /root/srconf.php.tmp
sed -i 's/YOURPASS/'$MYSQL_PASS_1'/' /root/srconf.php.tmp
cp /root/srconf.php.tmp /var/www/snortreport/srconf.php
rm /root/srconf.php.tmp
echo "password insertion complete."
echo ""

#known problem with snort report 1.3.3 not playing nice on systems that have the short_open_tag directive in php.ini set to off. Give the user a choice if they want the script to automatically resolve this, or if they plan on adding in proper php open tags on their own.

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

exit 0
