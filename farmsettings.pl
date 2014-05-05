#!/usr/bin/perl
#    This file is part of IFMI FarmManager.
#

use warnings;
use strict;
use CGI qw(:cgi-lib :standard);
use DBI;
use POSIX;
my $dbname = "/opt/ifmi/fm.db"; my $dbh; 
require '/opt/ifmi/fm-common.pl';
my $conf = &getConfig;
my %conf = %{$conf};
my $conffile = "/opt/ifmi/farmmanager.conf";
my $now = time;

# Take care of business
&ReadParse(our %in);

my $apooln = $in{'npoolurl'};
if (defined $apooln) {
	my $apoolu = $in{'npooluser'};
	my $apoolp = $in{'npoolpw'};
	my $apoola = $in{'npoola'};
  &addFMPool($apooln, $apoolu, $apoolp, $apoola);
  $apooln = ""; $apoolu = ""; $apoolp = ""; $apoola = "";
}
my $upoolnu = $in{'upoolurluser'};
if (defined $upoolnu) {
	my @upu = split(/,/, $upoolnu);
	my $upooln = $upu[0];
	my $upoolu = $upu[1];
	my $upoolp = $in{'upoolpw'}; 
	my $upoola = $in{'upoola'}; 
	&updateFMPool($upooln, $upoolu, $upoolp, $upoola);
	$upooln = ""; $upoolu = ""; $upoolp = ""; $upoola = "";
}
my $dpool = $in{'delpool'};
if (defined $dpool) {
	my $duser = $in{'deluser'};
  &deleteFMPool($dpool, $duser);
  $dpool = "";
}

my $anodeip = $in{'nnip'};
if (defined $anodeip) {
	my $anodep = $in{'nnport'};
	my $anodeh = $in{'nnname'};
	my $anodeu = $in{'nnuname'};
	my $anodepw = $in{'nnpass'};
	my $anodeg = $in{'nngroup'};
  &addFMNode($anodeip, $anodep, $anodeh, $anodeu, $anodepw, $anodeg);
  $anodeip = ""; $anodeh = ""; $anodep = ""; $anodeg = ""; $anodeu = ""; $anodepw = "";
}

my $unodeipp = $in{'unipport'};
if (defined $unodeipp) {
	my @nipp = split(/,/, $unodeipp);
	my $unodeip = $nipp[0]; 
	my $unodep = $nipp[1]; 
	my $unodeh = $in{'unname'};
	my $unodeu = $in{'ununame'};
	my $unodepw = $in{'unpass'};
	my $unodeg = $in{'ungroup'}; 
	&updateFMNode($unodeip, $unodeh, $unodep, $unodeg, $unodeu, $unodepw);
	$unodeip = ""; $unodeh = ""; $unodep = ""; $unodeg = ""; $unodeu = ""; $unodepw = "";
}
my $dnode = $in{'delnode'};
if (defined $dnode) {
	my $dport = $in{'delport'};
  &deleteFMNode($dnode, $dport);
  $dnode = ""; $dport = "";
}

my $npn = $in{'pnotify'};
if (defined $npn) {
	my $paurl = $in{'purln'};
	my $acount = 0;

	$npn = "";
}
# Now carry on
my $fm_name = `hostname`; chomp $fm_name;
my $iptxt; my $nicget = `/sbin/ifconfig`; 
  while ($nicget =~ m/(\w\w\w\w?\d:0)\s.+\n\s+inet addr:(\d+\.\d+\.\d+\.\d+)\s/g) {
  $iptxt = $2; 
}
my $q=CGI->new();
print header;
print start_html( -title=>$fm_name . ' - FM Settings', 
									-style=>{-src=>'/IFMI/fmdefault.css'},  		
									-head=>$q->meta({-http_equiv=>'REFRESH',-content=>'30'}));
# 

my $html = "<div id='confpage' class='container'>"; my $nodeh; my $phtml; my $head;

$html .= "<div id='overview'>";
$html .= "<div id='logo' class='odata'><IMG src='/IFMI/IFMI-FM-logo.png'></div>" ;	

$html .= "<div class='odata'><h2>$fm_name @ $iptxt</h2></div>";
$html .= "<div id='icon' class='odata'><a href='farmstatus.pl'><img src='/IFMI/overview.png'></a></div>";
$html .= "<div id='overviewend' class='odata'><br></div>";
$html .= "</div>";
$html .= "<div id='confform' class='content'>";

if (-e $dbname) {
	$dbh = DBI->connect("dbi:SQLite:dbname=$dbname", { RaiseError => 1 }) or die $DBI::errstr; my $sth;
	$nodeh .= "<div id='nodelist' class='form'>";
	$sth = $dbh->prepare("SELECT COUNT() FROM Miners"); $sth->execute();
  my $ncount = $sth->fetchrow_arrayref->[0]; $sth->finish;
	$nodeh .= "<div class='table'>";
	$nodeh .= "<div class='title'><p>$ncount Nodes</p></div>";
	$nodeh .= "<div class='row'>";
	$nodeh .= "<form name='nadd' method='POST'><b>Add Node</b> ";
	$nodeh .= "<input type='text' placeholder='IP' size='18' placeholder='192.168.0.100' name='nnip' required> ";
	$nodeh .= "<input type='text' size='4' placeholder='4028' name='nnport'> ";
	$nodeh .= "<input type='text' placeholder='Hostname' name='nnname'> ";
	$nodeh .= "<input type='text' placeholder='Farm Group' name='nngroup'> ";
	$nodeh .= "<input type='submit' value='Add'>"; 
	$nodeh .= "</form></div><br>";

	$nodeh .= "<div class='row'>";
	$nodeh .= "<form name=nupdate method=post>";
	$nodeh .= "<b>Edit Node</b> ";
  $nodeh .= "<select name=unipport>"; 	
	$sth = $dbh->prepare("SELECT * FROM Miners"); $sth->execute();
 	while (my @noderow = $sth->fetchrow_array()) {
 		my $nodeip = $noderow[0]; 
 		my $nodeport = $noderow[1];
  	$nodeh .= "<option value=$nodeip,$nodeport>$nodeip | $nodeport</option>";
  } $sth->finish();	
  $nodeh .= "</select> ";
	$nodeh .= "<input type='text' placeholder='Hostname' name='unname'> ";
	$nodeh .= "<input type='text' placeholder='Farm Group' name='ungroup'> ";
	$nodeh .= "<input type='submit' value='Change'></form>";
  $nodeh .= "</div><br>";

	$nodeh .= "<div class='row'>";
  $nodeh .= "<div class='heading'>";
  $nodeh .= "<div class='cell'><p>IP</p></div>";
  $nodeh .= "<div class='cell'><p>Port</p></div>";
  $nodeh .= "<div class='cell'><p>Hostname</p></div>";
  $nodeh .= "<div class='cell'><p>Farm Group</p></div>";
  $nodeh .= "<div class='cell'><p>Status</p></div>";
  $nodeh .= "<div class='cell'><p>Version</p></div>";
  $nodeh .= "<div class='cell'><p>Active Pool</p></div>";
  $nodeh .= "<div class='cell'><p>Last Update</p></div>";
  $nodeh .= "<div class='cell'><p> </p></div>";
	$nodeh .= "</div>";
	$sth = $dbh->prepare("SELECT * FROM Miners"); $sth->execute(); 
	my $mall = $sth->fetchall_arrayref(); $sth->finish();	
	foreach my $mrow (sort { $a->[0] cmp $b->[0] } @$mall) {
 		my ($mip, $mport, $mhost, $muser, $mpass, $mfg, $mupdated, $mdevs, $mpools, $msum, $vers, $macc) = @$mrow;
		$nodeh .= "<div class='row'>"; 
    $nodeh .= "<div class='cell'><p><A href=ssh://root@" . $mip . '>' . $mip . '</a></p></div>';
    $nodeh .= "<div class='cell'><p>$mport</p></div>";
    $nodeh .= "<div class='cell'><p><A href=https://$mip/index.html>$mhost</a></p></div>";
    $nodeh .= "<div class='cell'><p>$mfg</p></div>";
    $macc = "<p class='ok'>R W</p>" if ($macc eq "S");
    $macc = "<p class='warn'>R O</p>" if ($macc eq "E");
    $macc = "<p>U</p>" if ($macc eq "U");    
    $nodeh .= "<div class='cell'>$macc</div>";
		my $mname = ""; my $mvers = "";
		if ($vers =~ m/Miner=(\w+)?\s?(\d+\.\d+\.\d+),API/) {
			$mname = $1 if (defined $1);
			$mvers = $2; 
		} else {
			$mname = "unknown";
		}				
    $nodeh .= "<div class='cell'><p>$mname $mvers</p></div>";
    $nodeh .= "<div class='cell'>";
		my $mplm=0; my $mpname; 
		if ($mpools =~ m/^POOL=/) {
			while (!defined $mpname) {
				while ($mpools =~ m/POOL=(\d).+,?URL=(.+?),Status=(\w+?),Priority=(\d),.+,User=(.+?),Last/g) {
					my $mpoolid = $1; my $mpurl = $2; my $mpstat = $3; my $mppri = $4; my $mpusr = $5;
					if ($mppri == $mplm && $mpstat eq "Alive") {
						$mpname = $2 if ($mpurl =~ m|://(\w+-?\w+\.)+?(\w+-?\w+\.\w+:\d+)|); 
					}
				}
				$mplm++;
			}
		}
		
		$mpname = "N/A" if (!defined $mpname); 
  	$nodeh .= "<p>" . $mpname . "</p>";
    $nodeh .= "</div>";
 		if ($mupdated != 0) {
 			if ($now > $mupdated+90) {
 				$mupdated = POSIX::strftime("%m-%d %H:%M", localtime($mupdated));
    		$mupdated = "<p class='warn'>$mupdated</p>";
 			} else {
	    	$mupdated = POSIX::strftime("%m-%d %H:%M", localtime($mupdated));
  	  	$mupdated = "<p>$mupdated</p>";
    	}
    } else { $mupdated = "<p class='warn'>never</p>"; }
    $nodeh .= "<div class='cell'>$mupdated</div>";
    $nodeh .= "<div class='cell'>";
    $nodeh .= "<form name='mdelete' method='POST'><input type='hidden' name='delport' value='$mport'>";
    $nodeh .= "<input type='hidden' name='delnode' value='$mip'><input type='submit' value='Delete'>";
	  $nodeh .= "</form></div>";
    $nodeh .= "</div>";
 	}
	$nodeh .= "</div></div></div>";

	$phtml .= "<div id='poollist' class='form'>";
	$sth = $dbh->prepare("SELECT COUNT() FROM Pools"); $sth->execute();
  my $pcount = $sth->fetchrow_arrayref->[0]; $sth->finish;
	$phtml .= "<div class='table'><div class='title'><p>$pcount Pools</p></div>";
	$phtml .= "<div class='row'>";
	$phtml .= "<form name='padd' method='POST'><b>Add Pool</b> ";
	$phtml .= "<input type='text' size='45' placeholder='MiningURL:portnumber' name='npoolurl' required> ";
	$phtml .= "<input type='text' placeholder='username.worker' name='npooluser' required> ";
	$phtml .= "<input type='text' placeholder='worker password' name='npoolpw'> ";
	$phtml .= "<input type='text' placeholder='Pool Alias' name='npoola'> ";
	$phtml .= "<input type='submit' value='Add'></form>"; 
  $phtml .= "</div><br>";

	$phtml .= "<div class='row'>";
	$phtml .= "<form name=pupdate method=post>";
	$phtml .= "<b>Edit Pool</b> ";
  $phtml .= "<select name=upoolurluser>"; 	
	$sth = $dbh->prepare("SELECT * FROM Pools"); $sth->execute();
 	while (my @poolrow = $sth->fetchrow_array()) {
 		my $poolurl = $poolrow[0]; 
 		my $pooluser = $poolrow[1]; my $plusr = $pooluser;
		if (length($plusr) > 20) { 
	    $plusr = substr($pooluser, 0, 6) . " ... " . substr($pooluser, -6, 6) if (index($pooluser, '.') < 0);
	  } 
		my $plurl = $1 if ($poolurl =~ m/^.+?:\/\/(.+)/); 
  	$phtml .= "<option value=$poolurl,$pooluser>$plurl | $plusr</option>";

  } $sth->finish();	
  $phtml .= "</select> ";
	$phtml .= "<input type='text' placeholder='worker password' name='upoolpw'> ";
	$phtml .= "<input type='text' placeholder='Pool Alias' name='upoola'> ";
	$phtml .= "<input type='submit' value='Change'></form>";
  $phtml .= "</div><br>";

	$phtml .= "<div class='row'>";
  $phtml .= "<div class='heading'>";
  $phtml .= "<div class='cell'><p>URL</p></div>";
  $phtml .= "<div class='cell'><p>Worker</p></div>";
  $phtml .= "<div class='cell'><p>Password</p></div>";
  $phtml .= "<div class='cell'><p>Alias</p></div>";
  $phtml .= "<div class='cell'><p>Status</p></div>";
  $phtml .= "<div class='cell'><p>Notify</p></div>";
  $phtml .= "<div class='cell'><p>Last Used</p></div>";
#  $phtml .= "<div class='cell'><p> </p></div>";
	$phtml .= "</div>";
	$sth = $dbh->prepare("SELECT * FROM Pools"); $sth->execute(); 
	my $pall = $sth->fetchall_arrayref(); $sth->finish();	
	foreach my $prow (sort { $b->[9] <=> $a->[9] } @$pall) {
 		my ($purl, $puser, $ppass, $pupdated, $pstatus, $ppri, $pdiff, $prej, $palias, $plast) = @$prow;
		my $pusr = $puser;
		if (length($pusr) > 20) { 
	    $pusr = substr($pusr, 0, 6) . " ... " . substr($pusr, -6, 6) if (index($pusr, '.') < 0);
	  }
		$phtml .= "<div class='row'>"; 
    $phtml .= "<div class='cell'><p>$purl</p></div>";
    $phtml .= "<div class='cell'><p>$pusr</p></div>";
    $ppass = "(none)" if ($ppass eq "");
    $phtml .= "<div class='cell'><p>$ppass</p></div>";
    $phtml .= "<div class='cell'><p>$palias</p></div>";
    if ($pstatus eq "unknown") {
	    $pstatus = "<p class='warn'>$pstatus</p>";
	  } elsif ($pstatus eq "Dead") {
	    $pstatus = "<p class='error'>$pstatus</p>";
	  } else {
	    $pstatus = "<p class='ok'>$pstatus</p>";
		}  
    $phtml .= "<div class='cell'>$pstatus</div>";
  	$phtml .= "<div class='cell'>";
		$phtml .= "<form name='pooln' method='POST'>";
		$phtml .= "<input type=hidden name='purln' value=$purl>";
	  my $pdnotify;
  	if ((defined $pdnotify) && ($pdnotify==1)) {
	  	$phtml .= "<input type='checkbox' name='pdnotify' checked>Dead ";
	  } else { 
 	  	$phtml .= "<input type='checkbox' name='pdnotify'>Dead ";
	  }
	  my $plnotify;
  	if ((defined $plnotify) && ($plnotify==1)) {
	  	$phtml .= "<input type='checkbox' name='plnotify' checked>Live ";
	  } else { 
 	  	$phtml .= "<input type='checkbox' name='plnotify'>Live ";
	  }
	  $phtml .= "<br><input type='submit' value='Save'></form>";    
    $phtml .= "</div>";
		if ($plast != 0) {
 			if ($plast +90 > $now) {
 				$plast = "Active";
			} else {
		 		$plast = POSIX::strftime("%m-%d %H:%M", localtime($plast));
		 	}
 		} else { $plast = "unknown"; }
    if ($pupdated + 120 < $now) {
 			$phtml .= "<div class='cell'>";
    	$phtml .= "<form name='pdelete' method='POST'><input type='hidden' name='deluser' value='$puser'>";
    	$phtml .= "<input type='hidden' name='delpool' value='$purl'><input type='submit' value='Delete'>";
	  	$phtml .= "</form></div>";
 	  } else {
	    $phtml .= "<div class='cell'><p>$plast</p></div>";
	  }

    $phtml .= "</div>";
 	}
	$phtml .= "</div>";
	$dbh->disconnect();
} else { 
	$html .= "<div id='waiting'><h1>Miner database not available!</H1><P>&nbsp;<P></div>";
}	

print $html;

print $nodeh;

print $phtml;

print "</div></div></BODY></HTML>";

