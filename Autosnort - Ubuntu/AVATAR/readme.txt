This is a special release of autosnort meant to be used as a part of Project:AVATAR. This installer script provides the following functionality:

-Downloads required pre-reqs to run and compile snort
-Compiles snort with the --enable-sourcefire config option. Snort is installed to /opt/snort/bin/snort, while snort's supporting files are installed to /opt/snort/etc
-Downloads pulledpork.pl to /usr/src/pulledpork, and creates a stripped-down pulledpork.conf in /usr/src/pulledpork/etc. This is used to download the latest TALOS rules (with a valid register/subscriber oinkcode)
-Configures snort for inline mode operation via af-packet bridging
-Installes the "snortd" init script for service persistence
-Very stripped-down: This installer does NOT install barnyard2, or include any options to install an interface of any sort. This installs pulledpork, and snort with some persistence, and that's it.
-Inline mode operation: This installer requires a minimum of 3 network interfaces to work properly. Two interfaces will be placed into inline mode via the AFPACKET DAQ. ARP will be disabled on these interfaces, meaning that your system will NOT respond to any traffic sent to these interfaces. By default, the script will attempt to bridge the eth1 and eth2 interfaces. You can specify different interface names to be bridged in the full_autosnort.conf file
-Pulledpork.pl is installed and used to download the initial ruleset for snort. you will need to register a free account on snort.org (or pay for a rule subscription), and copy your oinkcode into the full_autosnort.conf file for this script to work properly

This installer, and its supporting files are meant to be consumed with the book "Building Virtual Machine Labs: A Hands-On Guide, my massive virtual lab book.

Thanks,

da_667

8-3-18
-This script is now compatible with Ubuntu 18.04, in addition to Ubuntu 16.04
-Fixed the pulledpork.conf this script generates. It now reflects the current version of pulledpork.pl (0.7.4)
10-18-2017
- Fixed a bug in the "snorttar" variable regex. To make a long story short, Cisco changed filename version formats for the Snort tarball on their site, and that broke various things in the script, like downloading the latest Snort tarball, and downloading the right rules for the current snort version via pulledpork. This should be un-borked now.
- Removed attempts to download older snort rule tarballs via pulledpork. Cisco now allows Registered Snort users (e.g. the free rule users) to download a rule tarball compatible with the latest snort release (that means compatible Shared Object rules). The only difference is that the rules are /still/ 30 days behind the subscribed users. Such is life.