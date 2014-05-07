#!/usr/bin/perl
#    This file is part of IFMI FarmManager.
#

use warnings;
use strict;
use IO::Socket::INET;
use DBI;
$SIG{CHLD} = 'IGNORE';
require '/opt/ifmi/fm-common.pl';

sub doGetData {
	my $dbname = "/opt/ifmi/fm.db"; my $dbh; 
	my $now = time;
	if (! -e $dbname) {
		$dbh = DBI->connect("dbi:SQLite:dbname=$dbname", { RaiseError => 1 }) or die $DBI::errstr;
		$dbh->do("CREATE TABLE Miners(IP TEXT, Port INTEGER, Name TEXT, User TEXT, Pass TEXT, Mgroup TEXT, Updated INT, Devices TEXT, Pools TEXT, Summary TEXT, Version TEXT, Access TEXT)");
		$dbh->do("INSERT INTO Miners(IP, Port, Name, User, Pass, Mgroup, Updated, Devices, Pools, Summary, Version, Access) VALUES ('192.168.0.1', '4028', 'unknown', '', '', 'Default', '0', 'None', 'None', 'None', 'None', 'E')");
		$dbh->do("CREATE TABLE Pools(URL TEXT, Worker TEXT, Pass TEXT, Updated INT, Status TEXT, Pri INT, Diff INT, Rej INT, Alias TEXT, LastUsed INT)");
		$dbh->do("INSERT INTO Pools(URL, Worker, Pass, Updated, Status, Pri, Diff, Rej, Alias, LastUsed) VALUES ('NEWPOOL', '1JBovQ1D3P4YdBntbmsu6F1CuZJGw9gnV6', '', '$now', 'unknown', '0', '0', '0', 'DONATE', '0')");
		my $dsth = $dbh->prepare("UPDATE Pools SET URL= ? WHERE URL='NEWPOOL'");
		my $donatepool = "stratum+tcp://mine.coinshift.com:3333";
		$dsth->execute($donatepool); $dsth->finish();
		my $apacheuser = "unknown";
		$apacheuser = "apache" if (-e "/etc/redhat-release");
		$apacheuser = "www-data" if (-e "/etc/debian_version"); 
		`chown $apacheuser $dbname` if ($apacheuser ne "unknown");
	} else { 
		$dbh = DBI->connect("dbi:SQLite:dbname=$dbname", { RaiseError => 1 }) or die $DBI::errstr;
	}

	my $pid; 
	my $all = $dbh->selectall_arrayref("SELECT IP, Port, Updated FROM Miners");
	foreach my $row (@$all) {
	  my ($ip, $port, $updated) = @$row;
		next if $pid = fork; die "fork failed: $!" unless defined $pid;
		if ($pid == 0) {
			my $cdbh = DBI->connect("dbi:SQLite:dbname=$dbname", { RaiseError => 1 }) or die $DBI::errstr; my $sth; 
		  my $acheck = &sendAPIcommand("privileged","",$ip,$port);
		  $acheck = $1 if ($acheck =~ m/STATUS=(\w),/g);	  	
		  if (defined $acheck && $acheck ne "" && $acheck ne "socket failed") {
		  	my $ttu = $updated+50;
		  	if ($now > $ttu) {
			  	my $nvers = &sendAPIcommand("version","",$ip,$port);
		  		$nvers = $1 if $nvers =~ m/VERSION,(.+)/g;
					my $nsum = &sendAPIcommand("summary","",$ip,$port);
					$nsum = $1 if $nsum =~ m/SUMMARY,(.+?)\|/g;
					my $npools = &sendAPIcommand("pools","",$ip,$port);
					my $poolsd = $1 if ($npools =~ m/STATUS=S,.+?\|(.+)/g);
					$poolsd =~ s/\|/\n/g;
					my $ndevs = &sendAPIcommand("devs","",$ip,$port);
					my $devsd = $1 if ($ndevs =~ m/STATUS=S,.+?\|(.+)/g);
					$devsd =~ s/\|/\n/g;
					$sth = $cdbh->prepare("UPDATE Miners SET Access= ?, Version= ?, Summary= ?, Pools= ?, Devices= ?, Updated= ? WHERE IP= ? AND Port= ? ");
					$sth->execute($acheck, $nvers, $nsum, $poolsd, $devsd, $now, $ip, $port); $sth->finish();
		  	}
			} elsif (!defined $acheck || $acheck eq "") {
					$acheck = "U";
					$sth = $cdbh->prepare("UPDATE Miners SET Access= ? WHERE IP= ? AND Port= ? ");
					$sth->execute($acheck, $ip, $port); $sth->finish();
			} elsif ($acheck eq "socket failed") {
					$acheck = "F";
					$sth = $cdbh->prepare("UPDATE Miners SET Access= ? WHERE IP= ? AND Port= ? ");
					$sth->execute($acheck, $ip, $port); $sth->finish();
			}
			$cdbh->disconnect();	
			exit 0;
		} 	 
	} 
	if ($pid > 0) {
		waitpid $pid, 0;
		my $nsth = $dbh->prepare("SELECT Pools, Devices, Updated FROM Miners"); $nsth->execute(); 
	 	while (my @mprow = $nsth->fetchrow_array()) {
	 		my $mdevs = $mprow[1]; 
	 		my $mupdated = $mprow[2];
			my $mpoid; my $mpurl; my $mpstat; my $mppri; my $mpuser; my $mpdiff; my $mprej;  
			while ($mprow[0] =~ m/POOL=(\d).+,?URL=(.+\/\/.+?:\d+?),(.+)?Status=(\w+?),Priority=(\d),.+,User=(.+),Last.+Last Share Difficulty=(\d+)\.\d+,.+,Pool Rejected%=(\d+\.\d+),/g) {
				$mpoid = $1; $mpurl = $2; $mpstat = $4; $mppri = $5; $mpuser = $6; $mpdiff = $7; $mprej = $8; 
			  my $psth = $dbh->prepare("SELECT URL, Worker FROM Pools"); $psth->execute();
				my $ucount = 0; my $upsth; 
	    	while (my @uprow = $psth->fetchrow_array()) {
	       	if ($uprow[0] eq $mpurl && $uprow[1] eq $mpuser) {
						$upsth = $dbh->prepare("UPDATE Pools SET Updated= ?, Status= ?, Pri= ?, Diff= ?, Rej= ? WHERE URL= ? AND Worker= ?");
	       		$upsth->execute($now, $mpstat, $mppri, $mpdiff, $mprej, $mpurl, $mpuser); $upsth->finish();
	       		$ucount++
	       	}
				} $psth->finish();
				while ($mdevs =~ m/Last Share Pool=(\d),/g) {
					if ($mpoid == $1) {
	 					my $plsth = $dbh->prepare("UPDATE Pools SET LastUsed= ? WHERE URL= ? AND Worker= ?");
						$plsth->execute($now, $mpurl, $mpuser); $plsth->finish();
					}
				} 
	  	 	if ($ucount == 0 ) {
		      	$dbh->do("INSERT INTO Pools(URL, Worker, Pass, Updated, Status, Pri, Diff, Rej, Alias, LastUsed) VALUES	('NEWPOOL', '', '', '0', 'unknown', '0', '0', '0', '', '0')");
		  	    $upsth = $dbh->prepare("UPDATE Pools SET URL= ?, Worker= ?, Updated= ?, Status= ?, Pri= ?, Diff= ?, Rej= ? WHERE URL='NEWPOOL'");
		    	  $upsth->execute($mpurl, $mpuser, $now, $mpstat, $mppri, $mpdiff, $mprej); $upsth->finish();				 
	  	 	}
			}		
		} $nsth->finish();
		my $usth = $dbh->prepare("SELECT URL, Worker, Updated FROM Pools"); $usth->execute(); 
	 	while (my @prow = $usth->fetchrow_array()) {
	 		my $purl = $prow[0]; my $puser = $prow[1]; my $pupdated = $prow[2];
	 		if ($pupdated + 120 < $now) {
		 		my @ipport = split(/:/, $purl);
		 		my $phost = $ipport[1]; $phost =~ s|^//||;
		 		my $pport = $ipport[2];
		 		my $pip = `dig +short $phost`;
		 		$pip = $1 if $pip =~ /(\d+\.\d+\.\d+\.\d+)/;
		 		my $pcheck = &doPoolCheck($pip, $pport);
		 		my $ssth;
		 		if ($pcheck =~ /"error":(\s)?null/) {
		 			$ssth = $dbh->prepare("UPDATE Pools SET Status='Alive' WHERE URL= ? AND Worker= ?");
					$ssth->execute($purl, $puser); $ssth->finish();
		 		} elsif ($pcheck =~ /socket failed/) {
		 			$ssth = $dbh->prepare("UPDATE Pools SET Status='Dead' WHERE URL= ? AND Worker= ?");
					$ssth->execute($purl, $puser); $ssth->finish();
		 		}
		 	} 
	  } $usth->finish();
	}
	$dbh->disconnect();	
}

sub doPoolCheck {
  my $pip = $_[0];
  my $pport = $_[1];
  if (defined $pip) { 
    my $command = '{"id": 1, "method": "mining.subscribe", "params": []}' . "\n";
    my $sock = new IO::Socket::INET (
      PeerAddr => $pip,
      PeerPort => $pport,
      Proto => 'tcp',
      ReuseAddr => 1,
      Timeout => 3,
    );
    if ($sock) {
      print $sock $command;
      my $res = "";
      while(<$sock>) {
        $res .= $_;
        last if /"error":/;
      }
      close($sock);
      return $res;  
    } else {
      return "socket failed";
    }
  }
}

1;
