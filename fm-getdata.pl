#!/usr/bin/perl
#    This file is part of IFMI FarmManager.
#

use warnings;
use strict;
use IO::Socket::INET;

require '/opt/ifmi/fm-common.pl';
use DBI;

sub doGetData {
	my $dbname = "/opt/ifmi/fm.db"; my $dbh; 
	my $now = time;
	if (! -e $dbname) {
		$dbh = DBI->connect("dbi:SQLite:dbname=$dbname", { RaiseError => 1 }) or die $DBI::errstr;

		$dbh->do("CREATE TABLE Miners(IP TEXT, Port INTEGER, Name TEXT, User TEXT, Pass TEXT, Mgroup TEXT, Updated INT, Devices TEXT, Pools TEXT, Summary TEXT, Version TEXT, Access TEXT)");
		$dbh->do("INSERT INTO Miners(IP, Port, Name, User, Pass, Mgroup, Updated, Devices, Pools, Summary, Version, Access) VALUES ('192.168.0.1', '4028', 'unknown', '', '', 'Default', '0', 'None', 'None', 'None', 'None', 'E')");

		$dbh->do("CREATE TABLE Pools(URL TEXT, Worker TEXT, Pass TEXT, Updated INT, Status TEXT, Alias TEXT, LastUsed TEXT)");
		$dbh->do("INSERT INTO Pools(URL, Worker, Pass, Updated, Status, Alias, LastUsed) VALUES ('NEWPOOL', '1JBovQ1D3P4YdBntbmsu6F1CuZJGw9gnV6', '', '$now', 'unknown', 'DONATE', '0')");
		my $sth = $dbh->prepare("UPDATE Pools SET URL= ? WHERE URL='NEWPOOL'");
		my $donatepool = "stratum+tcp://mine.coinshift.com:3333";
		$sth->execute($donatepool); $sth->finish();
		`chown www-data $dbname`;
	} else { 
		$dbh = DBI->connect("dbi:SQLite:dbname=$dbname", { RaiseError => 1 }) or die $DBI::errstr;
	}
	my $all = $dbh->selectall_arrayref("SELECT * FROM Miners");
	foreach my $row (@$all) {
	  my ($ip, $port, $name, $user, $pass, $loc, $updated, $devs, $pools, $summary, $vers) = @$row;
	  my $acheck = &sendAPIcommand("privileged","",$ip,$port);
	  if (defined $acheck && $acheck ne "socket failed") {
	  	$acheck = $1 if ($acheck =~ m/STATUS=(\w),/g);	  	
	  	my $ttu = $updated+50;
	  	if ($now > $ttu) {
				my $sth = $dbh->prepare("UPDATE Miners SET Access= ? WHERE IP= ? AND Port= ? ");
				$sth->execute($acheck, $ip, $port); $sth->finish();
	  	}	
	  	if ($now > $ttu || $vers eq "None") {
		  	my $nvers = &sendAPIcommand("version","",$ip,$port);
	  		$nvers = $1 if $nvers =~ m/VERSION,(.+)/g;
				if (defined $nvers) {
					my $sth = $dbh->prepare("UPDATE Miners SET Version= ? WHERE IP= ? AND Port= ? ");
					$sth->execute($nvers, $ip, $port); $sth->finish();
	  		}
	  	}
	  	if ($now > $ttu || $summary eq "None") {
				my $nsum = &sendAPIcommand("summary","",$ip,$port);
				$nsum = $1 if $nsum =~ m/SUMMARY,(.+?)\|/g;
				if (defined $nsum) {
					my $sth = $dbh->prepare("UPDATE Miners SET Summary= ? WHERE IP= ? AND Port= ? ");
					$sth->execute($nsum, $ip, $port); $sth->finish();
				}
			}  	
	  	if ($now > $ttu || $pools eq "None") {
				my $npools = &sendAPIcommand("pools","",$ip,$port);
				if ($npools =~ m/STATUS=S,.+?\|(.+)/g) {
					my $poolsd = $1;
					$poolsd =~ s/\|/\n/g;
					my $sth = $dbh->prepare("UPDATE Miners SET Pools= ? WHERE IP= ? AND Port= ? ");
					$sth->execute($poolsd, $ip, $port); $sth->finish();
				}
			}  	
	  	if ($now > $ttu || $devs eq "None") {
				my $ndevs = &sendAPIcommand("devs","",$ip,$port);
				if ($ndevs =~ m/STATUS=S,.+?\|(.+)/g) {
					my $devsd = $1;
					$devsd =~ s/\|/\n/g;
					my $sth = $dbh->prepare("UPDATE Miners SET Devices= ? WHERE IP= ? AND Port= ? ");
					$sth->execute($devsd, $ip, $port); $sth->finish();
				}			
			}  			
			if ($now > $ttu) {
				my $sth = $dbh->prepare("UPDATE Miners SET Updated= ? WHERE IP= ? AND Port= ? ");
				$sth->execute($now, $ip, $port); $sth->finish();
			}
		}
	}

	my $sth = $dbh->prepare("SELECT URL FROM Pools"); $sth->execute(); 
 	while (my @prow = $sth->fetchrow_array()) {
 		my $purl = $prow[0];	
 		my @ipport = split(/:/, $purl);
 		my $phost = $ipport[1]; $phost =~ s|^//||;
 		my $pport = $ipport[2];
 		my $pip = `dig +short $phost`;
 		$pip = $1 if $pip =~ /(\d+\.\d+\.\d+\.\d+)/;
 		my $pcheck = &doPoolCheck($pip, $pport);
 		my $ssth;
 		if ($pcheck =~ /"error":(\s)?null/) {
 			$ssth = $dbh->prepare("UPDATE Pools SET Status='Alive' WHERE URL= ? ");
			$ssth->execute($purl); $ssth->finish();
 		} elsif ($pcheck =~ /socket failed/) {
 			$ssth = $dbh->prepare("UPDATE Pools SET Status='Dead' WHERE URL= ? ");
			$ssth->execute($purl); $ssth->finish();
 		}
 		$ssth = $dbh->prepare("UPDATE Pools SET Updated= ? WHERE URL= ? ");
		$ssth->execute($now, $purl); $ssth->finish();
  } $sth->finish();
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

