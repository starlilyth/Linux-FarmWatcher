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

# Now carry on
my $fm_name = `hostname`; chomp $fm_name;
my $iptxt; my $nicget = `/sbin/ifconfig`; 
  while ($nicget =~ m/(\w\w\w\w?\d:0)\s.+\n\s+inet addr:(\d+\.\d+\.\d+\.\d+)\s/g) {
  $iptxt = $2; 
}
my $q=CGI->new();
print header;
print start_html( -title=>$fm_name . ' - Farm Manager', 
		-style=>{-src=>'/IFMI/fmdefault.css'},  
		-head=>$q->meta({-http_equiv=>'REFRESH',-content=>'30'})  
		);
# 
my $tothash = 0; my $totproblems = 0;
my $tlocs = 0; my $tnodes = 0;
my $problemdevs = 0; my $okdevs = 0;
my $problemascs = 0; my $okascs = 0;
my $problemgpus = 0; my $okgpus = 0;
my $problemnodes = 0; my $oknodes = 0;
my $problempools = 0; my $okpools = 0;
my $html = "<div id='farm' class='content'>"; my $head;
if (-e $dbname) {
	$dbh = DBI->connect("dbi:SQLite:dbname=$dbname", { RaiseError => 1 }) or die $DBI::errstr;
	my @locs; my $lhtml;  my $phtml; 
	my $sth = $dbh->prepare("SELECT Mgroup FROM Miners");  
	$sth->execute();
	while (my @glocs = $sth->fetchrow_array()) { push(@locs, (@glocs));	}
	$sth->finish();
	my %locs; my $loc;
	foreach $loc (@locs) { $locs{$loc} = 1; }
	foreach $loc (sort keys %locs) {
		$tlocs++;
	 	my $lochash = 0;
	 	my $locdevs = 0; 
	 	my $locproblems = 0;
	 	my $locnodes = 0;
		my ($nhtml, $nhead, $ndata, $ddata); 
		my $sth = $dbh->prepare("SELECT * FROM Miners WHERE Mgroup= ?");
		$sth->execute($loc); 
		my $all = $sth->fetchall_arrayref(); $sth->finish();
		foreach my $row (sort { $b <=> $a } @$all) {
 			my ($ip, $port, $name, $user, $pass, $loc, $updated, $devices, $pools, $summary, $vers, $acheck) = @$row;
 			$locnodes++; $tnodes++; my @nodemsg; my $problems = 0; my $dcount = 0; my $devtype = ""; my $notemp = 0;
 			while ($devices =~ m/\b(GPU|ASC|PGA)\b=\d+/g) { $locdevs++; $dcount++; }
			my $errspan = $dcount*4;
 			$ndata .= "<TR class='nodedata'><td class='ndatahdr'>$ip";
  		$ndata .= "<br><small>$port</small></td>";
			$ndata .= "<td>$name</td>";			  	
  		if ($updated == 0) {
  			$ddata .= "<td colspan=9><i>This node has never been reached</i></td>";
  		} else { 
				my $checkin = ($now - $updated);
				if ($checkin > 90) {
					my $missed = int($checkin/60);
					$locproblems++;	$problemnodes++; $totproblems++;
					push(@nodemsg, "Missed $missed update");
					$nodemsg[@nodemsg-1] .= "s" if ($missed > 1);			
					$ndata .= "<td class='error' colspan=5>$nodemsg[0]</td>";
					$ddata .= "<td colspan=$errspan><i>current data not available</i></td>";
				} else {
					my $pdata = "";
	 				if ($pools ne "None") {
	 				 	my $plm=0; my $pname;
		 				while (!defined $pname) {
							while ($pools =~ m/POOL=(\d).+,?URL=(.+?),Status=(\w+?),Priority=(\d),.+,Last Share Difficulty=(\d+)\.\d+,.+,Pool Rejected%=(\d+\.\d+),/g) {
								my $poolid = $1; my $purl = $2; my $pstat = $3; my $ppri = $4; my $pdiff = $5; my $prej = $6; 
								if ($ppri == $plm && $pstat eq "Alive") {
									$pname = $2 if ($purl =~ m|://(\w+-?\w+\.)+?(\w+-?\w+\.\w+:\d+)|); 
								}
							}
							$plm++;
						}
						$pname = "N/A" if (! defined $pname); 
	 		    	$pdata .= "<td>" . $pname . "</td>";
	 				} else { $pdata .= "<td>N / A</td>"; }
		 			if ($summary ne "None") {
		 				my $mrt = 0; $mrt = $1 if $summary =~ /Elapsed=(\d+),/;
		 				if ($mrt > 0) {
			 				my $mmhs = $1 if $summary =~ /MHS\sav=(\d+\.\d+),/;
			 				$mmhs = sprintf("%.2f", $mmhs);
				 			my $mwu = $1 if $summary =~ /Work\sUtility=(\d+\.\d+),/;
			 				$mwu = sprintf("%.2f", $mwu);
			 				my $mrat = $1 if $summary =~ /Device Rejected%=(\d+.\d+),/;
							$mrat =  sprintf("%.2f%%", $mrat);
							my $mhwe = $1 if $summary =~ /Hardware Errors=(\d+),/;
							my $mrth; my $minert; 
							my $mname = ""; my $mvers = ""; my $avers; 
							if ($vers =~ m/Miner=(\w+)?\s?(\d+\.\d+\.\d+),API=(\d+\.\d+)/) {
								$mname = $1 if (defined $1);
				  			$mvers = $2; 
				  			$avers = $3; 
							} else {
								$mname = "unknown";
							}				
							$ndata .= "<td>$mname v$mvers";
		 				  $mrth = sprintf("%dD %02d:%02d",(gmtime $mrt)[7,2,1]);
		 				  $ndata .= "<br>" . $mrth . "</td>";
		 					$ndata .= "<td>" . $mmhs . " Mh/s</td>";
		 					$ndata .= $pdata;
		 					$ndata .= "<td>" . $mwu . "</td>";
		 					$ndata .= "<td>" . $mrat . "</td>";
				 			if ($mhwe > 1) {
				 				  $problems++;
				 				  push(@nodemsg, "Hardware Errors");
				 				  $ndata .= "<td class='error'>" . $mhwe . "</td>";
				 			} else {
				 				 $ndata .= "<td>" . $mhwe . "</td>";
				 			}
		 				} else {
		 				  $problems++;
		 				  push(@nodemsg, "Miner Stopped");
		 				  $ndata .= "<td class='error' colspan=4>Miner Stopped</td>";
		 				}					
			 		} else { $ndata .= "<td colspan=4>Summary Info is Not Available</td>"; }

		 			if ($devices ne "None") {		
		 				my @dproblem;
						while ($devices =~ m/\b(GPU|ASC|PGA)\b=(\d).+,MHS\s\d+s=(\d+\.\d+),/g) {
							my $devid = $2; my $dhash = $3 * 1000; $dhash = sprintf("%.0f", $dhash); 
							if ($dhash < $conf{monitoring}{monitor_hash_lo}) {
								$dproblem[$devid]++;
								$problems++;
								push(@nodemsg, "Device $devid is below minimum hash rate");
								$ddata .= "<td class='error'>" . $dhash . '</TD>';
							} else {
								$ddata .= '<td>' . $dhash . '</TD>';
							}										
							$tothash += $dhash;
							$lochash += $dhash;											
						}	

						while ($devices =~ m/\b(GPU|ASC|PGA)\b=(\d).+,Temperature=(\d+.\d+),/g) {
							my $devid = $2; my $dtemp = $3; 
							if ($dtemp > 0) {
						 		if ($dtemp > $conf{monitoring}{monitor_temp_hi}) {
			 			 			$dproblem[$devid]++; 
			 			 			$problems++;
							 		push(@nodemsg, "Device $devid is over maximum temp");						
							 		$ddata .= "<td class='error'>";
							 	} elsif ($dtemp < $conf{monitoring}{monitor_temp_lo}) {
							 		$dproblem[$devid]++; 
							 		$problems++;
							 		push(@nodemsg, "Device $devid is below minimum temp");	
							 		$ddata .= "<td class='error'>";
								} else {
									$ddata .= "<td>";
								}
							 	$ddata .= sprintf("%.0f", $dtemp) . '</TD>';
							 	$notemp++
							}
						}
						while ($devices =~ m/GPU=(\d).+,Fan\sSpeed=(\d+),/g) {
							my $devid = $1; my $gfans = $2; 
							if (($gfans < $conf{monitoring}{monitor_fan_lo}) && (! $gfans eq '0')) {
								$dproblem[$devid]++;
								$problems++;
								push(@nodemsg, "GPU $devid is below minimum fan rpm");
								$ddata .= "<td class='error'>" . $gfans . '</TD>';
							} else {
								$ddata .= '<td>' . $gfans . '</TD>';
							}
						}	
						while ($devices =~ m/\b(GPU|ASC|PGA)\b=(\d+)/g) {
							$devtype = $1; my $devid = $2; 
							$devtype = "ASIC" if ($devtype eq "ASC"||$devtype eq "PGA");
	 					 	if (defined $dproblem[$devid] && $dproblem[$devid] > 0) {
	 					  	$problemdevs++;
	 					  	$problemgpus++ if ($devtype eq "GPU");
	 					  	$problemascs++ if ($devtype eq "ASIC");
	 					 	} else {
	 					  	$okdevs++;
	 					  	$okgpus++ if ($devtype eq "GPU");
								$okascs++ if ($devtype eq "ASIC");
	 					 	} 
						}
	 				} else { $ddata .= "<td colspan=$errspan>Device Data is Not Available</td>"; }
		 			if ($problems > 0) {
		 				$totproblems += $problems;
		 				$locproblems += $problems;
		 				$problemnodes++;
		 			} else { $oknodes++; }
		 		}
		 	}
 			$ddata .= "</tr>";

 			$nhead .= "<TR class='nodehdr'>";
			$nhead .= "<TD>IP / Port</TD>";
			$nhead .= "<TD>Hostname</TD>";
			$nhead .= "<TD>Miner</TD>";
			$nhead .= "<TD>Hashrate</TD>";
			$nhead .= "<TD>Active Pool</TD>";
			$nhead .= "<TD>WU</TD>";
			$nhead .= "<TD>Rej</TD>";
			$nhead .= "<TD>HW</TD>";
 			$nhead .= "<TD colspan=$dcount>$devtype Hashrate";
 			$nhead .= "s" if ($dcount > 1); 
# 			$nhead .= "</TD><TD colspan=$dcount>HW Errors</TD>";
			if ($notemp > 0) {
 				$nhead .= "<TD colspan=$dcount>Temperature";
 				$nhead .= "s" if ($dcount > 1); 
 				$nhead .= "</TD>";
 			}
	 		if ($devices =~ m/^GPU=/) {
 				$nhead .= "<TD colspan=$dcount>Fan Speed";
	 			$nhead .= "s" if ($dcount > 1); 
	 			$nhead .= "</TD>";
 			}
 			$nhead .= "</tr>";
 			$nhtml .= "<TABLE id='node'>";
			$nhtml .= $nhead;	
			$nhtml .= $ndata;	
			$nhtml .= $ddata;
			$nhtml .= '</table>';
			$ddata = ""; $ndata = ""; $nhead = "";
		}	
# Location HTML starts here		

		$lhtml .= "<div id='locsum'>";
		$lhtml .= sprintf("%.2f Mh/s",$lochash / 1000); 
		$lhtml .= " - $loc - ";

		if ($locdevs > 0) {
			$lhtml .= "$locdevs Device";
			if ($locdevs != 1)	{ $lhtml .= 's'; }
		}
		$lhtml .= ' in ' if ($locdevs>0); 
		$lhtml .= "$locnodes node"; 
		if ($locnodes != 1) { $lhtml .= 's'; }		
		if ($locproblems) {
			$lhtml .= ' with ' . $locproblems . ' problem';
			if ($locproblems != 1) { $lhtml .= 's'; }
		}
		$lhtml .= '</div>';
		$lhtml .= $nhtml;
	}

	$html .= $lhtml;

#POOLS
	$phtml = "<div id='pools'>";
	$phtml .= "<div id='locsum'>";
	$phtml .= "Active Pools";
	$phtml .= "</div>";

	$phtml .= "<div class='table' id='pooltable'>";
	$phtml .= "<div class='row' id='pthdr'>";
  $phtml .= "<div class='cell'><p>URL</p></div>";
  $phtml .= "<div class='cell'><p>Worker</p></div>";
  $phtml .= "<div class='cell'><p>Difficulty</p></div>";
  $phtml .= "<div class='cell'><p>Reject %</p></div>";
  $phtml .= "<div class='cell'><p>Node Pri</p></div>";
  $phtml .= "<div class='cell'><p>Alias</p></div>";
	$phtml .= "</div>";
	
	$sth = $dbh->prepare("SELECT * FROM Pools"); $sth->execute(); 
	my $pall = $sth->fetchall_arrayref(); $sth->finish();	
	my $pcount = 0;
	foreach my $prow (@$pall) {
 		my ($purl, $puser, $ppass, $pupdated, $pstatus, $ppri, $pdiff, $prej, $palias, $plast) = @$prow;
 		if ($plast +90 > $now) {
			$phtml .= "<div class='row'>";
	    $phtml .= "<div class='cell'><p>$purl</p></div>";
			if (length($puser) > 20) { 
	    	$puser = substr($puser, 0, 6) . " ... " . substr($puser, -6, 6) if (index($puser, '.') < 0);
	  	} 
	    $phtml .= "<div class='cell'><p>$puser</p></div>";
	    $phtml .= "<div class='cell'><p>$pdiff</p></div>";
	    $phtml .= "<div class='cell'><p>$prej</p></div>";
	    $phtml .= "<div class='cell'><p>$ppri</p></div>";
	    $phtml .= "<div class='cell'><p>$palias</p></div>";
	    $phtml .= "</div>";
	    $pcount++;
	  }  
  }
	$phtml .= "</div></div>";
	$html .= $phtml; 
	$html .= "</div>";

	$head = "<div id='overview'>";	
		$head .= "<div id='logo' class='odata'><IMG src='/IFMI/IFMI-FM-logo.png'></div>" ;	
	
		$head .= "<div id='overviewhash' class='odata'>";
		$head .= sprintf("%.2f", $tothash / 1000 ) . " Mh/s</div>";

		$head .= "<div id='overviewdevs' class='odata'>";    
		if (($okgpus + $problemgpus) >0) {
			if ($problemgpus == 0) {
				$head .= "$okgpus GPUs in the farm<br>";
			} else {
				$head .= "$problemgpus of " . ($okgpus + $problemgpus) . " GPUs";
				if ($problemgpus == 1) {
					$head .= ' has problems<br>';
				} else {
			 		$head .= ' have problems<br>';
				}    
			}
		} else { 
			$head .= "No GPUs in the farm<br>";
		}
		if (($okascs + $problemascs) >0) {
			if ($problemascs == 0) {
				$head .= "$okascs ASICs in the farm<br>";
			} else {
				$head .= "$problemascs of " . ($okascs + $problemascs) . " ASICs";
				if ($problemascs == 1) {
					$head .= ' has problems<br>';
				} else {
			 		$head .= ' have problems<br>';
				}    
			}
		} else { 
			$head .= "No ASICs in the farm<br>";
		}
		if (($okdevs + $problemdevs) >0) {
			if ($problemdevs == 0) {
				$head .= "$okdevs Devices Total";
			} else {
				$head .= "$problemdevs of " . ($okdevs + $problemdevs) . " Devices";
				if ($problemdevs == 1) {
					$head .= ' has problems';
				} else {
			 		$head .= ' have problems';
				}    
			}
		} else { 
			$head .= "No Devices in the farm!";
		}
		$head .= "</div>";    

		$head .= "<div id='overviewtotals' class='odata'>";
		$head .= "$tnodes node";
		$head .= 's' if ($tnodes != 1);
		$head .= " in ";
		$head .= "$tlocs location";
		$head .= 's' if ($tlocs > 1);
		$head .= '<br>';
		if ($problemnodes == 0) {	
			$head .= "All nodes are OK";
		} else {
			$head .= $problemnodes . " node";
			if ($problemnodes == 1) {
				$head .= ' has ';
			} else {
	 			$head .= 's have ';
			}    		
			$head .= $totproblems . " problem";
			$head .= 's' if ($totproblems != 1);
		}
		$head .= "<br>$pcount active pool";
		$head .= 's' if ($pcount != 1);
		$head .= "</div>";
		$head .= "<div id='icon' class='odata'><a href='farmsettings.pl'><img src='/IFMI/gear.png'></a></div>";
		$head .= "<div id='overviewend' class='odata'><br></div>";
	$head .= "</div>";
	$dbh->disconnect();
} else { 
	$html .= "<div id='waiting'><h1>Miner database not available!</H1><P>&nbsp;<P></div>";
}	

print "<div id='wrap'>";
print $head;
print $html;
print "</div></BODY></HTML>";

1;
