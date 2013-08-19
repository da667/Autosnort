###############################
Installation Instructions
###############################

1. copy the autosnort-debian-mm-dd-yyyy.sh script to root's home directory (/root) from the autosnort-master/autosnort - debian directory
2. decide which interface you would like to install there are five choices:
snortreport
BASE
aanval
snorby
remote syslog
3. Copy the shell script named after the interface you wish to install from autosnort-master/autosnort - debian/ directory and place it in /root along with the autosnort-debian-mm-dd-yyyy.sh script (example: if you want to install snorby, copy the snort-debian.sh script to /root along with autosnort-debian-mm-dd-yyyy.sh script
4. Run the autosnort-debian-mm-dd-yyyy.sh script:
as root:
cd /root;bash autosnort-debian-mm-dd-yyyy.sh
alternatively:
cd /root;chmod u+x autosnort-debian-mm-dd-yyyy.sh;./autosnort-debian-mm-dd-yyyy.sh
via sudo:
cd /root;sudo bash autosnort-debian-mm-dd-yyyy.sh
5. The script will prompt you as it needs answers from you. Answer the questions and before you know it, the installation is done.

##############################
autosnort-Debian Release Notes
##############################

Current Release: autosnort-debian-08-18-2013.sh

Release Notes:

- In an effort to make the mysql installs uniform between all autosnort builds and promote better security, I've made the mysql-server installation for Ubuntu and Debian silent, but now, just like with the centOS script, the /usr/bin/mysql_secure_installation script is ran as a part of autosnort. huzzah for better secured databases.


Bug Fixes:

- Apparently at some point between now and june, the passenger output directory for the mod_passenger.so binary changed the name of the directory from "libout" to "buildout". sigh. consistency is awesome, don't you agree? I only discovered this during testing passenger during the centOS testing process. 
- Same as the centOS script, found minor grammatical and syntactical errors littered all over the script. Found and fixed what I could.

##################
Previous Releases
##################

autosnort-debian-06-15-2013

Release Notes:

- This version is almost a complete re-write of the script. Quite a few nicer/newer features added to this build:
-- Output from the script has been minimized where possible. Instead of writing all command output to the screen and "puking" all over the screen buffer, users are now presented with nice, metasploit like prompts, giving a basic run-down of what the script is doing (blue output), things the user needs to pay attention to (yellow output), and whether or not a given task in the script was successful (green is good, red is bad). Instead of outputting everything to the screen...
-- ...Autosnort and all of the child shell scripts now automatically log the entire installation. Log files are written to /var/log. The primary script logs to autosnort_install.log, the child scripts also log to /var/log and are named after their namesake web interface. (e.g. snorby would be named snorby_install.log). This is in an effort to make troubleshooting easier for users -- you can review the installation logs to see what went wrong, or if you contact me, you can send me a copy and I can try to troll through them to figure out what exploded
-- Related to the logging/output printing improvements, the print statements actually tell you where the different components are installed
-- Support for Debian 7 officially added, backwards compatibility with Debian 6 maintained
-- Did some magic with the apache default-site config file to make it to where, no matter what web interface you install, you can point your web browser to your sensor's IP address and be greeted by your web interface (Gritty details: for each web interface install, the apache default-site DocumentRoot gets set to where the web interface is the DocumentRoot -- for example, if you install aanval, you can browse to http://[address] and be immediately greeted by aanval.)
-- Added an option to create an entry for Aanval's BPU subsystem in rc.local to start them up on boot

Bug fixes:
- Fixed an annoying problem with Debian 6/7 -- different versions of the operating system store libmysqlclient.so, a necessary file for barnyard2, in a different place. Made it to where the script does "find /usr/lib -name libmysqlclient.so | dirname" to tell the barnyard2 ./configure script where the libmysqlclient.so libriaries are located, instead of a bunch of if/thens.

autosnort-debian-05-19-2013

Release Notes:

- added in support for snorby (finally) after several long, grueling hours of testing.
-- navigate to the snorby web interface is simple, point your your browser to http://[sensor ip address] and you're done.
-- the default credentials are snorby@snorby.org and the password is snorby
-- Note that after reboot, the console may complain that the worker process isn't working. You'll need to ssh or console on as root and run this command to start the delayed_job task:
cd /var/www/snorby && ruby script/delayed_job start
additionally, you may want to force snorby to run the sensor cache jobs now as opposed to when it is scheduled to do so later:
cd /var/www/snorby && rails runner 'Snorby::Jobs::SensorCacheJob.new(false).perform; Snorby::Jobs::DailyCacheJob.new(false).perform'

-- I tried to automate this (have the commands added to rc.local, but that did not work as intended... so unfortunately, every time the system is rebooted, you'll likely want to ssh or console in to run these tasks, or try started the snorby worker via the web interface.

--as another side note, if you notice that intrusion events are filling the 'event' tab, but the dashboard has yet to update, try running the "force cache update" option on the dashboard's other tasks menu. Wait ten seconds, then refresh/reload the page. 

- Cleaned up the number of packages installed by default
-- now, by default, autosnort only installs the necessary packages required to compile daq, libdnet, snort, and barnyard2 (with support to log to a remote database)
-- as such as new dialogue, asking if the user wishes to install a web interface onto the system has been added. If you are unsure what to do at this point, just select option '1', this will install apache and mysql servers for a full stand-alone sensor
-- otherwise, if you elect to not install a web interface, an EXPERIMENTAL (as in, NOT FULLY TESTED) option has been added that results in another dialogue further in the installation that allows the user to specify a remote system to log intrusion events to, *possibly* allowing for distrubuted sensor installs. If you say no to this, the script continues and warns you that the only other output options available to you are syslog (barebone sensor install) or no interface at all
- Child shell scripts now install the packages needed for their installations independant of the main shell script
-- again, this was for cleanup purposes and to reduce the attack surface.
- Several minor code and comment enhancements/cleanups
--thanks to DK1844 for some suggestions for enhancing autosnort!

Bug fixes:
- for the aanval child shell script added --no-check-certificate as a work-around to automatically grab the install package from aanval.com (https)
- for the pulled pork rule installation phase, added support to download snortrules packages for older versions of snort in the event that the rules for the version before the current version have not been made free to registered rule users yet.
- fixed a bug in the remote database configuration portion of the script that turned into a mess of an infinite loop.


autosnort-debian-04-21-2013.sh

Release Notes:

- Added support for output interface BASE and syslog_full format

-- The installation of BASE is very straightforward
-- Upon system reboot navigate to http://[ip address]/base to begin the setup
-- page 1 verifies that requisite packages are in place
-- when asked where adodb is located, enter "/usr/share/php/adodb"
-- when asked for credentials for the database and its location:
database name: snort
database host: localhost
database port: (leave blank or enter 3306)
database username: snort
database passwrd: [snort database user's password]
-- on the authentication page, if you want users to enter a password to review events, do so. Otherwise, click continue.
-- on the next page, click the "BASE AG" button for BASE to modify the database.

- Regarding syslog_full format
-- this is NOT fully tested. It has only been tested against Splunk. As time goes on, I may test with other SIEMS (e.g. graylog2 or just raw syslog) as required or requested (submit a feature request via github!)
-- Ensure 514/udp outbound is open on the sensor's management interface
-- Ensure 514/udp inbound is open on the SIEM
-- you can use tcpdump (tcpdump -i eth0 port 514) to verify that events are being sent out, as well as on the SIEM to see if events are making it to the SIEM
- if syslog_full format is chosen, output to mysql is disabled.

- The script has been modified to generate a new barnyard2.conf on the fly as opposed to using sed to modify the .conf file provided with the source. The barnyard2.conf file provided with barnyard2's source code is copied to /usr/local/snort/etc as barnyard2.conf.orig in the event it is needed in the future (e.g. modify output settings, etc.)
- Of course, the output interface menu has been modified to include BASE and syslog_full

autosnort-debian-04-14-2013.sh

Release Notes:

- No new functionality added

Bug Fixes:

- Fixed a bug observed with Barnyard 2. Apparently specifying an argument on the command line as well as via its .conf file causes Barnyard2 to crash with a FATAL ERROR stating you can't do this anymore. Not sure when this change was implemented, but I've modified this version of autosnort script to reflect this change. As a direct result of this, the sid-msg.map and gen-msg.map files are specified via the barnyard2.conf file and not via the command line -S and -G options any longer.

Other Notes:

- CentOS users have been enjoying a new snortbarn script for a little while now, Well now it's time for Debian users to enjoy an init script for snort and barnyard2.
-- The snortbarn script has a variables section to change the init script to suit your Autosnort (or non Autosnort) snort installation
-- Save the snortbarn script, copy it to /etc/init.d and make it executable.
-- Remove the ifconfig snort and barnyard2 entries from rc.local
-- Run the command insserv -f -v snortbarn to insert init scripts for snortbarn
-- Enjoy.
-- The Debian snortbarn script supports start, stop and restart functions.

autosnort-debian-03-30-2013.sh

Release notes:

- This new release of autosnort for Debian introduces support for an additional web front-end: Tactical Flex's Aanval Console!

- Please note that for this release, autosnort does not yet support some of the more advanced snort-related features for Aanval just yet (such as rule and/or policy management). At this stage, this is just to register the snort functionality with Aanval and get intrusion events reported to the Aanval Console.

- With this release I'm trying to make autosnort a bit more modular, instead of having it be one gigantic, monolithic shell script. This was a design choice I made to make it easier to troubleshoot issues with Autosnort and add on functionality. The first things I decided to break off from the main script was installation of different front ends. You'll notice there are two smaller shell scripts that accompany the main shell script:

--aanval-debian.sh // installs aanval
--snortreport-debian.sh // installs snort report

- Place these scripts in root's home directory (/root) along with the main autosnort script. /root is where the main script expects to find the child scripts. If the child scripts aren't there, the web front-end installation section of autosnort will fail to run until the child shell script is present in /root.

Aanval Post-Setup notes:

- It is highly advised that you reboot your system before continuing to the aanval web console to configure Aanval to talk to snort. I ran into a problem prior to rebooting where the aanval console would not recognize that the php mysql module did exist and was loaded until the system was rebooted.

- During the initial setup, aanval will want to know the name of the aanvaldb user and password.

	Username:snort
	Password:password you gave the snort database user during the autosnort installation

- Aanval has a set of processes that are used to bring events over from the snort database that barnyard2 will dump to, and bring them over to the aanvaldb that aanval reads from. The console interface will let you know if they are not running. To start them:
	1. Navigate to /var/www/aanval/apps
	2. Run idsBackground.pl -start
	
- I plan on adding an rc.local entry that will do this for you in the near future!

- In order for Aanval to manage events for your snort sensor you need to enable it on the aanval console. click the gear symbol in the lower corner of the web interface. This will bring you to a page called configuration. Click the "Settings" option under the "Snort Module" section. On the next page, check the enabled checkbox and enter the information for the snort database:

	1. Database name: snort
	2. Database hostname: localhost
	3. Database username: snort
	4. Database password: the password you assigned to the snort database user during autosnort installation
	5. click update.
	6. Click on the gear symbol in the lower corner again. Under the "Snort Module" section, this time select "Sensor Configuration"
	7. Click the enabled checkbox
	8. Fill out the other fields except the SMT ID as you see fit (you can leave fields blank if you want)
	9. Click update
	10. The page will re-load with a new checkbox for "User Permissions". Select this checkbox. The page will automatically reload
	11. Click the house symbol at the top of the page to return to the Aanval home page.
	
- It may take a few minute for intrusion events to show up on the aanval interface. Be patient, they'll start coming in shortly!

- For more guidance and information specific to aanval, pay the folks at Tactical FLEX a visit at aanval.com. Community support site and Aanval wiki are free to use and will provide you with everything I used to integrate Aanval into Autosnort.

other notes:

- Previous releases are available in the Previous_Rel directory, in the event that you find a bug with the current release and cannot wait for a fix to be made available.


1/3/2013: 

- pulled pork integration has been integrated into the debian autosnort script. 

- The biggest change in functionality you will notice is the pulled pork integration using pulled pork for rule management has a few requirements:

	1. You need to have a valid oink code. register on snort.org as a registered user, or if you have a VRT subscription, the VRT oink code you have should work fine
	2. You'll need http and https access to labs.snort.org and snort.org to download snort.conf (from labs.snort.org) and rules via pulled pork (snort.org)
	
- Be aware that if there is a new release of snort, and you do not have a VRT subscription, you will be limited to snort rules for the previous version of snort for 30 days. That means that only the text-based rules will work. SO RULES DESIGNED FOR A PREVIOUS VERSION OF SNORT WILL NOT WORK ON A NEWER SNORT RELEASE.

- If you choose to have autosnort download rules for the previous snort version via pulled pork, pulled pork is configured to process text rules ONLY to prevent Shared Object compatibility problems.

other notes:

- A lot of fault tolerance improvements in the code. In most places requiring user input, the script will no longer blindly plow forward if you give it invalid input. If you give the script something invalid or something that doesn't make sense the script loops through the routine until you give it input that makes sense.


Hello folks, this is the readme specific to the Debian edition of autosnort.

- For the most part, this is a complete clone of the autosnort debian script except with changes where required (e.g. version checking) and a couple of minor changes:

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