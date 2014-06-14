#!/usr/bin/perl
#    This file is part of IFMI FarmManager.
#
use warnings;
use strict;
use IO::Socket::INET;
#use Sys::Syslog qw( :DEFAULT setlogsock);
#setlogsock('unix');
use DBI;
my $dbname = "/opt/ifmi/fm.db"; 

sub addFMPool {
  my ($apooln, $apoolu, $apoolp, $apoola, $userid) = @_;
  if ($apooln =~ m|://(\w+-?\w+\.)+?(\w+-?\w+\.\w+:\d+)|) {
    $dbname = "/opt/minerfarm/$userid/fm.db" if ($userid ne "");
    my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", { RaiseError => 1 }) or die $DBI::errstr;
    my $pmatch = 0;
    my $pall = $dbh->selectall_arrayref("SELECT URL, Worker FROM Pools"); 
    foreach my $prow (@$pall) {
      my ($pname, $pwkr) = @$prow;
      $pmatch++ if ($pname eq $apooln && $pwkr eq $apoolu);
    }  
    if ($pmatch eq 0) {
      $dbh->do("INSERT INTO Pools(URL, Worker, Pass, Updated, Status, Diff, Rej, Alias, LastUsed) VALUES ('NEWPOOL', '1JBovQ1D3P4YdBntbmsu6F1CuZJGw9gnV6', '', '0', 'unknown', '0', '0', 'DONATE', '0')");
      my $sth = $dbh->prepare("UPDATE Pools SET URL= ?, Worker= ?, Pass= ?, Alias= ? WHERE URL='NEWPOOL'");
      $sth->execute($apooln, $apoolu, $apoolp, $apoola); $sth->finish();
    } 
    $dbh->disconnect();
  }
}
sub updateFMPool {
 my ($upooln, $upoolu, $upoolp, $upoola, $userid) = @_;
  $dbname = "/opt/minerfarm/$userid/fm.db" if ($userid ne "");
 my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", { RaiseError => 1 }) or die $DBI::errstr;
  my $sth;
  if (defined $upoolp && $upoolp ne "") {
    $sth = $dbh->prepare("UPDATE Pools SET Pass= ? WHERE URL= ? AND Worker = ?");
    $sth->execute($upoolp, $upooln, $upoolu); $sth->finish(); 
  }
  if (defined $upoola && $upoola ne "") {
    $sth = $dbh->prepare("UPDATE Pools SET Alias= ? WHERE URL= ? AND Worker = ?");
    $sth->execute($upoola, $upooln, $upoolu); $sth->finish(); 
  }
  $dbh->disconnect();
}
sub deleteFMPool {
  my ($dpool, $duser, $userid) = @_;
  $dbname = "/opt/minerfarm/$userid/fm.db" if ($userid ne "");
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", { RaiseError => 1 }) or die $DBI::errstr;
  my $sth = $dbh->prepare("DELETE from Pools WHERE URL= ? AND Worker= ?");
  $sth->execute($dpool, $duser); $sth->finish(); 
  $dbh->disconnect();
}

sub addFMNode {
  my ($newm, $nmport, $nmname, $nmusr, $nmpw, $nmgroup, $userid) = @_; 
  my $nmip;
  if ($newm =~ /\d+\.\d+\.\d+\.\d+/) {
    $nmip = $newm;
  } else { 
    my $nip = `dig +short $newm`;
    chomp $nip;
    $nmip = $1 if $nip =~ /(\d+\.\d+\.\d+\.\d+)/;
    $nmname = $newm;
  }
  if ($nmip =~ /\d+\.\d+\.\d+\.\d+/) {
    $nmport = "4028" if (($nmport eq "") | !($nmport =~ /\d+/)); 
    $nmname = "unknown" if ($nmname eq "");    
    $nmgroup = "Default" if ($nmgroup eq "");
    $dbname = "/opt/minerfarm/$userid/fm.db" if ($userid ne "");
    my $now = time; my $sth;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", { RaiseError => 1 }) or die $DBI::errstr;
    my $nmatch = 0;
    my $mnall = $dbh->selectall_arrayref("SELECT IP, Port FROM Miners"); 
    foreach my $mnrow (@$mnall) {
      my ($nname, $nnport) = @$mnrow; 
      $nmatch++ if ($nname eq $nmip && $nmport eq $nnport);
    } 
     if ($nmatch eq 0) {
      $dbh->do("INSERT INTO Miners(IP, Port, Name, User, Pass, Mgroup, Updated, Devices, Pools, Summary, Version, Access, MonProf, Amail) VALUES ('NEWMINER', '4028', 'localhost', '', '', 'Default', '0', 'None', 'None', 'None', 'None', 'U', '0', 'N')");
      $sth = $dbh->prepare("UPDATE Miners SET IP= ?, Port= ?, Name= ?, User= ?, Pass= ?, Mgroup= ? WHERE IP='NEWMINER'");
      $sth->execute($nmip, $nmport, $nmname, $nmusr, $nmpw, $nmgroup); $sth->finish();
     }
    $dbh->disconnect();
  }
}

sub updateFMNode {
 my ($unodeip, $unodeh, $unodep, $unodeg, $unodeu, $unodepw, $userid) = @_;
  $dbname = "/opt/minerfarm/$userid/fm.db" if ($userid ne "");
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", { RaiseError => 1 }) or die $DBI::errstr;
  my $sth;
  if (defined $unodeh && $unodeh ne "") {
    $sth = $dbh->prepare("UPDATE Miners SET Name= ? WHERE IP= ? AND Port = ?");
    $sth->execute($unodeh, $unodeip, $unodep); $sth->finish(); 
  }
  if (defined $unodeg && $unodeg ne "") {
    $sth = $dbh->prepare("UPDATE Miners SET Mgroup= ? WHERE IP= ? AND Port = ?");
    $sth->execute($unodeg, $unodeip, $unodep); $sth->finish(); 
  }
  if (defined $unodeu && $unodeu ne "") {
    $sth = $dbh->prepare("UPDATE Miners SET User= ? WHERE IP= ? AND Port = ?");
    $sth->execute($unodeu, $unodeip, $unodep); $sth->finish(); 
  }
  if (defined $unodepw && $unodepw ne "") {
    $sth = $dbh->prepare("UPDATE Miners SET Pass= ? WHERE IP= ? AND Port = ?");
    $sth->execute($unodepw, $unodeip, $unodep); $sth->finish(); 
  }  
  $dbh->disconnect();
}
sub deleteFMNode {
  my ($dnode, $dport, $userid) = @_;
  $dbname = "/opt/minerfarm/$userid/fm.db" if ($userid ne "");
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", { RaiseError => 1 }) or die $DBI::errstr;
  my $sth = $dbh->prepare("DELETE from Miners WHERE IP= ? AND Port= ?");
  $sth->execute($dnode, $dport); $sth->finish();  
  $dbh->disconnect();
}

sub updateMonProf {
 my ($ummonprof, $umpname, $umphr, $umprr, $umphw, $umpthi, $umptlo, $umpfhi, $umpflo, $umpllo, $userid) = @_;
  $dbname = "/opt/minerfarm/$userid/fm.db" if ($userid ne "");
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", { RaiseError => 1 }) or die $DBI::errstr;
  if ($ummonprof eq "new") {    
    $umphr = "200" if ($umphr eq "");  
    $umprr = "5" if ($umprr eq "");
    $umphw = "1" if ($umphw eq ""); 
    $umpthi = "90" if ($umpthi eq "");
    $umptlo = "60" if ($umptlo eq "");
    $umpfhi = "4000" if ($umpfhi eq "");
    $umpflo = "1000" if ($umpflo eq "");
    $umpllo = "1" if ($umpllo eq "");
    $dbh->do("INSERT INTO MProfiles(ID, Name, hlow, rrhi, hwe, tmphi, tmplo, fanhi, fanlo, loadlo) VALUES ('NEW', '$umpname', '$umphr', '$umprr', '$umphw', '$umpthi', '$umptlo', '$umpfhi', '$umpflo', '$umpllo')");
    my $mpid = $dbh->func('last_insert_rowid');
    my $sth = $dbh->prepare("UPDATE MProfiles SET ID= ? WHERE ID='NEW'");
    $sth->execute($mpid); $sth->finish(); $dbh->disconnect();
  } else { 
    my $sth;
    if (defined $umpname && $umpname ne "") {
      $sth = $dbh->prepare("UPDATE MProfiles SET Name= ? WHERE ID= ?");
      $sth->execute($umpname, $ummonprof); $sth->finish(); 
    }
    if (defined $umphr && $umphr ne "") {
      $sth = $dbh->prepare("UPDATE MProfiles SET hlow= ? WHERE ID= ?");
      $sth->execute($umphr, $ummonprof); $sth->finish(); 
    }
      if (defined $umprr && $umprr ne "") {
      $sth = $dbh->prepare("UPDATE MProfiles SET rrhi= ? WHERE ID= ?");
      $sth->execute($umprr, $ummonprof); $sth->finish(); 
    }
    if (defined $umphw && $umphw ne "") {
      $sth = $dbh->prepare("UPDATE MProfiles SET hwe= ? WHERE ID= ?");
      $sth->execute($umphw, $ummonprof); $sth->finish(); 
    } 
    if (defined $umpthi && $umpthi ne "") {
      $sth = $dbh->prepare("UPDATE MProfiles SET tmphi= ? WHERE ID= ?");
      $sth->execute($umpthi, $ummonprof); $sth->finish(); 
    }   
    if (defined $umptlo && $umptlo ne "") {
      $sth = $dbh->prepare("UPDATE MProfiles SET tmplo= ? WHERE ID= ?");
      $sth->execute($umptlo, $ummonprof); $sth->finish(); 
    }
    if (defined $umpfhi && $umpfhi ne "") {
      $sth = $dbh->prepare("UPDATE MProfiles SET fanhi= ? WHERE ID= ?");
      $sth->execute($umpfhi, $ummonprof); $sth->finish(); 
    }
    if (defined $umpflo && $umpflo ne "") {
      $sth = $dbh->prepare("UPDATE MProfiles SET fanlo= ? WHERE ID= ?");
      $sth->execute($umpflo, $ummonprof); $sth->finish(); 
    }
    if (defined $umpllo && $umpllo ne "") {
      $sth = $dbh->prepare("UPDATE MProfiles SET loadlo= ? WHERE ID= ?");
      $sth->execute($umpllo, $ummonprof); $sth->finish(); 
    }
  }
  $dbh->disconnect();
}
sub deleteMonProf {
  my ($dmonprof, $userid) = @_;
  $dbname = "/opt/minerfarm/$userid/fm.db" if ($userid ne "");
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", { RaiseError => 1 }) or die $DBI::errstr;
  my $pused = 0;
  my $dpallm = $dbh->selectall_arrayref("SELECT MonProf FROM Miners"); 
    foreach my $dprow (@$dpallm) {
      my ($mpid) = @$dprow;
      if ($mpid == $dmonprof) { $pused++; }
    }
  if ($pused == 0) {
    my $sth = $dbh->prepare("DELETE from MProfiles WHERE ID= ?");
    $sth->execute($dmonprof); $sth->finish();  
  } 
  $dbh->disconnect();
}

sub setNodeMP {
  my ($nmmp, $nmpnip, $nmpnport, $userid) = @_;
  $dbname = "/opt/minerfarm/$userid/fm.db" if ($userid ne "");
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", { RaiseError => 1 }) or die $DBI::errstr;
  my $sth = $dbh->prepare("UPDATE Miners SET MonProf= ? WHERE IP= ? AND Port = ?");
  $sth->execute($nmmp, $nmpnip, $nmpnport); $sth->finish(); $dbh->disconnect();
}

sub sendAPIcommand {
  my ($command, $cflags, $cip, $cgport) = @_;
  $cgport = "4028" if (!defined $cgport); 
  if (defined $cip) { 
    my $sock = new IO::Socket::INET (
      PeerAddr => $cip,
      PeerPort => $cgport,
      Proto => 'tcp',
      ReuseAddr => 1,
      Timeout => 5,
    );
    if ($sock) {
      if (defined $cflags) {
  #      &blog("sending \"$command $cflags\" to cgminer api") if (defined(${$conf}{settings}{verbose}));
        print $sock "$command|$cflags";
      } else {
  #      &blog("sending \"$command\" to cgminer api") if (defined(${$conf}{settings}{verbose}));
        print $sock "$command|\n"; 
      }
      my $res = "";
      while(<$sock>) {
        $res .= $_;
      }
      close($sock);
  #    &blog("success!") if (defined(${$conf}{settings}{verbose}));
      return $res;  
    } else {
      return "socket failed";
  #    &blog("failed to get socket for cgminer api") if (defined(${$conf}{settings}{verbose}));
    }   
  } else { return "No IP specified"; }
}

sub getIPs {
  my %ips;
  my $interface;
  my @res;  
  foreach ( qx{ (LC_ALL=C /sbin/ifconfig -a 2>&1) } ) {
    $interface = $1 if /^(\S+?):?\s/;
    next unless defined $interface;
    $ips{$interface}->{STATE}=uc($1) if /\b(up|down)\b/i;
    $ips{$interface}->{IP}=$1 if /inet\D+(\d+\.\d+\.\d+\.\d+)/i;
  }
  for my $int ( keys %ips ) {
    if (( $ips{$int}->{STATE} eq "UP" ) && defined($ips{$int}->{IP}) && !($int eq "lo")) {
      push(@res, $ips{$int}->{IP});
    }
  }
 return(@res);
}

###

# sub blog {
#   my ($msg) = @_;
#   my @parts = split(/\//, $0);
#   my $task = $parts[@parts-1];  
#   openlog($task,'nofatal,pid','local5');
#   syslog('info', $msg);
#   closelog;
# }

1;
