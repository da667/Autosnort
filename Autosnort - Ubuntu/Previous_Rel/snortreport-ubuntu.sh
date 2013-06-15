#!/bin/bash
#Snortreport shell script 'module'
#Sets up snort report for Autosnort

apt-get install -y php5 php5-mysql php5-gd nmap nbtscan

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

exit 0
