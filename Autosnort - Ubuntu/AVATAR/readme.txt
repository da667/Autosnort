This is a special release of autosnort meant to be used as a part of Project:AVATAR. This release differs from the mainline release in a number of ways:

-Very stripped-down: This installer does NOT install barnyard2, or include any options to install an interface of any sort. This installs Snort, pulledpork, and persistence for both and that's it.
-Inline mode operation: This installer requires a minimum of 3 network interfaces to work properly. Two interfaces will be placed into inline mode via the AFPACKET DAQ. ARP will be disabled on these interfaces, meaning that your system will NOT respond to any traffic on these interfaces.

This installer, and its supporting files are meant to be consumed with PROJECT:AVATAR, my massive virtual lab book. Particularly, the chapter entitled "IDS/IPS" installation. All the instructions you should need should be included in the book.

Thanks,

da_667