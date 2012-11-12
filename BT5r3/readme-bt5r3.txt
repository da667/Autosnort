This readme is specifically for BT5-R3


If you take a look at the script, you'll notice its about as long as the scripts for CentOS and Ubuntu and operates mostly the same. There's less action and less checks going on with the backtrack script because backtrack is designed to be ran as the root user, and has practically all of the pre-req libraries and tools installed by default. 

You'll probably notice that the script runs a bit faster, doesn't install jpgraph, snortreport, or configure mysql for you -- there's a reason for this.

It's been stated multiple times, even by the creators of the distro themselves, that Backtrack is a security distro, and not necessarily a secure distro. Having considered this and thinking about it, I decided to drop the installation of mysql and the web frontend.

The following are NOT installed on backtrack systems:
-jpgraph
-mysql server (already installed, but I do not enable the mysql server or run the mysql_secure_installation script)
-snortreport
-barnyard 2

Some may ask "Well, what's the point if you're not going to do a full sensor install?" glad you asked. The version of snort installed with BT5r3 is 2.8.5.2 -- likely whatever is in the default Ubuntu repos. 2.8.5.2 is a few years old now and has been deprecated -- meaning no new rules. There have been a number of stability fixes and functionality enhancements that have gone into snort since then (for instance the DAQ -data acquisition libraries) as well as a number of new, improved rules, new rule options and recategorizations -- that's plenty of benefit to reserachers who do malicious traffic analysis as well as hackers worldwide  who have to quickly analyze traffic that is being thrown against them in CTFs around the world -- MS08-067 may still be around, by there are new threats in town and a new version of snort is simply a nice addition to backtrack.

Others may ask "Well, why didn't you submit a ticket to redmine to have the distro maintainers to update snort?" Because I'm a hacker, that's why - why make other people do something that I can do just as well myself?. Let's take a look at this seriously. Let's say I ask them to update the version of snort in the distro repos. Let's assume that they immediately do so and it becomes available in the BT5 repos. With how fast new versions of snort are released, I'd be asking them to update again eventually, taking away their attention to other, probably more important projects and issues that need to be resolved.

On the other hand, I provide this script to Backtrack users, and they can download an updated version of snort for themselves. The script automatically gets the latest stable source and DAQ libs without bothering the distro maintainers. Problem solved. Forever.

Q+A
Where does the new version of snort get installed?
A: /usr/local/snort/bin. in fact, /usr/local/snort contains all of the subdirectories for the installation (e.g. etc for snort.conf, rules, preproc_rules, so_rules, etc.) This was done in the event the user wants to keep their current snort installation for whatever reason.

How do I determine what version of snort got installed?
A: run the command /usr/local/snort/bin/snort -V -- this returns the version of snort the script installed for you. This is relevant if the rules falled to install properly (see below), or you want to update them later.

What happens if I don't give the script a VRT rules tarball or I mistyped the location of the rules tarball?
A: Snort will still install just fine, you just won't have any rules to run against. This can be fixed in a few ways:
	1) register to snort.org, download the tarball for the version of snort you have, re-run the entire script, and when prompted, point the script to the tarball.
	2) register on snort.org, download the rules tarball for the version of snort you have, copy lines 335 - 404 in the script, drop them into their own shell script and run it.
	3) manually perform the actions below:
		download a rules tarball from snort.org (sign up for a free account and download rules for your installed version
		to determine the version of snort you are running try the command: /usr/local/snort/bin/snort -V (gives you the version of snort installed)
		untar the rule snapshot you downloaded to /usr/local/snort:
		tar -xzvf snortrules-snapshot-xxxx.tar.gz -C /usr/local/snort
		for 32-bit backtrack, copy these files to /usr/local/snort/lib/snort_dynamicrules:
		cp /usr/local/snort/so_rules/precompiled/Ubuntu-10-4/i386/x.x.x.x/* /usr/local/snort/lib/snort_dynamicrules
		for 64-bit backtrack, copy these files instead:
		cp /usr/local/snort/so_rules/precompiled/Ubuntu-10-4/i386/x.x.x.x/* /usr/local/snort/lib/snort_dynamicrules
		run this command:
		touch /usr/local/snort/rules/white_list.rules && touch /usr/local/snort/rules/black_list.rules && ldconfig
		lines 373 - 404 (aka the remaining steps): modify /usr/local/snort/etc/snort.conf to suit your snort install and point to your .rules files (e.g. the files in /usr/local/snort/rules/)
I should probably have some sort of a test condition or validation that checks if the file user inputs exists, and this will likely occur in the future to protect against users fat fingering this part, but for right now, just be careful.

I don't feel like typing out "/usr/local/snort/bin/snort" every time I want to run snort. This is going to get really annoying really fast."
A: By default, BT5 uses the BASH shell and a .bashrc is provided for you. In the rc file, you can modify your PATH variable and include /usr/local/snort/bin in the PATH. if you want to do this quickly without logging out and/or logging in again, try this:
echo "export PATH=$PATH:/usr/local/snort/bin" >> ~/.bashrc && source ~/.bashrc -- this adds the line to .bashrc in root's home and tells your shell to reload it on the fly.
alternatively, at least in my system's .bashrc there's two PATH exports already included. You could just tack /usr/local/snort/bin on to either of them if you are comfortable in doing so.



I think that does it. Here's contact information if you want to send love/hatemail bribes, questions, etc.:
twitter: @da_667
e-mail: deusexmachina667@gmail.com