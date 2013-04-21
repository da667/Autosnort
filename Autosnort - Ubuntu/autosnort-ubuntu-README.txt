##############################
autosnort-Ubuntu Release Notes
##############################

Current Release: autosnort-ubuntu-04-21-2013.sh

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

##################
Previous Releases
##################

autosnort-ubuntu-04-14-2013.sh

Release Notes:

- No major functionality changes

Bug Fixes:

- Resolved a problem with Autosnort regarding a recent change in Barnyard2. Barnyard 2.13 BETA2 introduced a change where it doesn't like it if you give it directives via the command line and via its configuration file anymore. It is specifically throwing an error because we tell barnyard 2 where to find the sid and gen-msg.map via the -S and -G options, as well as via the barnyard2.conf file. I've since removed the -S and -G options that autosnort used for barnyard2 to fix this issue.

Other Notes:
- CentOS users have been enjoying a new snortbarn script for a little while now, Well now it's time for Ubuntu users to enjoy an init script for snort and barnyard2.
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