#!/bin/bash
#auto-snort for Backtrack 5r3
# purpose: from nothing to full snort in gods know how much time it takes to compile some of this shit.
#Contact info:
#@da_667 via twitter
#deusexmachina667@gmail.com

#Declaring Functions - This function is an easier way to reuse the apt-get code and pull down 1 or multiple packages at once.

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

####step 1: pre-reqs.#### 
# We need to check OS we're installing to, net connectivity, user we are running as, ensure sshd is running and wget is available.

#This is our OS Check. We want to ensure that we're running BT5r3.
#We're catting /etc/motd, cutting the first three lines and verifying that the read back "BackTrack 5 R3"
#This isn't as reliable as the check for autosnort in Ubuntu, but we have logic here that allows the user to continue if they've modified/removed the issue banner.
#warns the user if we're not running this script on BT5r3 that this script has not been tested on other platforms/distros then asks if they want to continue.
echo "OS Version Check."
     release=`cat /etc/issue | cut -f1,2,3 -d " "`
     if [ $release != "BackTrack 5 R3" ]
          then
               echo "Unable to determine if this is Backtrack 5 R3. This script has not been tested on other platforms."
               while true; do
                   read -p "Continue? (y/n)" warncheck
                   case $warncheck in
                       [Yy]* ) break;;
                       [Nn]* ) echo "Cancelling."; exit;;
                       * ) echo "Please answer yes or no.";;
                   esac
done
          else
               echo "Verified as Backtrack 5 R3. Good to go."
		echo " "
     fi
	 
#assumes internet connectivity. Connectivity check uses icmp, pings google once and checks for exit 0 status of the command. Exits script on error and notifies user connectivity check failed.

echo "Checking internet connectivity (pinging google.com)"
     ping google.com -c1 &> /dev/null
     if [ $? -eq 0 ]; then
          echo "Connectivity looks good!"
     else
          echo "Ping to google has failed. Please verify you have network connectivity or ICMP outbound is allowed. Seriously, what harm is it going to do?"
   	  exit 1
     fi

#assumes script is ran as root. root check performed via use of whoami. 
#checks for a response of "root" if user isn't root, script exits and notifies user it needs to be ran as root.
#we really shouldn't need to do this on a Backtrack system what with root being default users and /etc/nologin being present, but... why not?

echo "User Check"
     if [ $(whoami) != "root" ]
          then
               echo "This script must be ran with sudo or root privileges, or this isn't going to work."
		exit 1
          else
               echo "We are root."
     fi
	 
#Checking to ensure sshd is running done by running ps-ef, grepping for sshd, using wc -l and if we have more than one line, using that as a sign that SSHD is running 
#Anyone who's used ps-ef | grep [blah] knows that it will always return 0. 
#However if it only returns one line, that means the process you are searching for is not actually running.
#If YOU have a more reliable method of checking via a command that sshd is running, I'm all ears.
#TODO: want to ask the user, if this is a new backtrack install, if they want us to run sshd-generate and update-rc.d defaults to generate ssh keys and have sshd set to run at startup. Will revisit later.

echo "Checking to ensure sshd is running."

	if [ $(/bin/ps -ef |/bin/grep sshd |/usr/bin/wc -l) -gt 1 ]
		then
			echo "sshd is running "
		else
			echo "sshd isn't running... The script can continue, but in most cases, sshd is use for remotely managing snort sensors."
	fi
	
#the below checks for the existence of wget and offers to download it via apt-get if it isn't installed.
#Wget check cleaned up, redirected to /dev/null. We look for an exit 0 status against "which wget".
#any status other than 0 results in use asking the user if they want to install wget, which is required for us to download several sourcetarballs for the script.
#like the root user check, this should never fail in backtrack. Several packages depend on wget.

	/usr/bin/which wget &> /dev/null
		if [ $? -ne 0 ]; then
        		echo "wget not found. Install wget?"
         case $wget_install in
                                [yY]*)
				install_packages wget
                                ;;
                                *)
                                echo "Either you selected no or I didn't understand. Wget is required to continue"
                                exit 1
                                ;;
                                esac
		else
        		echo "found wget."
		fi
		
####step 2: patches and package pre-reqs####

#Here we call apt-get update and apt-get -y upgrade to ensure all repos and stock software is fully updated.
#For consistency, if the command chain exits on anything other than a 0 exit code, we notify the user that updates were not successfully installed.

echo "Performing apt-get update and apt-get upgrade (with -y switch)"

apt-get update && apt-get -y upgrade 
if [ $? -eq 0 ]; then
	echo "Packages and repos are fully updated."
else
	echo "apt-get upgrade or update failed."
fi

echo "Grabbing required packages via apt-get."

#Here we grab base install requirements for a full stand-alone snort sensor.
#Users of autosnort for ubuntu will notice that the package list is a lot smaller. Backtrack has most of these packages installed by default.
#TODO: Give users a choice -- do they want to install a collector, a full stand-alone sensor, or a barebones sensor install?

declare -a packages=(php5-gd libpcre3-dev libpcap-ruby);
install_packages ${packages[@]}

#Here is where we'd normally acquire mysql server and client. bt5 has these installed by default. 
#We ask the user if they want mysql to be started up on boot and if they do, just run update-rc.d mysql defaults to make it happen.
echo "Acquiring and install mysql server and client packages. You will need to assign a password to the root mysql user."

declare -a packages=(mysql-server libmysqlclient-dev)
install_packages ${packages[@]}