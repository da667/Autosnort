Hello, this is a readme specifically for the CentOS build of autosnort.

There are a few slight variations to the autosnort script for Ubuntu you should be aware of:

1. For the script to be able to download many of the package pre-reqs for snortreport and other tools, the epel repos are installed to get those required packages.

2. For the script to have the sniffing interface start up on boot, the entry to bring up the interface in promiscuous mode is currently added to /etc/rc.local, same as snort and barnyard. the official way of doing this via /etc/sysconfig/network-scripts/ifcfg-[interface-name] and adding PROMISC="yes" appears to not be working. If you know how to do this the "right" way, please contact me. For now however, this will provide the same functionality.