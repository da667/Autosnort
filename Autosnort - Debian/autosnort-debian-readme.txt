Hello folks, this is the readme specific to the Debian edition of autosnort.

for the most part, this is a complete clone of the autosnort ubuntu script except with changes where required (e.g. version checking) and a couple of minor changes:

1. As part of the installation http://www.dotdeb.org (deb and deb-src) and its gpg key are added in order to install necessary components of snort and snortreport.

2. as recommended per the the snort 2.9.3.1 install guide, the script installs ethtool and disables lro and gro (checksum offloading) on the sniffing interface

3. the short_open_tag is disabled by default on php installations on Debian. this results in page rendering problems for snort report. complete the following steps to resolve this problem:

	1. open up php.ini via the editor of your choice
	2. locate the short_open_tag directive. This should be line 226.
	3. Set this directive from Off to On and save php.ini
	4. Reload or Restart the apache web server (/etc/init.d/apache2 restart)

4. 1/3/2013: pulled pork integration has been integrated into the debian autosnort script. Additionally, short_open_tag configuration has been added to the script as a fix the user can have automatically performed for them.

as always, I can be contacted via twitter:
@da_667

or via e-mail:
deusexmachina667@gmail.com

Regards,

DA