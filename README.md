Linux-FarmWatcher
=================

Read only version of FarmManager

REQUIRES A WEBSERVER (APACHE) WITH CGI ENABLED. 
And a few Perl Modules... 

INSTALL: run install-fw.pl

Backwards compatible with FarmView (previously included in Linux-PoolManager). 
BAMT/SMOS/PIMP clients using UDP status broadcast will be detected and added to the farm. 

Or you can add miners by IP and port, and FarmWatcher will pull the data over tcp, provided the FarmWatcher host can reach the miner, and the miner has allowed the FarmWatcher host ReadOnly access (at minimum). 

You can copy the /opt/ifmi files on a remote host, like inside your firewall, 
then use scp or rsync and cron to copy /opt/ifmi/fm.db once a minute to whatever host has the CGI pages. 
This will allow you to monitor a farm without opening a firewall/router port. 