Autosnort

Triptych Security - Tony Robinson/da_667
twitter: @da_667
email: deusexmachina667 [at] gmail [dot] com


Autosnort is a shell script that leaves the user with a fully functional snort installation, with the latest versions of snort and intrusion event reviewing tools available. More specifically, autosnort will:

1. Install the latest version of snort, daq, libdnet, barnyard2 and the packages required to configure, compile and install them all, from source in addition to operating system updates and packages required for compiling and operating these tools

2. Provides advanced users the ability to manually install a VRT rule tarball, or use Pulledpork to install the VRT snort rules, the open-source community rules, and the VRT labs ip blacklist for the IP reputation preprocessor. Autosnort does all the heavy lifting required for initial rule configuration and set up. The default rule set is the VRT "Security over Connectivity" ruleset.

3. Install an intrusion event review interface of the user's choice, download the necessary packages for it, and configure it all in one fell swoop. Interface choices currently include:
--Symmetrix Technologies' SnortReport web interface
--Threat Stack's Snorby web interface
--Tactical Flex's Aanval web interface
--Base web interface (Currently hosted by Source Forge)
--syslog_full messages to port 514/udp (think: barebones sensor install or SIEM integration)
--(EXPERIMENTAL) configure barnyard2 to log to a remote database (think: distributed installation)
--install no interface at all 


Here are the requirements:

1. An internet connection -- autosnort downloads os repo packages required to install everything over the internet (exception: autosnort offline!), so internet access is a must!

2. root/sudo access -- several system-wide changes are made with autosnort. as such, root privelges are required.

3. A minimum of two network interfaces is recommended. autosnort dedicates one interface solely to sniffing traffic. This interface will NOT respond to any service requests at all. As such, a second physical interface is needed to remotely administer the sensor.

4.SSH/Secure remote access to the system for remote system administration is very highly recommended, but not absolutely necessary, if you have console access.

The shell script is meticulously commented in order to fully explain what it is the script does exactly and document all packages and changes made to the system.

To run autosnort you will need to do the following:

1. copy the autosnort-[os]-[date].sh to the /root directory of your operating system [e.g. autosnort-ubuntu-05-18-2013.sh]

2. copy the [webinterface]-[os].sh script to the /root directory [e.g. snorby-ubuntu.sh]

3. run the autosnort-[os]-[date].sh script as the root user [e.g. as root, type "bash /root/autosnort-[os]-[date].sh" or "cd /root && chmod u+x autosnort-[os]-[date].sh && ./autosnort-[os]-[date].sh" or run either of the following via sudo...]

4. The script gives you the option of rebooting your system after the installation is complete. In some cases it's necessary for some web interface components to register or work correctly, in all cases I highly recommend rebooting your system. Upon reboot snort, barnyard, and the interface of your choice should be running flawlessly.

snort is installed under: /usr/local/snort

barnyard2 is installed under: /usr/local/bin

pulledpork (if used) is installed under /usr/src

web interfaces are installed under: /var/www (ubuntu, debian) or /var/www/html (centOS)


I chose to write autosnort as an alternative to other IDS solutions such as security onion, insta-snorby, etc. as a way for me to enhance my bash-fu, while granting snort users of any proficiency the capability to install the latest and greatest version of snort and its components as soon as they become available with as little muss and fuss as possible, with only the interfaces or features they desired, on an operating system they want to use.

All this being said.. I am _NOT_ claiming that autosnort is better than any other IDS solution you are using at the present. Open-source solutions are all about free choice, simply consider Autosnort another option when you need to stand up an IDS sensor quickly and easily.

If you feel that this script is not as robust as it can be, lacks features that would be desireable to IDS/IPS users, or does not implement functionality in an intuitive manner, I welcome all criticisms, bugs, feature requests, code contributions, and/or anything else you can throw at me. Also cash.

Currently, autosnort supports Ubuntu, Debian, CentOS and Backtrack5(r3 -- being phased out; with support for Kali coming soon -- Really, I mean it..) 32 and 64-bit. I can include support for more operating systems, If I am give feature requests/enhancements to do so... the direction of this project is completely up to the users who utilize it.


Other features that I am working on that have not yet been fully implemented include:


1. OFFICIAL, non-experimental support for distributed installs (e.g. modify the script to install snort and barnyard2, then point barnyard2 to a management system running  the front-end of your choice and the mysql server.)

2. Support for inline installations

3. Reconfiguration of apache to allow viewing of web interface over SSL only

4. distributed sensor installations communicate over SSL only.


I think this is enough of a list combined with getting the script to run on other distros to keep me busy for a long time. If there's functionality you would see added, by all means, offer your suggestions, my contact information is up top.


Thanks for your time!
