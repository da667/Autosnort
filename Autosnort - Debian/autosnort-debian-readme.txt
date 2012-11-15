Hello folks, this is the readme specific to the Debian edition of autosnort.

for the most part, this is a complete clone of the autosnort ubuntu script except with changes where required (e.g. version checking) and a couple of minor changes:

1. As part of the installation http://www.dotdeb.org (deb and deb-src) and its gpg key are added in order to install necessary components of snort and snortreport.

2. as recommended per the the snort 2.9.3.1 install guide, the script installs ethtool and disables lro and gro (checksum offloading) on the sniffing interface

as always, I can be contacted via twitter:
@da_667

or via e-mail:
deusexmachina667@gmail.com

Regards,

DA