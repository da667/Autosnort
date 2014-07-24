Autosnort

Tony Robinson/da_667
twitter: @da_667
email: deusexmachina667 [at] gmail [dot] com


Autosnort is a series of bash shell scripts designed to install a fully functional, fully updated stand-alone snort sensor with an IDS event review console of your choice, on a variety of Linux distributions. The script is very meticulously commented in order for users to fully understand all the changes the script performs on a given system. That way if a user wants to make their own customizations, or gain a better understanding of the install process, that information is present.

I chose to write Autosnort as an alternative to other IDS solutions such as security onion, insta-snorby, etc. as a way for me to learn shell scripting a bit better, while granting snort users of any proficiency the capability to install the latest and greatest version of snort and its components as soon as they become available with as little muss and fuss as possible -- with only the interfaces or features they desired, on an operating system they want to use. As it stands right now, Autosnort supports Ubuntu 12.04+ (and its derivatives), Debian (6+ and it's derivatives), and CentOS (6+ and it's derivatives [including RHEL]), with support for additional operating systems to be added as requested.

All this being said.. I am _NOT_ claiming that Autosnort is better than any other IDS solution. Open-source is all about freedom of choice, simply consider Autosnort another option when you need to stand up an IDS sensor quickly and easily.

If you feel that this script is not as robust as it can be, is missing key features, or does not implement functionality in an intuitive manner, I welcome all criticisms, bugs, feature requests, code contributions, and/or anything else you can throw at me. Also cash. Thanks for your time!


Autosnort will:

1. Install the latest versions of Snort, Barnyard2, DAQ (Data Acquisition) Libraries as well as any other required repositories and pre-reqs for install all of Snort's components.

2. Automatically downloads pulled pork and uses it to pull down the latest available rules for your version of Snort, so long as you have a valid Oink Code -- Doesn't matter if it's a registered user or VRT subscription Oink Code.

3. Gives the user a choice between a variety of IDS event console installation choices. Autosnort handles installation of pre-req packages, file configuration, as well as configuring apache to serve Web-Based IDS event consoles over HTTPS. You may choose among the following:

--Symmetrix Technologies' SnortReport web interface
--Threat Stack's Snorby web interface
--Tactical Flex's Aanval web interface
--BASE web interface (Currently hosted by SourceForge)
--syslog_full messages to port 514/udp (think: barebones sensor install or SIEM integration)
--configure barnyard2 to log to a remote database (central console, distributed sensors)
--install no interface at all


Requirements:

1. An internet connection -- Autosnort downloads os repo packages required to install everything over the internet as well as system updates (exception: Autosnort offline!), so internet access is a must!

2. Root/sudo access -- several system-wide changes are made with Autosnort. as such, root privileges are required.

3. A minimum of two network interfaces is recommended. Autosnort dedicates one interface solely to sniffing traffic. This interface will NOT respond to any service requests at all. As such, a second physical interface is needed to remotely administer the sensor. If you cannot acquire a second network interface card, simply edit /etc/rc.local and remove the "-noarp" option from the ifconfig command in that file.

4.SSH/Secure remote access to the system for remote system administration is very highly recommended, but not absolutely necessary, if you have console access.

Here are the instructions to run the Autosnort:

1. copy the Autosnort-[os]-[date].sh to the /root directory of your operating system [e.g. Autosnort-ubuntu-07-21-2014.sh]

2. copy the [webinterface]-[os].sh script to the /root directory [e.g. snorby-ubuntu.sh]

3. run the Autosnort-[os]-[date].sh script as the root user [e.g. as root, type "bash /root/Autosnort-[os]-[date].sh" or "cd /root && chmod u+x Autosnort-[os]-[date].sh && ./Autosnort-[os]-[date].sh" or run either of the following via sudo...]

4. There are a series of prompts that the script will ask during execution. It should be very straight forward what the script is asking for (e.g. mysql password, oink code, etc.). Simply answer the questions as they come, and the script handles the rest.

5. The script gives you the option of rebooting your system after the installation is complete. In some cases it's necessary for some web interface components to register or work correctly. In all cases I highly recommend rebooting your system. Upon reboot snort, barnyard, and the interface of your choice should be running flawlessly.

snort is installed under: /usr/local/snort

barnyard2 is installed under: /usr/local/bin

pulledpork (if used) is installed under /usr/src

web interfaces are installed under: /var/www (ubuntu, debian) or /var/www/html (centOS/RHEL)

TO-DO List:

1. More complete support for distributed installs (e.g. mysql over SSL/STUNNEL)

2. Support for inline installations (afpacket, NFQ, pf_ring)
