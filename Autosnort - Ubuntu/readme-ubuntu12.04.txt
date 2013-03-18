Hello AS users, this is a readme specifically for the Ubuntu edition of autosnort.

This script was the templete for the BT5, Debian and CentOS editions, so practically everything in the readme applies directly to this script as well as the others and their additional readme files.

This script is fully support on Ubuntu 12.04 and 12.10 and has NOT been test on other versions of Ubuntu. Let me know if it works OR if you run into problems!

It is advised that you run this script out of the /root directory. Copy the main autosnort script and the web interface script of your choice to /root, then run the main autosnort script out of /root.

01/02/13: added pulledpork integration. If you choose pulled pork during the rule installation phase, autosnort will pull down necessary packages and software for pulled pork. You must provide autosnort an oink code to process rules from snort.org. The registered user and subscriber oink codes will BOTH work here.

Be aware that if there is a new release of snort, and you do not have a VRT subscription, you will be limited to snort rules for the previous version of snort for 30 days. That means that only the text-based rules will work. SO RULES DESIGNED FOR A PREVIOUS VERSION OF SNORT WILL NOT WORK ON A NEWER SNORT RELEASE.

If you download rules for the previous snort version, pulled pork is configured to process text rules only to prevent Shared Object compatibility problems.

3/17/13: added in User Interface choices. Users of Autosnort should now have a choice between Snort Report and Aanval as web interfaces for displaying intrusion events.

As a result, I have began to modularize Autosnort. Each of the interface installation options is a shell script all its own. This was a design decision to make the script more manageable and easier to debug as I add support for more interfaces and more options; Instead of one monolithic script to trace through, I can trace problems down to individual module scripts to make things easier to troubleshoot.

In order for Autosnort to proceed properly,  the main autosnort script, aanval.sh and/or snortreport.sh (whichever interface you wish to install) must all be in the /root directory for the script to work successfully.. I plan on fixing this in the future, but bear with it for now.

This is a new release. While I have tested it in my test environment I cannot reproduce every possible problem. So if you run into bugs, please report them -- It helps you, me and the rest of the Snort community when you do. If the latest version of the Autosnort script does NOT work for you, and you cannot wait for me to fix it, try using the previous version of the script, located in the Prev_Rel directory as an alternative. 

Aanval Post-Setup notes:

 

- It is highly advised that you reboot your system before continuing to the aanval console to continue the installation via the web interface. I ran into a problem prior to rebooting where the aanval console would not recognize that the php mysql module did exist and was loaded until the system was rebooted.

 

- During the initial setup, aanval will want to know the name of the aanvaldb user and password.

 

Username:snort
Password:password you gave the snort database user during the autosnort installation

- Aanval has a set of processes that are used to bring events over from the snort database that barnyard2 will dump to, and bring them over to the aanvaldb that aanval reads from. The console interface will let you know if they are not running. To start them, navigate to /var/www/aanval/apps and run idsBackground.pl -start --- I plan on adding an rc.local entry that will do this for you in the near future!

- In order for Aanval to manage events for your snort sensor you need to enable it on the aanval console. click the gear symbol in the lower corner of the web interface. This will bring you to a page called configuration. Click the "Settings" option under the "Snort" section. On the next page, check the enabled checkbox and enter the information for the snort database:

database name: snort

database hostname: localhost

database username: snort

database password: the password you assigned to the snort database user during autosnort installation

then click update. It may take a few minute for intrusion events to show up on the aanval interface. Be patient, they'll start coming in shortly!

- At this time, Autosnort does not support the sensor configuration options that Aanval includes. This is a limitation on my part; I need to figure out where Aanval expects to find the rule files, snort.conf and other configuration files before this will be possible!

- For more guidance and information specific to aanval, pay the folks at Tactical FLEX a visit at aanval.com



As always, reachable via:

twitter: @da_667
e-mail: deusexmachina667@gmail.com

Thank you for using Autosnort! Tell your friends!