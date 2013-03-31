###############################
autosnort-centOS Release Notes
###############################

Current Release: autosnort-centOS-03-30-2013.sh

Release notes:

- This new release of autosnort for CentOS introduces support for an additional web front-end: Tactical Flex's Aanval Console!

- Please note that for this release, autosnort does not yet support some of the more advanced snort-related features for Aanval just yet (such as rule and/or policy management). At this stage, this is just to register the snort functionality with Aanval and get intrusion events reported to the Aanval Console.

- With this release I'm trying to make autosnort a bit more modular, instead of having it be one gigantic, monolithic shell script. This was a design choice I made to make it easier to troubleshoot issues with Autosnort and add on functionality. The first things I decided to break off from the main script was installation of different front ends. You'll notice there are two smaller shell scripts that accompany the main shell script:

--aanval-centOS.sh // installs aanval
--snortreport-centOS.sh // installs snort report

- Place these scripts in root's home directory (/root) along with the main autosnort script. /root is where the main script expects to find the child scripts. If the child scripts aren't there, the web front-end installation section of autosnort will fail to run until the child shell script is present in /root.

- As a part of the installation for Aanval on CentOS for users running SELinux, be aware that the script modifies SELinux to allow the httpd process to perform database connections (127.0.0.1:3306), and r/w access to /var/www/html/aanval and its subdirectories. You should NOT have to disable SELinux to run Aanval with these changes, just like you didn't have to with snortreport. Remember: disable SELinux is NEVER the solution!

- Finally, previous releases are available in the Previous_Rel directory, in the event that you find a bug with the current release and cannot wait for a fix to be made available.

bug fixes:

- Changed how the main script performs the OS check. no longer checks for the sub-version of CentOS when running (e.g. 6.x), just checks to see if the primary OS version number is 6. Script was flagging CentOS 6.4 as an unsupported operating system for this script.

other notes:

- Recieved a couple of notifications that users cannot connect to the web server running on their sensor post-reboot after the installation is done. This is because CentOS ships with a firewall that essentially blocks everything but 22/tcp (ssh) inbound by default. To remedy this, run the command "system-configure-firewall-tui" and enable access for "WWW" (80/tcp), and everything should work fine.

##################
Previous Releases
##################

Hello autosnort users. This is a README the CentOS autosnort build with Pulled Pork integration.

- The biggest change in functionality you will notice is the pulled pork integration using pulled pork for rule management has a few requirements:

	1. You need to have a valid oink code. register on snort.org as a registered user, or if you have a VRT subscription, the VRT oink code you have should work fine
	2. You'll need http and https access to labs.snort.org and snort.org to download snort.conf (from labs.snort.org) and rules via pulled pork (snort.org)

- short_open_tag as well as SELinux configuration can be automatically performed for you through the script. --short_open_tag ON is required for httpd to be able to make sense of the short php tags. 
--SELinux reconfiguration is necessary for SELinux to allow httpd to access /var/www/html/snortreport files as required.

other notes:

- A lot of fault tolerance improvements in the code -- the script will no longer blindly plow forward if you give it invalid input. If you give the script something invalid or something that doesn't make sense the script loops through the routine until it gets input that makes sense.


as always, I can be contacted via twitter:
@da_667

or via e-mail:
deusexmachina667@gmail.com

Regards,

DA