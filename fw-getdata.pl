#!/usr/bin/perl
#    This file is part of IFMI FarmManager.
#
use warnings;
use strict;
use IO::Socket::INET;
use DBI;
use Proc::ProcessTable;
require '/opt/ifmi/fw-common.pl';

sub doGetData {
	my $dbh; my $dbname = "/opt/ifmi/fm.db";
	my $now = time;
	if (! -e $dbname) {
		$dbh = DBI->connect("dbi:SQLite:dbname=$dbname", { RaiseError => 1 }) or die $DBI::errstr;
		$dbh->do("CREATE TABLE Miners(IP TEXT, Port INTEGER, Name TEXT, User TEXT, Pass TEXT, Mgroup TEXT, Updated INT, Devices TEXT, Pools TEXT, Summary TEXT, Version TEXT, Access TEXT, MonProf INTEGER, Amail TEXT)");
		$dbh->do("CREATE TABLE Settings(Theme TEXT, Port INTEGER, UnPDel TEXT, Updated INT, Status TEXT)");
		$dbh->do("INSERT INTO Settings(Theme, Port, UnPDel, Updated, Status) VALUES ('fwdefault.css', '54545', 'N', '0', '')");
		$dbh->do("CREATE TABLE MProfiles(ID INTEGER, Name TEXT, hlow INTEGER, rrhi INTEGER, hwe INTEGER, tmphi INTEGER, tmplo INTEGER, fanhi INTEGER, fanlo INTEGER, loadlo INTEGER)");
		$dbh->do("INSERT INTO MProfiles(ID, Name, hlow, rrhi, hwe, tmphi, tmplo, fanhi, fanlo, loadlo) VALUES ('0', 'Default', '200', '5', '1', '85', '45', '4000', '1000', '1')");
		$dbh->do("CREATE TABLE Pools(URL TEXT, Worker TEXT, Pass TEXT, Updated INT, Status TEXT, Pri INT, Diff INT, Rej INT, Alias TEXT, LastUsed INT, Avalue INTEGER)");
		$dbh->disconnect();
		my $apacheuser = "unknown";
		$apacheuser = "apache" if (-e "/etc/redhat-release");
		$apacheuser = "www-data" if (-e "/etc/debian_version");
		`chown $apacheuser $dbname` if ($apacheuser ne "unknown");
	}
	&getMinerData($dbname);
	&updatePools($dbname);
	sleep 6;
	for my $p (@{new Proc::ProcessTable->table}){
		 kill 9, $p->pid if($p->ppid == $$);
	}
}

sub getMinerData {
	my ($dbname) = @_; my $now = time;
	my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", { RaiseError => 1 }) or die $DBI::errstr;
	my $all = $dbh->selectall_arrayref("SELECT IP, Port, Access, Updated FROM Miners");
	foreach my $row (@$all) {
	  my ($ip, $port, $access, $updated) = @$row;
		my $pid; $SIG{CHLD} = 'IGNORE';
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
					$poolsd =~ s/\|/\n/g if (defined $poolsd);
					my $ndevs = &sendAPIcommand("devs","",$ip,$port);
					my $devsd = $1 if ($ndevs =~ m/STATUS=S,.+?\|(.+)/g);
					$devsd =~ s/\|/\n/g if (defined $devsd);
					$sth = $cdbh->prepare("UPDATE Miners SET Access= ?, Version= ?, Summary= ?, Pools= ?, Devices= ?, Updated= ? WHERE IP= ? AND Port= ? ");
					$sth->execute($acheck, $nvers, $nsum, $poolsd, $devsd, $now, $ip, $port); $sth->finish();
		  	}
		  } else {
		  	if ($access ne "D") {
					if (!defined $acheck || $acheck eq "") {
							$acheck = "U";
							$sth = $cdbh->prepare("UPDATE Miners SET Access= ? WHERE IP= ? AND Port= ? ");
							$sth->execute($acheck, $ip, $port); $sth->finish();
					} elsif ($acheck eq "socket failed") {
							$acheck = "F";
							$sth = $cdbh->prepare("UPDATE Miners SET Access= ? WHERE IP= ? AND Port= ? ");
							$sth->execute($acheck, $ip, $port); $sth->finish();
					}
				}
			}
			$cdbh->disconnect();
			exit 0;
		}
	} $dbh->disconnect();
}

sub updatePools {
	my ($dbname) = @_; my $now = time;
	my $pdbh = DBI->connect("dbi:SQLite:dbname=$dbname", { RaiseError => 1 }) or die $DBI::errstr;
	my $mpall = $pdbh->selectall_arrayref("SELECT Pools, Devices, Updated FROM Miners");
	foreach my $mprow (@$mpall) {
		my ($mpools, $mdevs, $mupdated) = @$mprow;
		if (($mupdated+90 > $now) && (defined $mpools && $mpools ne "") && (defined $mdevs && $mdevs ne "")) {
			my $mpoid; my $mpurl; my $mpstat; my $mppri; my $mpuser; my $mpdiff; my $mprej;
			while ($mpools =~ m/POOL=(\d),(.+)/g) {
				my $mpoid = $1; my $pooldata = $2;
				my $mpurl = $1 if ($pooldata =~ m/URL=(.+?\/\/.+?:\d+?),/);
				my $mpstat = $1 if ($pooldata =~ m/Status=(\w+?),/);
				my $mppri = $1 if ($pooldata =~ m/Priority=(\d),/);
				my $mpuser = $1 if ($pooldata =~ m/User=(.+?),/);
				my $mpdiff = $1 if ($pooldata =~ m/Last.+Last Share Difficulty=(\d+\.\d+),/);
				my $mprej = $1 if ($pooldata =~ m/Pool Rejected%=(\d+\.\d+),/);
				my $ucount = 0; my $upsth;
	    	my $upall = $pdbh->selectall_arrayref("SELECT URL, Worker, LastUsed FROM Pools");
				foreach my $uprow (@$upall) {
					my ($upurl, $upwkr, $uplast) = @$uprow;
	       	if ($upurl eq $mpurl && $upwkr eq $mpuser) {
					  while ($mdevs =~ m/Last Share Pool=(\d),/g) {
						 	$uplast = $now if ($mpoid == $1);
						 	last if $1 eq "";
					 	}
						$upsth = $pdbh->prepare("UPDATE Pools SET Updated= ?, Status= ?, Pri= ?, Diff= ?, Rej= ?, LastUsed= ? WHERE URL= ? AND Worker= ?");
	       		$upsth->execute($now, $mpstat, $mppri, $mpdiff, $mprej, $uplast, $mpurl, $mpuser); $upsth->finish();
	       		$ucount++
	       	}
				}
	  	 	if ($ucount == 0 ) {
		      	$pdbh->do("INSERT INTO Pools(URL, Worker, Pass, Updated, Status, Pri, Diff, Rej, Alias, LastUsed, Avalue) VALUES	('NEWPOOL', '', '', '0', 'unknown', '0', '0', '0', '', '0', '5')");
		  	    $upsth = $pdbh->prepare("UPDATE Pools SET URL= ?, Worker= ?, Updated= ?, Status= ?, Pri= ?, Diff= ?, Rej= ?, LastUsed= ? WHERE URL='NEWPOOL'");
		    	  $upsth->execute($mpurl, $mpuser, $now, $mpstat, $mppri, $mpdiff, $mprej, $now); $upsth->finish();
	  	 	}
	  	 	last if $mpoid eq "";
			}
		}
	}
	# check status on a pool if its in the table but no longer in a miner
	my $upothr = $pdbh->selectall_arrayref("SELECT URL, Worker, Updated FROM Pools");
 	foreach my $orow (@$upothr) {
 		my ($purl, $puser, $pupdated) = @$orow;
 		if ($pupdated + 120 < $now) {
	 		my @ipport = split(/:/, $purl);
	 		my $phost = $ipport[1]; $phost =~ s|^//||;
	 		my $pport = $ipport[2];
	 		my $pip = `dig +short $phost`;
	 		$pip = $1 if $pip =~ /(\d+\.\d+\.\d+\.\d+)/;
	 		my $pcheck = &doPoolCheck($pip, $pport);
	 		my $ssth;
	 		if ($pcheck =~ /"error":(\s)?null/) {
	 			$ssth = $pdbh->prepare("UPDATE Pools SET Status='Alive' WHERE URL= ? AND Worker= ?");
				$ssth->execute($purl, $puser); $ssth->finish();
	 		} elsif ($pcheck =~ /socket failed/) {
	 			$ssth = $pdbh->prepare("UPDATE Pools SET Status='Dead' WHERE URL= ? AND Worker= ?");
				$ssth->execute($purl, $puser); $ssth->finish();
	 		}
	 	}
  }
	$pdbh->disconnect();
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
