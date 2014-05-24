Linux-FarmWatcher
=================

Read only version of FarmManager

Manual Install Instructions:
REQUIRES A WEBSERVER (APACHE) WITH CGI ENABLED. 
And a few Perl Modules... 

Copy images/ to your web root (/var/www/html)
Copy fmdefault.css to a directory named IFMI in your web root. 
Copy farmstatus.pl to your cgi directory (/usr/lib/cgi-bin), then ln -s farmstatus.pl farmstatus. 
Copy farmsettings.pl to your cgi directory (/usr/lib/cgi-bin), then ln -s farmsettings.pl farmsetings
Copy everything else (run-farmmanager.pl, fm-common.pl, fm-getdata.pl) to /opt/imfi
Do: chown /opt/ifmi www-data (or whatever your webserver user is. 'apache' on centos)
Add the following to your /etc/crontab:
* * * * * root /opt/ifmi/run-farmmanager.pl

Provided the FarmWatcher host can reach a miner, and the miner has allowed the FarmWatcher host ReadOnly access
(at minimum), you should now be able to add it to your farm. 

