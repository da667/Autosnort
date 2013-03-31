Documentation: Autosnort offline installer.
Supported Operating Systems: Ubuntu 12.04 32-bit and 64-bit, Debian 6 32-bit and 64-bit.

Before you begin, you will need the following:
1) root access on both your online AND offline systems
2) as-offline-stage1.sh
3) as-offline-stage2.sh
4) dpkgorder$OS$arch.txt, where $OS is Ubuntu or Debian and $arch is i686 (32-bit) or x86_64(64-bit)
5) create-sidmap.pl (special note: this script was NOT created by me. It is included as a part of the Oinkmaster suite. I am simply including it here as a part of the script as a convenience. If you wish for me to remote the create-sidmap.pl script, please contact me!)
6) VRT rules tarball
7) a system with internet access that is similar to the offline system you plan on running this script on. By similar I mean:
-Same Distro (Ubuntu 12.04)
-Same arch (x86_64 || i386)
-Same software version (e.g. 12.04)
-Either a base installed of the OS, or an install that is quite literally identical, so you don't end up with missing packages. Use clonezilla/acronis/DD or whatever to clone the OS if you have to here, or just use the stage 1 script on a base install of the operating system and architecture you plan to install the stage 2 script on.

Guide:

Step 1: Drop the stage 1 shell script, dpkgorder$OS$arch.txt, and create-sidmap.pl files on to your system with internet access. Make sure they are in the same directory!

Step 2: Run the stage 1 shell script. May take a bit of time, depending on your internet connection. The stage 1 script grabs all the packages required via apt-get,
but will NOT install them on this system, only download them for use on your offline system. Afterwards, the script will also download:

-jpgraph
-snortreport 1.3.3
-libdnet 1.12
-the latest version of snort and DAQ

Finally the script will tar it all up for you to sneakernet it to your offline system. At this point, you should have 2 tarballs:

-AS_offline_$OS$arch.tar.gz
--contains the .deb packages
--contains the .deb installer list file (dpkgorder$OS$arch.txt)
--contains the source tarballs for snort, daq, snortreport, jpgraph and libdnet
--contains create-sidmap.pl
-snortrules-snapshot-[snortver].tar.gz
--da rulez for snort.
--a basic snort.conf

note: the script only does the bare minimum to snort.conf to get it to work. modifying snort.conf is completely left to the user!

Step 3: Copy these two tarballs to whatever media you plan on using to copy it to the offline system. I recommend something with a capacity of at least 256mb (shouldn't be hard to find)

Step 4: Drop the stage 2 shellscript and both of the tarballs above on to your offline system, into the same directory

Step 5: Run the stage 2 shellscript and follow the prompts. the script will unpack and install everything. You should have a running IDS installation by the time we're done here.

Special considerations:
-If you want snort and barnyard to be daemonized (that is run automatically on boot), then you MUST have at least two network interfaces, or be willing to lose network connectivity on your single interface.

This is because the installer will configure the sniffing interface to come up automatically on boot -- without an ip address, in promiscuous mode and to ignore any and all arp traffic (promisc mode will
pick it up, but the interface will NOT respond to any ARP requests. period.) this is per IDS best practices: Dedicate 1 interface for sniffing, and a second interface for carrying traffic to interact with the IDS.

If you only have one interface on your IDS you will either need console access to the system to manage it, or select the option to NOT configure the interface on boot and/or daemonize snort/barnyard2.

Other recommendations:
run iptables on the interface that will be carrying traffic to interact with the IDS. snortreport runs on port 80, and traditionally, SSH is used to get a shell session on linux systems. usually this is port 22. In the future I may provide an iptables autoconfiguration script... but for now, I leave firewall configuration as an exercise to the user.