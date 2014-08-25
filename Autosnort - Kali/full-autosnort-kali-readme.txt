###############################
Installation Instructions
###############################

1. Acquire master.zip via the autosnort github web page, or run git clone to clone the Autosnort repository. cd into "Autosnort - Kali".
2. Review the configuration file, full_autosnort.conf. READ IT, UNDERSTAND THE CONFIGURATION OPTIONS. By default, full-autosnort will install a fully, standalone IDS sensor with Snorby as the IDS event review interface. At a minimum, you will NEED supply the follow for the configuration file:
root_mysql_pass
snort_mysql_pass
o_code
3. If you do not want to install snorby, there are a variety of other configurations avialable, as well as other interface choices:
snortreport
BASE
aanval
snorby
remote syslog
remote database
no interface (just dump to unified2)
Review the configuration file and fill it out to meet your installation goals.
4. The full-autosnort-kali-mm-dd-yyyy.sh script can be executed from practically any directory on the system, so long as the following criteria is met:
-full_autosnort.conf MUST be in the same directory you will be executing full-autosnort-kali-mm-dd-yyyy.sh
-the installation script for alternative IDS event choices (aside from remote database, or no interface install) MUST be in the same directory as full_autosnort.conf and full-autosnort-kali-mm-dd-yyyy.sh (by default, these criteria are all met.)
5. Run the full-autosnort-kali-mm-dd-yyyy.sh script with root permissions:
as root:
bash full-autosnort-kali-mm-dd-yyyy.sh
alternatively:
cd chmod u+x full-autosnort-kali-mm-dd-yyyy.sh;./full-autosnort-kali-mm-dd-yyyy.sh
via sudo:
sudo bash full-autosnort-kali-mm-dd-yyyy.sh
OR
sudo chmod u+x full-autosnort-kali-mm-dd-yyyy.sh;sudo ./full-autosnort-kali-mm-dd-yyyy.sh
5. The script should run automatically, giving you indicators as to what it is doing along the way. If there are errors or problems, the script should exit. The script logs just about every command executed in /var/log in one of the following files:
-/var/log/autosnort_install.log (the main autosnort script)
-/var/log/aanval_install.log (the aanval install script)
-/var/log/base_install.log (the BASE install script)
-/var/log/snorby_install.log (the snorby install script)
-/var/log/sr_install.log (the snort report install script)
Read through these files (if they exist) for errors. If you do not understand why the script failed, contact me for assistance. Contact information below.

##############################
full-autosnort-kali Release Notes
##############################
Current Release: full-autosnort-kali-08-25-2014

killing bugs and other things.

Bug Fixes:

- wget to snort.org would NOT work properly for some unknown reason. Attempts to wget snort.org would result in a 302 redirect to 127.0.0.1. Escalated to snort.org and snort-users mailing list. Ended up discovering that changing the URL from snort.org to www.snort.org resolves this issue handily, and is the primary reason for this script update.

Thank you to @JakeKing and @Snauzage for your patience and notification regarding the issue
as well as c0deMike and darkshade9 on github for pointing out the issue. I appreciate all reports on issues and aim to please my users as best I can.

##################
Previous Releases
##################
full-autosnort-kali-07-27-2014

Codename:FULL AUTO

This is an initial release for full-autosnort. As it is with most things, pentesters and security researchers usually get the coolest toys first. They're also usually the loudest if there are problems with a tool you provide them. I'm hoping to rely on these facts to spot bugs in this pilot release before I push fully automated deployment scripts to other operating systems.

-This is the initial release for full-autosnort-kali, as well as the auto scripts for IDS console installation. Please report ANY problems!


as always, I can be contacted via twitter:
@da_667

or via e-mail:
deusexmachina667@gmail.com

Regards,

DA_667