autosnort-centOS-ppinteg README

Hello autosnort users. This is a README the CentOS autosnort build with Pulled Pork integration.
The biggest change in functionality you will notice is the pulled pork integration
using pulled pork for rule management has a few requirements:

1) you need to have a valid oink code. register on snort.org as a registered user, or if you have a VRT subscription, the VRT oink code you have should work fine
2) you'll need http and https access to labs.snort.org and snort.org to download snort.conf (from labs.snort.org) and rules via pulled pork (snort.org)

Other major chances include a lot of fault tolerance improvements in the code -- the script will no longer blindly plow forward if you give it invalid input, leaving you with a broken snort install. If you give the script something invalid or something that doesn't make sense the script loops through the routine until you do.

questions, as always can be directed to me via email or twitter:
e-mail deusexmachina667@gmail.com
twitter @da_667
