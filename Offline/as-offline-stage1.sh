#!/bin/bash
#####################################################################################################################################
#####################################################################################################################################
# Autosnort offline installer. Downloads all required packages and .tar.gz files for autosnort. As implied, this means this script  #
# must be ran on a system that DOES have internet access. Also, the offline and online operating system AND distro MUST match. this #
# should be a given. Be forewarned, this script is VERY VERY stripped down. If you run into problems, report them!                  #
# twitter: @da_667                                                                                                                  #
# email: deusexmachina667@gmail.com                                                                                                 #
# Shouts to UAS and Forgottensec. I'm never there, but I'm always there.                                                            #
#####################################################################################################################################
#####################################################################################################################################

# determine arch. Much uglier work-around to support Debian here.
arch=`uname -a | cut -d " " -f12`
# determine OS. not the cleanest method... but it works.
OS=`cat /etc/issue.net | cut -d " " -f1`

# This exists for idiot proofing. The script uses wget extensively, so I want to make sure it's there. I'm not going to bother
# Checking for apt-get or dpkg because it should be there. Not going to hand-hold THAT much.


which wget 2>&1 >> /dev/null
if [ $? -ne 0 ]; then
	echo "wget not found. installing wget"
	echo ""
	apt-get -y install wget
else
	echo "wget found."
	echo ""
fi

# The portions below are pretty easy to follow. we're making directories and making them nested parents,
# Then using apt-get with the -y -d and the -o options. -y is to not be prompted to accept the download confirmation -d is to 
# only download the packages -o sets the script's cache directory to our newly created cache directory. the subdirectories need to be 
# there otherwise apt will bitch and complain.

mkdir -p AS_offline_$OS$arch/apt_pkgs/archives/partial

# Debian needs access to particiular apt repos to pull the required packages. We're doing a check here to see if the host OS is Debian.
# Then adding the repos in question and pulling the GPG key if the host OS is Debian.

if [ $OS = "Debian" ]; then
	echo "adding deb and deb-src via http://packages.dotdeb.org to apt sources."
	echo "# the below lines are added via autosnort to ensure a successful snort installation." >> /etc/apt/sources.list
	echo "deb http://packages.dotdeb.org squeeze all" >> /etc/apt/sources.list
	echo "deb-src http://packages.dotdeb.org squeeze all" >> /etc/apt/sources.list
	echo "adding packages.dotdeb.org gpg key."
	wget http://www.dotdeb.org/dotdeb.gpg && cat dotdeb.gpg | apt-key add -
else
	echo "Not Debian. Moving on."
	echo ""
fi
apt-get update
apt-get install -y -d -o dir::cache=./AS_offline_$OS$arch/apt_pkgs ethtool nmap nbtscan apache2 php5 php5-mysql php5-gd libpcap0.8-dev libpcre3-dev g++ bison flex libpcap-ruby make autoconf libtool mysql-server libmysqlclient-dev linux-libc-dev libxpm4

 

# Next, we need to download our source packages. we drop these in a sources directory. grabs: barnyard2, snort, daq, libdnet, snortreport, and jpgraph

mkdir AS_offline_$OS$arch/sources
cd AS_offline_$OS$arch/sources

# Handy quick and dirty way to determine the latest stable release versions of snort and daq, then download them.
wget -q http://snort.org/snort-downloads -O /tmp/snort-downloads
snortver=`cat /tmp/snort-downloads | grep snort-[0-9]|cut -d">" -f2 |cut -d"<" -f1 | head -1`
daqver=`cat /tmp/snort-downloads | grep daq|cut -d">" -f2 |cut -d"<" -f1 | head -1`
rm /tmp/snort-downloads
wget http://snort.org/dl/snort-current/$snortver -O $snortver
wget http://snort.org/dl/snort-current/$daqver -O $daqver

wget http://libdnet.googlecode.com/files/libdnet-1.12.tgz
wget http://www.symmetrixtech.com/ids/snortreport-1.3.3.tar.gz
wget http://hem.bredband.net/jpgraph/jpgraph-1.27.1.tar.gz
wget http://www.securixlive.com/download/barnyard2/barnyard2-1.9.tar.gz -O barnyard2.tar.gz

#get out of the packages directory and tar it up for sneakernet transit to the offline system and interaction with the stage 2 script.
cd ../..
# this dpkgorder script is included with the stage1 shell script. It's MANDATORY to have this file in the archives directory. these are the
# packages installed via the apt-get line above. They MUST be installed in the order presented in this file.
# create-sidmap.pl is not mandatory to have, but if you want to know what snort alert 23455 is named, you'll include it.

cp dpkgorder$OS$arch.txt AS_offline_$OS$arch/apt_pkgs/archives/
cp create-sidmap.pl AS_offline_$OS$arch/sources
tar -cvzf AS_offline_$OS$arch.tar.gz  AS_offline_$OS$arch/

# as part of snort install:
# need to symlink these two libraries on ubuntu. snort doesn't know where to find them by default.
# ln -s /usr/local/lib/libdnet.1.0.1 /usr/lib/libdnet.1
# ln -s /usr/local/lib/libsfbpf.so.0 /usr/lib/libsfbpf.so.0
