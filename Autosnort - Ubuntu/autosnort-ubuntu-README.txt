###############################
Installation Instructions
###############################

1. Edit the full_autosnort.conf file to reflect your installation requirements. At a minimum you will need to provide a password for the ROOT mysql user and the SNORT mysql user and finally a valid oink code for snort.org. By default, the config file will install mysql, httpd, snorby, snort, barnyard2 and init/systemd scripts. Snort will run on eth1. If you wish to change the default settings, the configuration file has tons of comments to help you along the way.
2. Run autosnort-ubuntu-mm-dd-yyyy.sh script. By default, all of the files necessary to run autosnort are in the same directory. At a minimum, the script requires full_autosnort.conf, snortbarn (init script) and the interface install script (for example, autosnorby-ubuntu) to be in the SAME directory. By default, all the files required are in the same directory.
Note: If you are installing aanval, you will also need the aanvalbpu (init script) to be in the same directory as well.
3. Run the autosnort-ubuntu-mm-dd-yyyy.sh script:
as root:
bash autosnort-ubuntu-mm-dd-yyyy.sh
alternatively:
chmod u+x autosnort-ubuntu-mm-dd-yyyy.sh;./autosnort-ubuntu-mm-dd-yyyy.sh
via sudo:
sudo bash autosnort-ubuntu-mm-dd-yyyy.sh
4. The script should run completely without any user input. If there are any problems, the scripts log in the following locations:
/var/log/autosnort_install.log
/var/log/base_install.log
/var/log/snortreport_install.log
/var/log/snorby_install.log
/var/log/aanval_install.log

Contact deusexmachina667 at gmail dot com with a copy of any of the above log files and I'll do what I can to assist you.

Note: After the installation is complete, either secure the full_autosnort.conf file, or delete it to ensure the root and/or snort database user's passwords are secured.


##############################
autosnort-Ubuntu Release Notes
##############################
Codename:"Winter is Coming"

Massive updates all around!

Current Release:autosnort-ubuntu-11-02-2014.sh

autosnort-ubuntu changes:

- The Ubuntu release of autosnort (as well as all the other releases of autosnort) are now fully automated and driven by a configuration file (full_autosnort.conf). 
-- By default, the config will install snorby and snort will be configured to sniff on eth1.
-- The configuration file can be modified to have snort sniff on any interface, and install any output interface (snortreport, BASE, aanval, syslog_full, and/or nothing at all)
- The main autosnort script has been reconfigured to install an init script named "snortbarn"
-- this init script starts both snort and barnyard2 on boot.
-- If you wish to modify the ifconfig interface options for the snort interface (for instance, remove the no arp and no multicast options if you don't have a second dedicated sniffing interface for snort, or some other reason..) you can do so via the snortbarn init script.
- Much of the code was completely re-written and streamlined and a few solid feature requests were finally implemented.
- The pulledpork installation portion of the script installs a cronjob to install new rules once weekly on Sunday morning. (kudos to @Snauzage for the request!)
- Choosing to install a web interface now installs a stub virtual host to redirect all http requests to https. Previously, it was the web interface install scripts that did this, but I figured I would rather have the code written once, than written four times in each web interface install script.

all web interface scripts:
- Just like with the main script, everything has been streamlined and fully automated. The user should not have to answer any prompts. 

aanval script changes:
- an init script (aanvalbpu) has been created to handle starting aanval's background processors instead of relying on rc.local. Ensure this file is in the SAME directory as the other autosnort required/configuration files to ensure a successful aanval installation.

snortreport script changes:
-Symmetrix Technologies changed to what I believe is a wordpress-based site. This changed the download location for SnortReport (thanks to r3d91l from github for reporting this issue)

snorby script changes:
-apparently changing the wget to www.ruby-lang.org (from ruby-lang.org) for checking the latest ruby 1.9.x version fixes needing --no-check-certificate (It's like I'm using HTTPS again!) (Thanks to ssi0202 from github for the report)

syslog_full script changes:
- If you wish to configure autosnort to utilize syslog_full output, you will want to fill out the syslog_full portion of full_autosnort.conf, specifically sensor_name (set to the sensor's hostname by default) and syslog_server (the IP address of the syslog server you want to send syslog messages to)


Other notes:
- Ubuntu 14.04 uses apache 2.4. Apache 2.4 is crotchety about what you name your vhost files in /etc/apache2/sites-available, namely they all have to end in ".conf" for some arbitrary reason. I coded in an OS version check to work around this in the main script and properly back up the default apache2 files, and all ubuntu files simply end in ".conf" to work around this. No muss, no fuss. If you use a version of ubuntu that isn't 12.04 or 14.04, the script may still work. if It doesn't I can try to help you if you give me log files :D
- Autosnort can finally be ran outside of the "/root" directory. In order for the script to run correctly, these four things MUST be in the SAME directory, wherever you execute from:
-- the autosnort-centOS script
-- the snortbarn script
-- full_autosnort.conf
-- the web interface script you wish to install
-- IF you are installing aanval as your event review interface: You must also have the aanvalbpu init script in the same directory as well.

##################
Previous Releases
##################
autosnort-ubuntu-08-25-2014

annoying bug was annoying. *squash*

Bug Fixes:

- wget to snort.org would NOT work properly for some unknown reason. Attempts to wget snort.org would result in a 302 redirect to 127.0.0.1. Escalated to snort.org and snort-users mailing list. Ended up discovering that changing the URL from snort.org to www.snort.org resolves this issue handily, and is the primary reason for this script update.

Thank you to @JakeKing and @Snauzage for your patience and notification regarding the issue
as well as c0deMike and darkshade9 on github for pointing out the issue. I appreciate all reports on issues and aim to please my users as best I can.

autosnort-ubuntu-07-21-2014.sh

Codename: REMEMBRANCE I'll see you soon, I promise.

autosnort script changes:
--Finally have official, tested support for Ubuntu 14.04!
--If you elect to install a web server and mysql as a part of a web IDS console installation, the following changes are made:
--- /etc/apache2/sites-available/000-default.conf, /etc/apache2/sites-available/default-ssl.conf, and /etc/apache2/mods-available/ssl.conf are all moved/backed up to /etc/apache2/. A new default site virtual host and custom ssl site virtual host for each ids console is also generated. ssl.conf is moved in order to generate a new ssl.conf based off the qualys ssl scanner blog recommendations.
--- mod_rewrite and mod_ssl are both enabled to ensure support and enforcement of all IDS console traffic over SSL.
--- openssl generates a new private key and a new self-signed ssl certificate.

snorby script changes:
-- Determined that a few of the work-arounds that were required to install Snorby were no longer required, and the Snorby project never bothered telling anyone. Go figure. Installation is now a little bit faster and more streamlined, but it still takes the longest out of any web-based IDS console to install.

Bug Fixes:
--Snort.org underwent a facelift. Just like with the autosnort-centOS and debian scripts, the main script has been modified to where It can find the correct versions of snort, DAQ, and rule tarballs to download.


all web interface scripts:
--Made significant changes to the Virtual Host settings across all web interface installations. In order to fully support all web interfaces being served over SSL (HTTPS):
---A Virtual Host on port 80 redirects all HTTP requests to HTTPS via mod_rewrite (enforced encryption)
---All web interfaces had their virtual host moved to port 443 and should be perfectly compatible and fine with being served over SSL (https).
---Don't forget: If you run a firewall on your host, I would recommend opening port 80 and port 443 on your INPUT chain.
--Ubuntu 14.04 runs a version of apache that is VERY strict on virtual host files in /etc/apache2/sites-available. They MUST end in the extension ".conf" to be considered a valid virtual host file for a2ensite and a2dissite. To ensure compatibility with ubuntu 12.04 (doesn't care about the file extention) and 14.04 (strict file extension check), all web interface installs have a 000-default.conf and [interface_name]-ssl.conf virtual host file in /etc/apache2/sites-available that replace the default site and are enabled by the IDS console installation script.

other notes:
--Noticed that the Snorby script fails catastrophically if rubygems.org is down or unresponsive. the snorby_install.log in /var/log that gets made will leave a pretty blatant error message. In my case it was "503 rubygems.org back end at capacity." was the only clue I would get that things went awry. That and the script not executing functions after the gem installation properly due to missing gems. Bottom line: if you see a 503 error message in the installation logs, the problem is with rubygems.org. This is the price you pay when you deal with the devil (Ruby)

autosnort-ubuntu-03-31-2014.sh

So, this all started when a user notified me that gen-msg.map is no longer provided by rule tarballs, and as a result barnyard2 wouldn't start when installed by autosnort. I made a few changes to autosnort, so sit tight:

-autosnort-ubuntu script changes:

--removed the choice to install a VRT rule tarball from the filesystem. There are a few reasons for this:
1) the sid-msg.map included in the rule tarball doesn't contain everything needed. To generate a good, valid sid-msg.map the user would need to pull the perl script from oinkmaster to do this, or download pulled pork to do this for them anyway.
2) pulledpork is the recommended tool for managing snort rulesets, and has been for some amount of time. If users really want to enable all snort rules at once, pulledpork supports it via enablesid.conf and regex magic.
3) one less question to ask the users during setup, a long stretch of time where the script does what it needs to without user intervention... (hint of things to come..)

--Shared Object rule stubs are now included in the snort.rules file; so_rules.rules is no longer generated, but the so_rules directory is still there. Pulled Pork seperates out all Shared Object rules and organized them by category. to find your Shared Object rules, you can use the expressions "GID:3" to search by category, or the expression "engine shared" to list all shared object rules in the snort.rules file.
--Installed the necessary packages and made the necessary configuration changes to enable support for the NFQUEUE DAQ module; Autosnort Ubuntu should now be capable of supporting inline mode operation via both AFPACKET and NFQUEUE.

snorby script changes:
--Experienced a problem with rvm not downloading properly on Debian's wget because the certificate did not match the name of the site for rvm.io. As much as I detest --no-check-certificates (It's like I'm really using HTTP!). While this isn't a bug, it's more of an evil preventative action.

bug fixes:
--gen-msg.map is copied out of the /usr/src/$snortver/etc now (so the untarred directory of the version of snort the script downloads), since rule tarballs no longer contain gen-msg.map. Thanks to David Earp for notifying me of this issue.
--Snort 2.9.6.0 has been the production release of snort for a while now, long enough for me to actually verify that the Shared Object rule generation works. spoilers: it sort-of, but not really worked. This has been fixed.
---The SO files would be put into the right place, but the rule stubs (SO rule headers) wouldn't be generated. Pulledpork actually executes snort to generate the SO rule stubs, but because snort would read the config, not find things where the config said they were, would summarily barf with no rule stubs. Fixed the script by generating some dummy files before pulled pork is ran, and placing files where pulled pork expects them.

autosnort-ubuntu-02-01-2014.sh

Release Notes:

-A new year, a new autosnort release. I plan on releasing more than once yearly. I hope.

-autosnort-ubuntu script changes:
--Removed libpcap-ruby as a core package requirement. It isn't really needed, and as of Ubuntu 13.10, it is no longer even in the package repositories. Speaking of Ubuntu 13.10...
--Officially added support for Ubuntu 13.10
--Removed all instances of catting and piping to grep. Grep is capable of reading from files directly. Results in a slight efficiency increase
--Lots of minor changes to formatting and output given to the user to make things a little more user-friendly.
--pulledpork 0.7.0 has been out since September. This autosnort release has been upgraded to use pulledpork 0.7.0 and its new features
--- In addition to download the standard VRT rule release, pulledpork now downloads the Snort community rules, and the ip blacklist from the VRT labs site
--- pulledpork now generates sid-msg.map version 2 output
--Efficiency enhancement: The entire pulledpork routine only runs pulledpork once, making the rule setup phase significantly faster.

-snorby-ubuntu script changes:
--Lots of minor formatting changes
--Removed all instances of catting and piping to grep. Grep files directly now.
--the rvm (Ruby Version Manager) tool download and installation is now torn down a bit more cleanly.
--Changed permissions of database.yml and snorby_config.yml to be readable only by the www-data user (chmod 400). Everything still works just fine.
--Stopped using a2ensite and a2dissite: Apache 2.4 (Ubuntu 13.10+) seems to be very pickly about only allowing users to use a2ensite and a2dissite on files ending in ".conf" in /etc/apache2/sites-available. Not only that, even if you manually make the symlinks to sites-enabled yourself, Apache still won't recognize them. Renamed the /etc/apache2/sites-available/snorby file to snorby.conf, and now handle manually creation/removal of symlinks to sites-available. This is to ensure compatibility between older versions of Ubuntu using the older, more lenient versions of Apache, and the newest Ubuntu release, using Apache 2.4+

snortreport-ubuntu script changes:
--Very minor formatting changes
--Version 1.3.4 came out last september and I had no clue.
--No more short open tags. the snortreport-ubuntu script now removes every single last PHP short open tag without breaking anything else; Kind of a mandatory change, since Ubuntu 13.10 ships with the short_open_tag directive turned off in php.ini (Like it should be)
--Ensured compatibility with Ubuntu 12.X and 13.X versions by making a very minor change the sed line that modifies DocumentRoot
--Originally, the guide called for installation of jpgraph 1.27.1; a very old version of jpgraph. Autosnort now installs jpgraph 3.05, not quite as old, works just as well.
--The script now changes ownership for jpgraph and snortreport directories to be owned by www-data user and group (recursively)
--Changed file permissions on srconf.php. This file is now only readable by the www-data user. Everything still works just fine.

-syslog_full-ubuntu script changes:
--Minor formatting changes.
--Removed all "cat" commands for slightly more efficient shell script.

BASE-ubuntu and Aanval-ubuntu script changes
--Very minor formatting changes
--Ensured compatibility with Ubuntu 12.X and 13.X versions by making a very minor change the sed line that modifies DocumentRoot


Bug Fixes:
-autosnort-ubuntu:
--The OS version check at the start of the script was broken, not doing proper string comparison, so I fixed that.

snorby-ubuntu:
--The script show now properly download the latest ruby 1.9.x release, like it used to (fixes autosnort issue 19)
--Clone of snorby from github is now https only (Pre-cursor to fixing issue 19 on CentOS)
--Resolved autosnort issue 20 (snorby issue 323) via work-around that involves running bundler --no-deployment, followed by running bundler again with --deployment. It now takes bundler twice as long to perform its installation, but for now, this is the only viable work-around I've found until Mephux/Snorby team closes out this issue.

autosnort-ubuntu-08-18-2013.sh

- In an effort to make the mysql installs uniform between all autosnort builds and promote better security, I've made the mysql-server installation for Ubuntu and Debian silent, but now, just like with the centOS script, the /usr/bin/mysql_secure_installation script is ran as a part of autosnort. huzzah for better secured databases.


Bug Fixes:

- Apparently at some point between now and june, the passenger output directory for the mod_passenger.so binary changed the name of the directory from "libout" to "buildout". sigh. consistency is awesome, don't you agree? I only discovered this during testing passenger during the centOS testing process. 
- Same as the centOS script, found minor grammatical and syntactical errors littered all over the script. Found and fixed what I could.

autosnort-ubuntu-06-15-2013

- This version is almost a complete re-write of the script. Quite a few nicer/newer features added to this build:
-- Output from the script has been minimized where possible. Instead of writing all command output to the screen and "puking" all over the screen buffer, users are now presented with nice, metasploit like prompts, giving a basic run-down of what the script is doing (blue output), things the user needs to pay attention to (yellow output), and whether or not a given task in the script was successful (green is good, red is bad). Instead of outputting everything to the screen...
-- ...Autosnort and all of the child shell scripts now automatically log the entire installation. Log files are written to /var/log. The primary script logs to autosnort_install.log, the child scripts also log to /var/log and are named after their namesake web interface. (e.g. snorby would be named snorby_install.log). This is in an effort to make troubleshooting easier for users -- you can review the installation logs to see what went wrong, or if you contact me, you can send me a copy and I can try to troll through them to figure out what exploded
-- Related to the logging/output printing improvements, the print statements actually tell you where the different components are installed
-- Support for Ubuntu 13.04 officially added, backwards compatibility with Ubuntu 12.04 maintained
-- Did some magic with the apache default-site config file to make it to where, no matter what web interface you install, you can point your web browser to your sensor's IP address and be greeted by your web interface (Gritty details: for each web interface install, the apache default-site DocumentRoot gets set to where the web interface is the DocumentRoot -- for example, if you install aanval, you can browse to http://[address] and be immediately greeted by aanval.)
-- Added an option to create an entry for Aanval's BPU subsystem in rc.local to start them up on boot

Bug fixes:
- Fixed an annoying problem -- different versions of ubuntu store libmysqlclient.so, a necessary file for barnyard2, in a different place (Just like Debian.. Consistently inconsistent..). Made it to where the script does "find /usr/lib -name libmysqlclient.so" to tell the barnyard2 ./configure script where the libmysqlclient.so libriaries are located, instead of a bunch of if/thens.

autosnort-ubuntu-05-18-2013.sh

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

autosnort-ubuntu-04-21-2013.sh

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


autosnort-ubuntu-04-14-2013.sh

Release Notes:

- No major functionality changes

Bug Fixes:

- Resolved a problem with Autosnort regarding a recent change in Barnyard2. Barnyard 2.13 BETA2 introduced a change where it doesn't like it if you give it directives via the command line and via its configuration file anymore. It is specifically throwing an error because we tell barnyard 2 where to find the sid and gen-msg.map via the -S and -G options, as well as via the barnyard2.conf file. I've since removed the -S and -G options that autosnort used for barnyard2 to fix this issue.

Other Notes:
- ubuntu users have been enjoying a new snortbarn script for a little while now, Well now it's time for Ubuntu users to enjoy an init script for snort and barnyard2.
-- The snortbarn script has a variables section to change the init script to suit your Autosnort (or non Autosnort) snort installation
-- Save the snortbarn script, copy it to /etc/init.d and make it executable.
-- Remove the ifconfig snort and barnyard2 entries from rc.local
-- Run the command update-rc.d snortart to insert init script links for snortbarn
-- Enjoy.
-- The Ubuntu snortbarn script supports start, stop and restart functions.

autosnort-ubuntu-03-17-2013.sh

Release notes:

- This new release of autosnort for Ubuntu introduces support for an additional web front-end: Tactical Flex's Aanval Console!

- Please note that for this release, autosnort does not yet support some of the more advanced snort-related features for Aanval just yet (such as rule and/or policy management). At this stage, this is just to register the snort functionality with Aanval and get intrusion events reported to the Aanval Console.

- With this release I'm trying to make autosnort a bit more modular, instead of having it be one gigantic, monolithic shell script. This was a design choice I made to make it easier to troubleshoot issues with Autosnort and add on functionality. The first things I decided to break off from the main script was installation of different front ends. You'll notice there are two smaller shell scripts that accompany the main shell script:

--aanval-ubuntu.sh // installs aanval
--snortreport-ubuntu.sh // installs snort report

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

01/02/13:

- pulled pork integration has been integrated into the ubuntu autosnort script. 

- The biggest change in functionality you will notice is the pulled pork integration using pulled pork for rule management has a few requirements:

	1. You need to have a valid oink code. register on snort.org as a registered user, or if you have a VRT subscription, the VRT oink code you have should work fine
	2. You'll need http and https access to labs.snort.org and snort.org to download snort.conf (from labs.snort.org) and rules via pulled pork (snort.org)
	
- Be aware that if there is a new release of snort, and you do not have a VRT subscription, you will be limited to snort rules for the previous version of snort for 30 days. That means that only the text-based rules will work. SO RULES DESIGNED FOR A PREVIOUS VERSION OF SNORT WILL NOT WORK ON A NEWER SNORT RELEASE.

- If you choose to have autosnort download rules for the previous snort version via pulled pork, pulled pork is configured to process text rules ONLY to prevent Shared Object compatibility problems.

other notes:

- A lot of fault tolerance improvements in the code. In most places requiring user input, the script will no longer blindly plow forward if you give it invalid input. If you give the script something invalid or something that doesn't make sense the script loops through the routine until you give it input that makes sense.

Hello AS users, this is a readme specifically for the Ubuntu edition of autosnort.

- This script is fully supported on Ubuntu 12.04 and 12.10 and has NOT been test on other versions of Ubuntu. Let me know if it works OR if you run into problems!

as always, I can be contacted via twitter:
@da_667

or via e-mail:
deusexmachina667@gmail.com

Regards,

DA