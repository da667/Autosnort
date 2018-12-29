###############################
Installation Instructions
###############################

1. Edit the full_autosnort.conf file to reflect your installation requirements. At a minimum you will need to provide a password for the ROOT mysql user and the SNORT mysql user and finally a valid oink code for snort.org. By default, the config file will install mysql, httpd, snorby, snort, barnyard2 and init/systemd scripts. Snort will run on eth1. If you wish to change the default settings, the configuration file has tons of comments to help you along the way.
2. Run autosnort-kali-mm-dd-yyyy.sh script. By default, all of the files necessary to run autosnort are in the same directory. At a minimum, the script requires full_autosnort.conf, snortbarn (init script) and the interface install script (for example, autosnorby-kali) to be in the SAME directory. By default, all the files required are in the same directory.
Note: If you are installing aanval, you will also need the aanvalbpu (init script) to be in the same directory as well.
3. Run the autosnort-kali-mm-dd-yyyy.sh script:
as root:
bash autosnort-kali-mm-dd-yyyy.sh
alternatively:
chmod u+x autosnort-kali-mm-dd-yyyy.sh;./autosnort-kali-mm-dd-yyyy.sh
via sudo:
sudo bash autosnort-kali-mm-dd-yyyy.sh
4. The script should run completely without any user input. If there are any problems, the scripts log in the following locations:
/var/log/autosnort_install.log
/var/log/base_install.log
/var/log/snortreport_install.log
/var/log/snorby_install.log
/var/log/aanval_install.log

Contact deusexmachina667 at gmail dot com with a copy of any of the above log files and I'll do what I can to assist you.

Note: After the installation is complete, either secure the full_autosnort.conf file, or delete it to ensure the root and/or snort database user's passwords are secured.

##############################
autosnort-kali Release Notes
##############################
Codename:"Winter is Coming"

Massive updates all around!

Current Release:autosnort-kali-11-02-2014.sh

autosnort-kali changes:

- The main autosnort script has been reconfigured to install an init script named "snortbarn"
-- this init script starts both snort and barnyard2 on boot.
-- If you wish to modify the ifconfig interface options for the snort interface (for instance, remove the no arp and no multicast options if you don't have a second dedicated sniffing interface for snort, or some other reason..) you can do so via the snortbarn init script.
- Much of the code was completely re-written and streamlined and a few solid feature requests were finally implemented.
- The pulledpork installation portion of the script installs a cronjob to install new rules once weekly on Sunday morning. (kudos to @Snauzage for the request!)
- Choosing to install a web interface now installs a stub virtual host to redirect all http requests to https. Previously, it was the web interface install scripts that did this, but I figured I would rather have the code written once, than written four times in each web interface install script.

all web interface scripts:
- Everything has been more fully streamlined, the code made a little more efficient.

aanval script changes:
- an init script (aanvalbpu) has been created to handle starting aanval's background processors instead of relying on rc.local. Ensure this file is in the SAME directory as the other autosnort required/configuration files to ensure a successful aanval installation.

snortreport script changes:
-Symmetrix Technologies changed to what I believe is a wordpress-based site. This changed the download location for SnortReport (thanks to r3d91l from github for reporting this issue)

snorby script changes:
-apparently changing the wget to www.ruby-lang.org (from ruby-lang.org) for checking the latest ruby 1.9.x version fixes needing --no-check-certificate (It's like I'm using HTTPS again!) (Thanks to ssi0202 from github for the report)


Other notes:
In order for Autosnort to run correctly, these four things MUST be in the SAME directory, wherever you execute from:
-- the autosnort-centOS script
-- the snortbarn script
-- full_autosnort.conf
-- the web interface script you wish to install
-- IF you are installing aanval as your event review interface: You must also have the aanvalbpu init script in the same directory as well.

##################
Previous Releases
##################
full-autosnort-kali-08-25-2014

killing bugs and other things.

Bug Fixes:

- wget to snort.org would NOT work properly for some unknown reason. Attempts to wget snort.org would result in a 302 redirect to 127.0.0.1. Escalated to snort.org and snort-users mailing list. Ended up discovering that changing the URL from snort.org to www.snort.org resolves this issue handily, and is the primary reason for this script update.

Thank you to @JakeKing and @Snauzage for your patience and notification regarding the issue
as well as c0deMike and darkshade9 on github for pointing out the issue. I appreciate all reports on issues and aim to please my users as best I can.

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