Hello, this is a readme specifically for the CentOS build of autosnort.

There are a few slight variations to this autosnort script for CentOS/Redhat from the Ubuntu and Backtrack versions you should be aware of:

1. For the script to be able to download many of the package pre-reqs for snortreport and other tools, the epel repos are installed and enabled as a part of the installation to get those required packages.

2. For the script to have the sniffing interface start up on boot, the entry to bring up the interface in promiscuous mode is currently added to /etc/rc.local, same as snort and barnyard. Per googling and a bit of sleuthing this is the only official way to do this from here on out, unfortunately.

3. There are two modifications that you will need to perform manually on CentOS/Redhat systems to make sure autosnort works properly -- modify php.ini and set the short_open_tag directive to On and running the chcon -R command on the snortreport directory in /var/www/html for SELinux to allow httpd to read the files in the directory here is the step-by-step on how to do this:

	1. open up php.ini via the editor of your choice
	2. locate the short_open_tag directive. This should be line 229.
	3. Set this directive from Off to On and save php.ini
	4. Reload or Restart the httpd service (servce httpd restart)
	5. change directories to /var/www/html
	6. run the command: chcon -R -t httpd_sys_rw_content_t snortreport-1.3.3/