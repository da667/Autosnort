Autosnort v1

Triptych Security - Tony Robinson/da_667
twitter: @da_667
email: deusexmachina667@gmail.com


Q & A

Q:First and foremost, WHAT is Autosnort?

A: Autosnort is a shell script that will perform all of the dirty work of a snort install for you on Supported operating systems(32-bit or 64-bit). The script as it stands right now leaves you with:

1. A fresh install of Snort with --enable-sourcefire for performance profiling.
2. A fresh install of Barnyard 2
3. A fresh install of snortreport for you to retrieve intrusion events.

Q:What does the script do to my system?

A: Quite a number of things:

1. Downloads pre-requisite packages, services, and dependencies as a part of the installation process.
2. Sets up mysql and apache (including setting the root mysql user password and the snort mysql user's password)
2. Runs an apt-get update and upgrade to ensure the system is fully updated before doing the snort installation.
3. Polls snort.org/snort-downloads, determines latest stable source for DAQ and snort, then downloads and compiles them.
3. Handles creation of several directories, modification of configuration files, and creation of the unpriveleged snort user for the snort process to run as.
4. Adds entries to rc.local for snort and barnyard to run at boot against a chosen sniffing interface

Q:What software is downloaded and installed by Autosnort?

A:There are several software packages required to install snortreport, and compile snort and barnyard and depending on the distro you are running Autosnort on, they go by different names.

Here are the packages that are downloaded by autosnort (not including dependencies) by their general names:

Any and all System updates for your distro of choice
nmap 
nbtscan 
apache/httpd
php5 
php5-mysql 
php5-gd 
libpcap
libpcre 
g++ 
bison 
flex 
libpcap-ruby 
make 
autoconf 
libtool
mysql-server
libmysqlclient-dev
libdnet
Daq Libraries (The stable release, which, as of this writing is libdaq 1.1.1)
Snort (The stable release, which, as of this writing is snort 2.9.3.1)
Barnyard2
jpgraph
snortreport

If you want more granular details, the shell script is meticulously commented and is relatively easy to understand if you have any experience with shell scripting.

Q:What are system requirements for the script?

A:I've listed what access the script needs, what file(s) need to be present for the script to complete successfully as well as required user input below:


System/Access requirements:
1. you will need root access on the system you plan to install snort on, either that or "sudo" access to run this script as root. We do a lot of system administrative tasks to make this script work, so we need system priveleges. There's no way around this, unfortunately.
2. Internet access - we'll be downloading a lot of things from the wild wild web, so an internet connection is absolutely required
3. A VRT rules tarball from snort.org (subscriber rules or registered user rules will work fine) MUST BE PRESENT ON THE SYSTEM!
4. For all operating systems (with the exception of backtrack linux), two dedicated network interfaces are required if you plan on having your server act as a dedicated IDS -- one interface to carry ssh and http/s traffic to/from the sensor and a sniffing interface. the sniffing interface will NOT have an ip address, and will NOT respond to ARP or multicast traffic, effectively preventing anything on the network from talking to the sniffing interface. This is done for opsec reasons. IDS always have dedicated sniffing and dedicated management interfaces.

User input requirements (during the course of the script, you will need to supply the following):
1. During the mysqld install, you need to supply the root database user's password and confirm it.
2. During the installation of snortreport, the file srconf.php needs credentials for the database user, snort (Just a password and the confirmation). The snort mysql user is required to retrieve data from the mysql database and display it via the web interface, snortreport. I also give you the option of modifying srconf.php yourself if you don't want the script to do this portion. After installation, it will be located in /var/www/snortreport-1.3.3/srconf.php (Note: this step MUST be done for snortreport to run properly!)
3. The password and confirmation for the regular snort user (note: this user is SEPARATE from the snort database user, as in, I wouldn't use the same password twice!)
4. The directory (without the trailing "/") and
5. The name of the VRT rules tarball on the system (the script will NOT download the rules tarball for you -- pulled pork integration is an eventual goal, however.)
6. The interface you want snort to run on (modifies /etc/network/interfaces to bring the interface up at boot in promiscuous mode)
7. Whether or not you want snort and barnyard added to /etc/rc.local to run on system start
8. Whether or not you want the system rebooted at the end of the script (highly recommended)

as an example for items 4 and 5 above, if the file was: /home/da_667/snortrules-snapshot-2931.tar.gz you would do the following:

enter the directory: /home/da_667
enter the name of the rules file: snortrules-snapshot-2931.tar.gz

note:it is essential that you perform steps 4 and 5 with complete accuracy to ensure the snort rules are unpacked properly and moved to the proper location for snort to reference them while it is running.

Q: What happens if I don't give the script a VRT rules tarball or I mistyped the location of the rules tarball?

A: Snort will still install just fine, you just won't have any rules to run against. This can be fixed in a few ways:
	1) register to snort.org, download the tarball for the version of snort you have, re-run the entire script, and when prompted, point the script to the tarball.
	2) register on snort.org, download the rules tarball for the version of snort you have, copy lines 335 - 404 in the script, drop them into their own shell script and run it.
	3) manually perform the actions below:
		download a rules tarball from snort.org (sign up for a free account and download rules for your installed version
		to determine the version of snort you are running try the command: /usr/local/snort/bin/snort -V (gives you the version of snort installed)
		untar the rule snapshot you downloaded to /usr/local/snort:
		tar -xzvf snortrules-snapshot-xxxx.tar.gz -C /usr/local/snort
		for 32-bit backtrack, copy these files to /usr/local/snort/lib/snort_dynamicrules:
		cp /usr/local/snort/so_rules/precompiled/Ubuntu-10-4/i386/x.x.x.x/* /usr/local/snort/lib/snort_dynamicrules
		for 64-bit backtrack, copy these files instead:
		cp /usr/local/snort/so_rules/precompiled/Ubuntu-10-4/i386/x.x.x.x/* /usr/local/snort/lib/snort_dynamicrules
		run this command:
		touch /usr/local/snort/rules/white_list.rules && touch /usr/local/snort/rules/black_list.rules && ldconfig
		lines 373 - 404 (aka the remaining steps): modify /usr/local/snort/etc/snort.conf to suit your snort install and point to your .rules files (e.g. the files in /usr/local/snort/rules/)
I should probably have some sort of a test condition or validation that checks if the file user inputs exists, and this will likely occur in the future to protect against users fat fingering this part, but for right now, just be careful.

Q: Where does the script install snort, the snort.conf, rule files, etc. ?

A: The script installs snort to /usr/local/snort/. the actual snort binary is in /usr/local/snort/bin/snort. the snort.conf is in /usr/local/snort/etc/snort.conf. rules are located in /usr/local/snort/lib/snort_dynamicrules for SO rules, /usr/local/snort/rules for whitelist.rules, blacklist.rules and all GID 1 rules, and finally, /usr/local/snort/preproc_rules for preprocessor rules, if you desire to use them. unified 2 files and the waldo file for barnyard are located in /var/log/snort.

Q: I don't feel like typing out "/usr/local/snort/bin/snort" every time I want to run snort manually. This is going to get really annoying really fast.

A: By default, most Linux distros uses the BASH shell. Every bashes will read certain files from your home directory called rc or profile files. For BASH, these files are usually .bashrc, .bash_profile, among others. In the rc file, you can modify your system's PATH variable and include /usr/local/snort/bin in the PATH. if you want to do this quickly without logging out and/or logging in again, try this:
echo "export PATH=$PATH:/usr/local/snort/bin" >> ~/.bashrc && source ~/.bashrc -- this adds the line to .bashrc in root's home and tells your shell to reload it on the fly.

Q:*How* do I run this script

A: See below for details on how to get autosnort to run:

1. This script must be ran in the BASH shell specifically. There are two ways I recommend doing this:
	a. run chmod u+x autosnort-ubuntu-12.04.sh to make the script executable, then just type "./autosnort-ubuntu-12.04.sh" to run the script
	b. run the command "bash autosnort-ubuntu-12.04.sh" to call a BASH shell and make it run the script
	
Q: Why did you do it? Security Onion already exists and the documents are already out there.

A: First and foremost: THIS SCRIPT IS *NOT* A REPLACEMENT FOR SECURITY ONION! I did this as a way for snort users to be able to perform an installation from scratch and understand what is done to their system when snort is installed. The script can be modified by snort experts to build snort with other configure options, install different web frontends, integration with CM tools (i.e. Spacewalk/Puppet/Chef) and a host of other purposes.

Most importantly I chose to do this to bring snort to more people. A lot of critics of the snort project complain it is cumbersome to install, and not user friendly at all. This script is my attempt to prove to new users that setting up a new snort instance can be quick and painless.

Q: Why snortreport? Why not snorby or squil or [...]

A: This script is a proof of concept, and a baseline at this point. I chose snortreport for ease of install and readily available instructions via snort.org. As time moves on, I plan on adding options for the user to select a web front-end from a series of choices, or to just log alerts to syslog for collection to a SIEM.

Q: Dude, this script sucks. I could do this in half a day, in [insert scripting/programming language] blindfolded and with [x] functionality integrated.

A: So my script sucks. Tell me what sucks about it, and how you would improve it instead of straw man arguments against me.. I'm not much of a programmer obviously, so help me out --  not to benefit me but to benefit the Open-Source and snort community in general.

Q: What distros do you support? What distros do you plan on supporting

A: Currently I support all of the operating systems listed in the github repo. So, to date that is: Ubuntu 12.04LTS, CentOS 6.3, and Backtrack 5 r3. For all supported operating systems this includes 32-bit and 64-bit support. If you choose to run the script on an earlier version of a supported operating system, I *may* be able to assist you, but this is NOT any kind of a garantee. If you ran the script on an earlier version of a supported operating system and it works, please let me know! If you ran into problems, at least let me know what problems you came across!

Q: So you mentioned a bit of a to-do list. You're releasing a half-baked script?

A: No, put down the pitchforks. I want to add some enhancements and additional functionality to this script in addition to porting it to a few other distros. Some things I would like to do:

1. Add support for distributed installs (e.g. modify the script to install snort and barnyard2, then point barnyard2 to a management system running  the front-end of your choice and the mysql server.)

2. Add support for barebones installs (e.g. no mysql, no barnyard, no web front-end, syslog only, configure rsyslogd, syslogd, etc. to log to a log management solution).   Think: splunk, graylog 2 or another SIEM-- something where 'you don't want/need packets, you just want alerts.

3. Add support for installing other/different web frontends (think: a choice of installing snorby and/or BASE instead of just snort report)

4. Add support for inline installs either through guided installation and configuration of bridge-utils, or through proper use of the snort daq, maybe even pf_ring if I can figure out how the hell pf_ring works.

5. Add support for running pulled pork to create a base ruleset, instead of defaulting to all rules on.

I think this is enough of a list combined with getting the script to run on other distros to keep me busy for a long time. If there's functionality you would see added, by all means, offer your suggestions, my contact information is up top.


Thanks for your time!