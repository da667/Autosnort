This is a special release of autosnort meant to be used for students in the Building Virtual Labs class and/or readers of Building Virtual Machine Labs: A Hands-On Guide book. This script performs the following tasks:

-Downloads required pre-reqs to run and compile snort
-Compiles snort with the --enable-sourcefire config option. Snort is installed to /opt/snort/bin/snort, while snort's supporting files are installed to /opt/snort/etc
-Downloads pulledpork.pl to /usr/src/pulledpork, and creates a stripped-down pulledpork.conf in /usr/src/pulledpork/etc. This is used to download the latest TALOS rules (with a valid register/subscriber oinkcode)
-Configures snort for inline mode operation via af-packet bridging
-Installes the "snortd" init script for service persistence
-Very stripped-down: This installer does NOT install barnyard2, or include any options to install an interface of any sort. This installs pulledpork, and snort with some persistence, and that's it.
-Inline mode operation: This installer requires a minimum of 3 network interfaces to work properly. Two interfaces will be placed into inline mode via the AFPACKET DAQ. ARP will be disabled on these interfaces, meaning that your system will NOT respond to any traffic sent to these interfaces. By default, the script will attempt to bridge the eth1 and eth2 interfaces. You can specify different interface names to be bridged in the full_autosnort.conf file
-Pulledpork.pl is installed and used to download the initial ruleset for snort. you will need to register a free account on snort.org (or pay for a rule subscription), and copy your oinkcode into the full_autosnort.conf file for this script to work properly

1. pull https://github.com/da667/Autosnort
2. cd Autosnort/Autosnort-Ubuntu/AVATAR
3. modify full_autosnort.conf (e.g. interface names, base installation directory, etc.). At an absolute minimum you MUST input a valid snort.org Oink Code
4. As root, (or via "sudo") run autosnort-ubuntu-AVATAR.sh
5. On successful reboot, snort should be running (try ps -ef | grep snort to check)
6. snortd service should be registered, you can use 'service snortd (start|stop|status|restart) to control the snort process.
7. Errors? Problems? Check the file /var/log/autosnort_install.log for troubleshooting.

Thanks,

da_667

12-29-18
-Users reported users that the script no longer works, complaining about a libluajit dependency. apparently the Snort team has opted to included openappID as a part of the --enable-sourcefire compile option that the autosnort script has used for years now.
--Script has been updated to download a couple of dependencies in order to be able to run openappID -- libnghttp2, libluajit, libssl-dev, pkg-config and a few others. All you need to know is that Snort should configure and compile with no errors, at least as of 2.9.12
---please note that this script doesn't download fingerprints for openappID, nor does it enable the openappId preprocessor in snort.conf. If you're interested in learning how to do that, that is an exercise that will be left to you to try out. Have fun storming the castle!
--Had to write in a config change very similar to the autosuricata config change we wrote for ubuntu 18.04 users recently: backing up the apt sources.list file, clobber the existing sources.list, and regenerate a new sources.list file that enables the universe repos for ubuntu 18.04. This is because 18.04 doesn't enable universe by default, and libluajit is a universe repo package.
-discovered an issue where pulledpork was actually dropping any rules into the /opt/snort/rules/snort.rules file, claiming 0 new rules. Added the "-P" option to pulledpork execution, to force pulledpork to process rules, even if it /thinks/ there are no new rules.
8-3-18
-This script is now compatible with Ubuntu 18.04, in addition to Ubuntu 16.04
-Fixed the pulledpork.conf this script generates. It now reflects the current version of pulledpork.pl (0.7.4)
10-18-2017
- Fixed a bug in the "snorttar" variable regex. To make a long story short, Cisco changed filename version formats for the Snort tarball on their site, and that broke various things in the script, like downloading the latest Snort tarball, and downloading the right rules for the current snort version via pulledpork. This should be un-borked now.
- Removed attempts to download older snort rule tarballs via pulledpork. Cisco now allows Registered Snort users (e.g. the free rule users) to download a rule tarball compatible with the latest snort release (that means compatible Shared Object rules). The only difference is that the rules are /still/ 30 days behind the subscribed users. Such is life.