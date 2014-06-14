#!/usr/bin/perl
# IFMI FarmWatcher installer. 
#    This file is part of IFMI FarmWatcher.
#
#    FarmWatcher is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.   
use strict;
use warnings;
use File::Path qw(make_path);
use File::Copy; 

my $login = (getpwuid $>);
die "Please run as root (do not use sudo)" if ($login ne 'root');
die "please execute from the install directory.\n" if (!-f "./install-fw.pl") ;

if ((defined $ARGV[0]) && ($ARGV[0] eq "-q")) {
	my $flag = $ARGV[0];
	&doInstall($flag); 
} else { 
	print "This will install the IFMI FarmWatcher for cgminer and clones on Linux.\n";
	print "Are you sure? (y/n) ";
	my $ireply = <>; chomp $ireply;
	if ($ireply =~ m/y(es)?/i) {
		if (-f "/opt/ifmi/run-farmwatcher.pl") {
			print "It looks like this has been installed before. Do over? (y/n) ";
			my $oreply = <>; chomp $oreply; 
			if ($oreply =~ m/y(es)?/i) {
				&doInstall; 
			} else {
				die "Installation exited!\n";
			}
		} else {
			&doInstall; 
		}
	} else {
		die "Installation exited!\n";
	}
}
sub doInstall {
	my $flag = "x";;
	$flag = $_[0] if (defined $_[0]);
	use POSIX qw(strftime);
	my $now = POSIX::strftime("%Y-%m-%d.%H.%M", localtime());	
	my $instlog = "PoolManager Install Log.\n$now\n";
	print "Perl module check \n" if ($flag ne "-q");
	require IO::Socket::INET;
	require Proc::PID::File;
	require Proc::Daemon;
	require Proc::ProcessTable;
	require DBI;
	require DBD::SQLite;
	require JSON;
	print " ..all set!\n" if ($flag ne "-q");
	$instlog .= "Perl test passed.";

# The following three values may need adjusting on systems that are not Debian or RedHat based. 
	my $webdir = "/var/www";
	if (-d "/etc/lighttpd" && !-d "/var/www/cgi-bin" ) { `ln -s /usr/lib/cgi-bin /var/www/cgi-bin` }
	my $cgidir = "/usr/lib/cgi-bin"; 
  my $apacheuser = "unknown";

	my $appdir = "/opt/ifmi";
  	$apacheuser = "apache" if (-f "/etc/redhat-release");
  	$apacheuser = "www-data" if (-f "/etc/debian_version"); 
  	if ($apacheuser ne "unknown") {
	    if (-d $webdir && -d $cgidir) { 
			print "Copying files...\n" if ($flag ne "-q");
			#perl chown requires UID and make_path is broken, so
    	copy "farmstatus.pl", $cgidir;
    	`ln -s $cgidir/farmstatus.pl $cgidir/farmstatus`;
			copy "farmsettings.pl", $cgidir;
    	`ln -s $cgidir/farmsettings.pl $cgidir/farmsettings`;
    	copy "favicon.ico", $webdir;
    	copy "fw-common.pl", $appdir;
      copy "run-farmwatcher.pl", $appdir;
    	copy "fw-getdata.pl", $appdir;
    	copy "fw-listener", $appdir;
			make_path $webdir . '/IFMI/themes' ;
    	`cp fmdefault.css $webdir/IFMI/themes`;
    	`cp -r images/ $webdir`;
    	`chmod 0755 $appdir/*.pl`; #because windows f's up the permissions. wtf. 
    	`chmod 0755 $appdir/fw-listener`; #because windows
    	`chmod 0755 $cgidir/*.pl`; #because windows
    	$instlog .= "files copied.\n";
		} else { 
			die "Your web directories are in unexpected places. Quitting.\n";
		}
		copy "/etc/crontab", "/etc/crontab.pre-ifmi" if (!-f "/etc/crontab.pre-ifmi");
    if (! `grep -E  ^"\* \* \* \* \* root /opt/ifmi/run-farmwatcher.pl" /etc/crontab`) {
			print "Setting up crontab...\n" if ($flag ne "-q");
    	open my $cin, '>>', "/etc/crontab";
     	print $cin "* * * * * root /opt/ifmi/run-farmwatcher.pl\n\n";
    	close $cin;
	    $instlog .= "crontab modified.\n";
    }
		print "FarmWatcher attempts to set up some basic security for your web service.\n" if ($flag ne "-q");
		print "It will enable SSL and redirect all web traffic over https.\n" if ($flag ne "-q");
		if (!-f "/etc/ssl/certs/apache.crt") {
			print "First, we need to create a self-signed cert to enable SSL.\n" if ($flag ne "-q");
			print "The next set of questions is information for this cert.\n" if ($flag ne "-q");
			print "Please set the country code, and the rest of the cert quetions can be left blank.\n";
			print "Press any key to continue: ";
			my $creply = <STDIN>; 
			if ($creply =~ m/.*/) {
			    `/usr/bin/openssl req -x509 -nodes -days 1825 -newkey rsa:2048 -keyout /etc/ssl/private/apache.key -out /etc/ssl/certs/apache.crt`;
			    print "...finished creating cert.\n";
			    $instlog .= "cert created.\n";
			}
	 	} else {
    		print "...cert appears to be installed, skipping...\n" if ($flag ne "-q");
		}
		
		#Lighttpd additions begin
		my $lrestart = 0;
		if (-d "/etc/lighttpd") {
			if (!-f "/etc/lighttpd/snakeoil.pem") {
				copy "/etc/ssl/private/apache.key", "/etc/lighttpd/snakeoil.pem";
				`cat /etc/ssl/certs/apache.crt >> /etc/lighttpd/snakeoil.pem`;
				copy "/etc/lighttpd/lighttpd.conf", "/etc/lighttpd/lighttpd.conf.pre-ifmi";
				`sed -i 's/#       \"mod_rewrite\"/       \"mod_rewrite\"/g' /etc/lighttpd/lighttpd.conf`;
				$lrestart++;
			}
			if (!-f "/etc/lighttpd/conf-enabled/10-ssl.conf") { 
				`lighty-enable-mod ssl`;
				copy "/etc/lighttpd/conf-available/10-ssl.conf", "/etc/lighttpd/conf-available/10-ssl.conf.pre-ifmi";
				`sed -i "s/server.pem/snakeoil.pem/g" /etc/lighttpd/conf-available/10-ssl.conf`;
				$lrestart++;
			}
			if (!-f "/etc/lighttpd/conf-enabled/10-cgi.conf") {
				`lighty-enable-mod cgi`;
				$lrestart++;
			}
			`service lighttpd restart` if ($lrestart > 0);
			#Lighttpd additions end.
		} else {
			my $restart = 0; 
   			copy "/etc/apache2/sites-available/default-ssl", "/etc/apache2/sites-available/default-ssl.pre-ifmi"
			if (!-f "/etc/apache2/sites-available/default-ssl.pre-ifmi");
	    	if (`grep ssl-cert-snakeoil.pem /etc/apache2/sites-available/default-ssl`) {
  			`sed -i "s/ssl-cert-snakeoil.pem/apache.crt/g" /etc/apache2/sites-available/default-ssl`;
				`sed -i "s/ssl-cert-snakeoil.key/apache.key/g" /etc/apache2/sites-available/default-ssl`;
  			$instlog .= "cert installed.\n";
				`/usr/sbin/a2ensite default-ssl`;
  			`/usr/sbin/a2enmod ssl`;
  			$restart++;
			}
			if (! `grep ServerName /etc/apache2/sites-available/default-ssl`) {
				open my $din, '<', "/etc/apache2/sites-available/default-ssl";
 	    	open my $dout, '>', "/etc/apache2/sites-available/default-ssl.out";
 	    	while (<$din>) {
		    		print $dout $_;
	    			last if /ServerAdmin /;
	   			}
 	    	print $dout "\n	ServerName IFMI:443\n";
 	    	while (<$din>) {
		    		print $dout $_;
			    }
	    		close $dout;
				move "/etc/apache2/sites-available/default-ssl.out", "/etc/apache2/sites-available/default-ssl";
	 	 } 
    	if (! `grep RewriteEngine /etc/apache2/sites-available/default`) {
	    	copy "/etc/apache2/sites-available/default", "/etc/apache2/sites-available/default.pre-ifmi"
	    		if (!-f "/etc/apache2/sites-available/default.pre-ifmi");
	    	open my $din, '<', "/etc/apache2/sites-available/default";
	    	open my $dout, '>', "/etc/apache2/sites-available/default.out";
	    	while (<$din>) {
	    		print $dout $_;
    			last if /ServerAdmin /;
   			}
	    	print $dout "\n	RewriteEngine On\n	RewriteCond %{HTTPS} !=on\n";
	    	print $dout "	RewriteRule ^/?(.*) https://%{SERVER_NAME}/\$1 [R,L]\n";
	    	while (<$din>) {
	    		print $dout $_;
	    	}
    		close $dout;
				move "/etc/apache2/sites-available/default.out", "/etc/apache2/sites-available/default";
				$instlog .= "rewrite enabled.\n";
  			`/usr/sbin/a2enmod rewrite`;
  			$restart++;
			}
			`service apache2 restart` if ($restart > 0);
		}

		print "Done! STOP FARMVIEW IF YOU HAVE IT! Thank you for flying IFMI!\n" if ($flag ne "-q");
	} else { 
		print "Cant determine apache user, Bailing out!\n";
		$instlog .= "unknown apache user, bailed out.\n";
	}
	open my $lin, '>', "FW-install-log.$now";
	print $lin $instlog;
	close $lin; 
}






