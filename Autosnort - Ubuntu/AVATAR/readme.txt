This is a special release of autosuricata meant to be used as a part of Project:AVATAR. This installer script provides the following functionality:

-Downloads required pre-reqs to run and compile suricata
-Downloads suricata-currrent and compiles it with the make install-full option (Which downloads and installs the ET Open ruleset). Suricata is installed to /usr/local/bin/suricata, while suricata's supporting files are installed to /usr/local/etc/suricata
-Downloads pulledpork.pl to /usr/src/pulledpork, and creates a stripped-down pulledpork.conf in /usr/src/pulledpork/etc
-Configures suricata for inline mode operation via af-packet bridging
-Installes the "suricatad" init script for service persistence
-Very stripped-down: This installer does NOT install barnyard2, or include any options to install an interface of any sort. This installs pulledpork, and Suricata with some persistence, and that's it.
-Inline mode operation: This installer requires a minimum of 3 network interfaces to work properly. Two interfaces will be placed into inline mode via the AFPACKET DAQ. ARP will be disabled on these interfaces, meaning that your system will NOT respond to any traffic sent to these interfaces.
-Pulledpork.pl is installed but is NOT configured to run. Because the Emerging Threats ruleset doesn't really include a default ruleset, I leave it as an exercise to the user if they want to learn how to customize and manage their rules.

This installer, and its supporting files are meant to be consumed with PROJECT:AVATAR, my massive virtual lab book. Particularly, the chapter entitled "IDS/IPS" installation. All the instructions you should need should be included in the book.

Thanks,

da_667