##############################
autosnort-Debian Release Notes
##############################

Current Release: autosnort-debian-03-30-2013.sh

Release notes:

- This new release of autosnort for Debian introduces support for an additional web front-end: Tactical Flex's Aanval Console!

- Please note that for this release, autosnort does not yet support some of the more advanced snort-related features for Aanval just yet (such as rule and/or policy management). At this stage, this is just to register the snort functionality with Aanval and get intrusion events reported to the Aanval Console.

- With this release I'm trying to make autosnort a bit more modular, instead of having it be one gigantic, monolithic shell script. This was a design choice I made to make it easier to troubleshoot issues with Autosnort and add on functionality. The first things I decided to break off from the main script was installation of different front ends. You'll notice there are two smaller shell scripts that accompany the main shell script:

--aanval-debian.sh // installs aanval
--snortreport-debian.sh // installs snort report

- Place these scripts in root's home directory (/root) along with the main autosnort script. /root is where the main script expects to find the child scripts. If the child scripts aren't there, the web front-end installation section of autosnort will fail to run until the child shell script is present in /root.

- Finally, previous releases are available in the Previous_Rel directory, in the event that you find a bug with the current release and cannot wait for a fix to be made available.


##################
Previous Releases
##################

- 1/3/2013: pulled pork integration has been integrated into the debian autosnort script. 

- The biggest change in functionality you will notice is the pulled pork integration using pulled pork for rule management has a few requirements:

	1. You need to have a valid oink code. register on snort.org as a registered user, or if you have a VRT subscription, the VRT oink code you have should work fine
	2. You'll need http and https access to labs.snort.org and snort.org to download snort.conf (from labs.snort.org) and rules via pulled pork (snort.org)

other notes:

- A lot of fault tolerance improvements in the code. In most places requiring user input, the script will no longer blindly plow forward if you give it invalid input. If you give the script something invalid or something that doesn't make sense the script loops through the routine until you give it input that makes sense.


Hello folks, this is the readme specific to the Debian edition of autosnort.

- For the most part, this is a complete clone of the autosnort ubuntu script except with changes where required (e.g. version checking) and a couple of minor changes:

- As part of the installation http://www.dotdeb.org (deb and deb-src) and its gpg key are added in order to install necessary components of snort and snortreport.

- As recommended per the the snort 2.9.3.1 install guide, the script installs ethtool and disables lro and gro (checksum offloading) on the sniffing interface

- The short_open_tag is disabled by default on php installations on Debian. this results in page rendering problems for snort report.

	1. open up php.ini via the editor of your choice
	2. locate the short_open_tag directive. This should be line 226.
	3. Set this directive from Off to On and save php.ini
	4. Reload or Restart the apache web server (/etc/init.d/apache2 restart)

Otherwise you will have to modify the php for each snort report page to eliminate the short open php tags.

as always, I can be contacted via twitter:
@da_667

or via e-mail:
deusexmachina667@gmail.com

Regards,

DA