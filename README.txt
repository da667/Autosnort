Autosnort v1

Triptych Security - Tony Robinson/da_667
twitter: @da_667
email: deusexmachina667@gmail.com


Q & A

Q:First and foremost, WHAT is Autosnort?

A: Autosnort is a shell script that will perform all of the dirty work of a snort install for you on Supported operating systems(32-bit or 64-bit). The script as it stands right now leaves you with:

1. A fresh install of Snort with --enable-sourcefire for performance profiling.
2. A fresh install of Barnyard 2
3. A fresh install of web interface of your choose (current choices include snortreport and aanval, with more to come)

Q:What does the script do to my system?

A: Quite a number of things:

1. Performs a system update before beginning the installation
2. Downloads all the required packages (and dependencies) via your operating system's package manager for a fully functional IDS and Web Interface installation
3. Compiles libdnet, daq, snort, and barnyard2 (and other tools as required) from source
4. Automatically downloads the latest rules for snort via pulled pork
5. Fully configures snort, httpd, mysql, barnyard2 and the web interface you choose to sniff network traffic and report events to your web interface

Q:What software is downloaded and installed by Autosnort?

A: It varies depending on the OS distribution you are using, and the functionality you choose to install.

Here are SOME of the packages that are downloaded by autosnort (not including dependencies) by their general names:

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
Daq Libraries
Snort
Barnyard2


If you want more granular details, the shell script is meticulously commented and is relatively easy to understand if you have any experience with shell scripting.

Q:What are system requirements for the script?

A:I've listed what access the script needs, what file(s) need to be present for the script to complete successfully as well as required user input below:


System/Access requirements:
1. you will need root access on the system you plan to install snort on, either that or "sudo" access to run this script as root. We do a lot of system administrative tasks to make this script work, so we need system priveleges. There's no way around this, unfortunately.
2. Internet access - we'll be downloading a lot of things from the wild wild web, so an internet connection is absolutely required. I would advise that you ensure that http, https and ftp access to the internet are allowed from the system you are attempting to configure with autosnort to ensure all required items can be downloaded successfully.

3. For all operating systems (with the exception of backtrack linux), two dedicated network interfaces are required if you plan on having your server act as a dedicated IDS -- one interface to carry ssh and http/s traffic to/from the sensor (aka your "management" interface) and a sniffing interface. the sniffing interface will NOT have an ip address, and will NOT respond to ARP or multicast traffic, effectively preventing anything on the network from talking to the sniffing interface. This is done for opsec reasons. An IDS should always have dedicated sniffing and dedicated management interfaces.


Q: Where does the script install snort, the snort.conf, rule files, etc. ?

A: The script installs snort to /usr/local/snort/. the actual snort binary is in /usr/local/snort/bin/snort. the snort.conf is in /usr/local/snort/etc/snort.conf. rules are located in /usr/local/snort/lib/snort_dynamicrules for SO rules, /usr/local/snort/rules for whitelist.rules, blacklist.rules and all GID 1 rules, and finally, /usr/local/snort/preproc_rules for preprocessor rules, if you desire to use them. unified 2 files and the waldo file for barnyard are located in /var/log/snort.

Q: I don't feel like typing out "/usr/local/snort/bin/snort" every time I want to run snort manually. This is going to get really annoying really fast.

A: By default, most Linux distros use the BASH shell. Every bashes will read certain files from your home directory called rc or profile files. For BASH, these files are usually .bashrc, .bash_profile, among others. In the rc file, you can modify your system's PATH variable and include /usr/local/snort/bin in the PATH. if you want to do this quickly without logging out and/or logging in again, try this:
echo "export PATH=$PATH:/usr/local/snort/bin" >> ~/.bashrc && source ~/.bashrc -- this adds the line to .bashrc in root's home and tells your shell to reload it on the fly.

alternatively, you can symlink the /usr/local/snort/bin/snort directory to a directory that is already on the PATH variable (/bin, /usr/sbin, etc.)

Q:*How* do I run this script

A: See below for details on how to get autosnort to run:

1. This script must be ran in the BASH shell specifically. There are two ways I recommend doing this:
	a. run chmod u+x autosnort-ubuntu-12.04.sh to make the script executable, then just type "./autosnort-ubuntu-12.04.sh" to run the script
	b. run the command "bash autosnort-ubuntu-12.04.sh" to call a BASH shell and make it run the script
	
Q: Why did you do it? Security Onion already exists and the documents are already out there.

A: First and foremost: THIS SCRIPT IS *NOT* A REPLACEMENT FOR SECURITY ONION! I did this as a way for snort users to be able to perform an installation from scratch and understand what is done to their system when snort is installed. The script can be modified by snort experts to build snort with other configure options, install different web frontends, integration with CM tools (i.e. Spacewalk/Puppet/Chef) and a host of other purposes.

Most importantly I chose to do this to bring snort to more people. A lot of critics of the snort project complain it is cumbersome to install, and not user friendly at all. This script is my attempt to prove to new users that setting up a new snort instance can be quick and painless.

Q: Why snortreport? Why not snorby or squil or [...]

A: I chose snortreport for ease of install and readily available instructions via snort.org. As time moves on, I plan on adding options for the user to select a web front-end from a series of choices, or to just log alerts to syslog for collection to a SIEM.

Q: Dude, this script sucks. I could do this in half a day, in [insert scripting/programming language] blindfolded and with [x] functionality integrated.

A: So my script sucks. Tell me what sucks about it, and how you would improve it instead of straw man arguments against me.. I'm not much of a programmer obviously, so help me out --  not to benefit me but to benefit the Open-Source and snort community in general.

Q: What distros do you support? What distros do you plan on supporting?

A: Currently I support all of the operating systems listed in the github repo. So, to date that is: Ubuntu 12.04+, CentOS 6.3+, Debian 6+ and Backtrack 5 r3. For all supported operating systems this includes 32-bit and 64-bit support. If you choose to run the script on an earlier version of a supported operating system, I *may* be able to assist you, but this is NOT any kind of a garantee. If you ran the script on an earlier version of a supported operating system and it works, please let me know! If you ran into problems, at least let me know what problems you came across!

Q: So you mentioned a bit of a to-do list. You're releasing a half-baked script?

A: No, put down the pitchforks. I want to add some enhancements and additional functionality to this script in addition to porting it to a few other distros. Some things I would like to do:

1. Add support for distributed installs (e.g. modify the script to install snort and barnyard2, then point barnyard2 to a management system running  the front-end of your choice and the mysql server.)

2. Add support for barebones installs (e.g. no mysql, no barnyard, no web front-end, syslog only, configure rsyslogd, syslogd, etc. to log to a log management solution).   Think: splunk, graylog 2 or another SIEM-- something where 'you don't want/need packets, you just want alerts.

3. Add support for installing other/different web frontends (think: a choice of installing snorby and/or BASE instead of just snort report)

4. Add support for inline installs either through guided installation and configuration of bridge-utils, or through proper use of the snort daq, maybe even pf_ring if I can figure out how the hell pf_ring works.


I think this is enough of a list combined with getting the script to run on other distros to keep me busy for a long time. If there's functionality you would see added, by all means, offer your suggestions, my contact information is up top.


Thanks for your time!