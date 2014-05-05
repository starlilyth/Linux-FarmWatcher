#!/usr/bin/perl
#    This file is part of IFMI FarmManager.
#
use warnings;
use strict;
use YAML qw( LoadFile );
use IO::Socket::INET;
#use Sys::Syslog qw( :DEFAULT setlogsock);
#setlogsock('unix');
use DBI;
my $dbname = "/opt/ifmi/fm.db"; 

sub addFMPool {
  my $apooln = $_[0]; 
  if ($apooln =~ m|://(\w+-?\w+\.)+?(\w+-?\w+\.\w+:\d+)|) {
    my $apoolu = $_[1]; my $apoolp = $_[2]; my $apoola = $_[3];
    my $sth; 
    my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", { RaiseError => 1 }) or die $DBI::errstr;
    my $pmatch = 0;
    $sth = $dbh->prepare("SELECT URL, Worker FROM Pools"); $sth->execute();
    while (my @prow = $sth->fetchrow_array()) {
      my $pname = $prow[0]; my $pwkr = $prow[1];
      $pmatch++ if ($pname eq $apooln && $pwkr eq $apoolu);
    } $sth->finish(); 
    if ($pmatch eq 0) {
      $dbh->do("INSERT INTO Pools(URL, Worker, Pass, Updated, Status, Diff, Rej, Alias, LastUsed) VALUES ('NEWPOOL', '1JBovQ1D3P4YdBntbmsu6F1CuZJGw9gnV6', '', '0', 'unknown', '0', '0', 'DONATE', '0')");
      $sth = $dbh->prepare("UPDATE Pools SET URL= ?, Worker= ?, Pass= ?, Alias= ? WHERE URL='NEWPOOL'");
      $sth->execute($apooln, $apoolu, $apoolp, $apoola); $sth->finish();
    } 
    $dbh->disconnect();
  }
}
sub updateFMPool {
 my $upooln = $_[0]; my $upoolu = $_[1]; my $upoolp = $_[2]; my $upoola = $_[3];
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
  my $dpool = $_[0]; my $duser = $_[1]; 
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", { RaiseError => 1 }) or die $DBI::errstr;
  my $sth = $dbh->prepare("DELETE from Pools WHERE URL= ? AND Worker= ?");
  $sth->execute($dpool, $duser);
  $dbh->disconnect();
}

sub addFMNode {
  my $nmip = $_[0];
  if ($nmip =~ /\d+\.\d+\.\d+\.\d+/) {
    my $nmport = $_[1]; $nmport = "4028" if (($nmport eq "") | !($nmport =~ /\d+/)); 
    my $nmname = $_[2]; $nmname = "unknown" if ($nmname eq "");
    my $nmusr = $_[3]; my $nmpw = $_[4];
    my $nmgroup = $_[5]; $nmgroup = "Default" if ($nmgroup eq "");
    my $now = time; my $sth;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", { RaiseError => 1 }) or die $DBI::errstr;
    my $nmatch = 0;
    $sth = $dbh->prepare("SELECT IP, Port FROM Miners"); $sth->execute();
    while (my @nrow = $sth->fetchrow_array()) {
      my $nname = $nrow[0]; 
      my $nnport = $nrow[1]; 
      $nmatch++ if ($nname eq $nmip && $nmport eq $nnport);
    } $sth->finish(); 
     if ($nmatch eq 0) {
      $dbh->do("INSERT INTO Miners(IP, Port, Name, User, Pass, Mgroup, Updated, Devices, Pools, Summary, Version, Access) VALUES ('NEWMINER', '4028', 'localhost', '', '', 'Default', '0', 'None', 'None', 'None', 'None', 'U')");
      $sth = $dbh->prepare("UPDATE Miners SET IP= ?, Port= ?, Name= ?, User= ?, Pass= ?, Mgroup= ? WHERE IP='NEWMINER'");
      $sth->execute($nmip, $nmport, $nmname, $nmusr, $nmpw, $nmgroup); $sth->finish();
     }
    $dbh->disconnect();
  }
}

sub updateFMNode {
 my $unodeip = $_[0]; my $unodeh = $_[1]; my $unodep = $_[2]; my $unodeg = $_[3];
 my $unodeu = $_[4]; my $unodepw = $_[5];
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
  my $dnode = $_[0]; my $dport = $_[1];
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", { RaiseError => 1 }) or die $DBI::errstr;
  my $sth = $dbh->prepare("DELETE from Miners WHERE IP= ? AND Port= ?");
  $sth->execute($dnode, $dport);
  $dbh->disconnect();
}

sub sendAPIcommand {
  my $command = $_[0];
  my $cflags = $_[1];
  my $cip = $_[2]; 
  my $cgport = $_[3];
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


sub getConfig {
  my $conffile = '/opt/ifmi/farmmanager.conf';
  if (! -e $conffile) {
    exec('/usr/lib/cgi-bin/config.pl');
  } 
  my $c;
  $c = LoadFile($conffile);
  return($c);
}


1;
