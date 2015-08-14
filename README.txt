Autosnort

Tony Robinson/da_667
twitter: @da_667
email: deusexmachina667 [at] gmail [dot] com


Autosnort is a series of bash shell scripts designed to install a fully functional, fully updated stand-alone snort sensor with an IDS event review console of your choice, on a variety of Linux distributions. The script is very meticulously commented in order for users to fully understand all the changes the script performs on a given system. That way if a user wants to make their own customizations, or gain a better understanding of the install process, that information is present.

I chose to write Autosnort as an alternative to other IDS solutions and also as a way for me to learn shell scripting a bit better, while granting snort users of any proficiency the capability to install the latest and greatest version of snort and its components as soon as they become available with as little muss and fuss as possible -- with only the interfaces or features they desired, on an operating system they want to use. As it stands right now, Autosnort supports the followin major linux distributions:

-Ubuntu 12.X and 14.x
-Debian 7.x and 8.x
-CentOS 6.x and 7.x
-Kali Linux

All this being said.. I am _NOT_ claiming that Autosnort is better than any other IDS solution. Open-source is all about freedom of choice, simply consider Autosnort another option when you need to stand up an IDS sensor quickly and easily.

If you feel that this script is not as robust as it can be, is missing key features, or does not implement functionality in an intuitive manner, I welcome all criticisms, bugs, feature requests, code contributions, and/or anything else you can throw at me. Also cash. Thanks for your time!


Autosnort will:

1. Install the latest versions of Snort, Barnyard2, DAQ (Data Acquisition) Libraries as well as any other required repositories and pre-reqs for all of Snort's components automatically with no user input required (beyond filling out a configuration file)

2. Automatically downloads pulled pork and uses it to pull down the latest available rules for your version of Snort, so long as you have a valid Oink Code -- Doesn't matter if it's a registered user or VRT subscription Oink Code. Don't have or know what an oink code is? Visit snort.org, register on their website and login. There's an option to display your oink code once you log in.

3. Can automatically install a variety of IDS event consoles/output mechanisms. Autosnort handles installation of pre-req packages for the console, configuration files, as well as configuring Apache to serve Web-Based IDS event consoles over HTTPS. You may choose among the following:

--Bammv's SGUIL project (sguild and snort_agent.tcl)
--Symmetrix Technologies' SnortReport web interface
--Threat Stack's Snorby web interface (NO LONGER SUPPORTED - Scripts still provided)
--Tactical Flex's Aanval web interface
--BASE web interface (Currently hosted by SourceForge)
--syslog_full messages to port 514/udp (think: barebones sensor install or SIEM integration)
--configure barnyard2 to log to a remote database (central console, distributed sensors)
--install no interface at all


Requirements:

1. An internet connection -- Autosnort downloads os repo packages required to install everything over the internet as well as system updates (exception: Autosnort offline!), so internet access is a must!

2. Root/sudo access -- several system-wide changes are made with Autosnort. as such, root privileges are required.

3. A minimum of two network interfaces is recommended. Autosnort dedicates one interface solely to sniffing traffic. This interface will NOT respond to any service requests at all, but this can easily be modified if you only have a single network interface. Get a second network card, if at all possible!

4.SSH/Secure remote access to the system for remote system administration is very highly recommended, but not absolutely necessary, if you have console access.

Here are the instructions to run the Autosnort:

1. Edit the full_autosnort.conf file to reflect your installation requirements. At a minimum you will need to provide a password for the ROOT mysql user and the SNORT mysql user and finally a valid oink code for snort.org. By default, the config file will install mysql, httpd, snorby, snort, barnyard2 and init/systemd scripts. Snort will run on eth1. If you wish to change the default settings, the configuration file has tons of comments to help you along the way. There is a separate full_autosnort.conf for each operating system.
2. Run autosnort-ubuntu-mm-dd-yyyy.sh script. By default, all of the files necessary to run autosnort are in the same directory. At a minimum, the script requires full_autosnort.conf, snortbarn (init/systemd script) and the interface install script (for example, autosnorby-ubuntu) to be in the SAME directory. By default, all the files required are in the same directory.
Note: If you are installing aanval, you will also need the aanvalbpu (init/systemd script) to be in the same directory as well. If you are installing sguil, the initsguil init script must also be present.
3. Run the autosnort-os-mm-dd-yyyy.sh script:
as root:
bash autosnort-os-mm-dd-yyyy.sh
alternatively:
chmod u+x autosnort-os-mm-dd-yyyy.sh;./autosnort-ubuntu-mm-dd-yyyy.sh
via sudo:
sudo bash autosnort-os-mm-dd-yyyy.sh
4. The script should run completely without any user input. If there are any problems, the scripts log command output in the following locations:
/var/log/autosnort_install.log
/var/log/base_install.log
/var/log/snortreport_install.log
/var/log/snorby_install.log
/var/log/aanval_install.log
/var/log/sguil_install.log
Contact me with a copy of any of the above log files and I'll do what I can to assist you.

Note: After the installation is complete, either secure the full_autosnort.conf file, or delete it to ensure the root and/or snort database user's passwords are secured.

snort is installed under: /opt/snort (by default, but can be user-modified)

barnyard2 is installed under: /usr/local/bin

pulledpork is installed under: /usr/src

snort.conf and barnyard2.conf are located under: /opt/snort/etc (by default, but is modified if snort's install directory is changed)

web interfaces are installed under: /var/www (ubuntu, debian, kali) or /var/www/html (centOS/RHEL)

TO-DO List:

1. More complete support for distributed installs (e.g. mysql over SSL/STUNNEL)

2. Support for inline installations (afpacket, NFQ, pf_ring)
