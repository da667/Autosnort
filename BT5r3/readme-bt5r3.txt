This readme is specifically for BT5-R3


If you take a look at the script, you'll notice its about as long as the scripts for CentOS and Ubuntu and 
operates mostly the same. There's less action and less checks going on with the backtrack script because 
backtrack is designed to be ran as the root user, and has practically all of the pre-req libraries and tools 
installed by default. 

You'll probably notice that the script runs a bit faster, doesn't install jpgraph, snortreport, or configure mysql 
for you -- there's a reason for this.

It's been stated multiple times, even by the creators of the distro themselves, that Backtrack is a security distro, 
and not necessarily a secure distro. Having considered this and thinking about it, I decided to drop the installation
of mysql and the web frontend.

The following are NOT installed on backtrack systems:
-jpgraph
-mysql server (already installed, but I do not enable the mysql server or run the mysql_secure_installation script)
-snortreport
-barnyard 2

Some may ask "Well, what's the point if you're not going to do a full sensor install?" glad you asked. The version 
of snort installed with BT5r3 is 2.8.5.2 -- likely whatever is in the default Ubuntu repos. 2.8.5.2 is a few years old
now and has been deprecated -- meaning no new rules. There have been a number of stability fixes and functionality 
enhancements that have gone into snort since then (for instance the DAQ -data acquisition libraries) as well as a 
number of new, improved rules, new rule options and recategorizations -- that's plenty of benefit to reserachers who 
do malicious traffic analysis as well as hackers worldwide  who have to quickly analyze traffic that is being thrown 
against them in CTFs around the world -- MS08-067 may still be around, by there are new threats in town and a new 
version of snort is simply a nice addition to backtrack.

Others may ask "Well, why didn't you submit a ticket to redmine to have the distro maintainers to update snort?" 
Because I'm a hacker, that's why - why make other people do something that I can do just as well myself?. Let's take 
a look at this seriously. Let's say I ask them to update the version of snort in the distro repos. Let's assume that 
they immediately do so and it becomes available in the BT5 repos. With how fast new versions of snort are released, 
I'd be asking them to update again eventually, taking away their attention to other, probably more important projects 
and issues that need to be resolved.

On the other hand, I provide this script to Backtrack users, and they can download an updated version of snort for 
themselves. The script automatically gets the latest stable source and DAQ libs without bothering the distro maintainers.
Problem solved. Forever.


I think that does it. Here's contact information if you want to send love/hatemail bribes, questions, etc.:
twitter: @da_667
e-mail: deusexmachina667@gmail.com