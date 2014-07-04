#!/usr/bin/perl
#    This file is part of IFMI FarmManager.
#

package farmstatus;
use warnings;
use strict;
use DBI;
use POSIX;

use base qw(Exporter);
our @EXPORT = qw(make_farm_html);

sub make_farm_html {
	my ($dbname, $shownode) = @_;

	require '/opt/ifmi/fw-common.pl';
	my $now = time;
	my $dbh;
	my $tothash = 0; my $thrh; my $totproblems = 0;
	my $tlocs = 0; my $tnodes = 0;
	my $problemdevs = 0; my $okdevs = 0;
	my $problemascs = 0; my $okascs = 0;
	my $problemgpus = 0; my $okgpus = 0;
	my $problemnodes = 0; my $oknodes = 0;
	my $problempools = 0; my $okpools = 0;
	my $html = "<div id='farm' class='content'>";
	my $adata = `cat /opt/ifmi/fwadata`;
	$html .= "<div class='cell' id=adblock>$adata</td></div><br>" if ($adata ne "");
	my $head;	my $ndhtml = "<div id='node' class='content'>";

	if (-e $dbname) {
		$dbh = DBI->connect("dbi:SQLite:dbname=$dbname", { RaiseError => 1 }) or die $DBI::errstr;
		my $ndhead = ""; my $nddata = ""; my $mmhs = ""; my $nddhead = ""; my $ndddata = ""; my $ndphead = ""; my $ndpdata = "";
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
		 	my $npage = 0;
			my $nhtml = ""; my $nhead = ""; my $ndata = ""; my $ddata = "";
			my $all = $dbh->selectall_arrayref("SELECT * FROM Miners WHERE Mgroup= ?", undef, $loc);
			foreach my $row (sort { $a->[0] cmp $b->[0] || $a->[1] <=> $b->[1] } @$all) {
	 			my ($ip, $port, $name, $user, $pass, $loc, $updated, $devices, $pools, $summary, $vers, $acheck, $mprof, $amail) = @$row;
				my @monprof = $dbh->selectrow_array("SELECT * FROM MProfiles WHERE ID= ?", undef, $mprof);
				my ($mpid, $mpname, $hlow, $rrhi, $hwe, $tmphi, $tmplo, $fanhi, $fanlo, $loadlo) = @monprof;
	 			$locnodes++; $tnodes++; my @nodemsg; my $problems = 0; my $dcount = 0; my $devtype = ""; my $notemp = 0;
	 			if (defined $devices) { while ($devices =~ m/\b(GPU|ASC|PGA)\b=\d+/g) { $locdevs++; $dcount++; } }
				my $errspan = $dcount*4;
				my $nodeurl = "?";
				$npage = $tlocs + $npage;
				$nodeurl .= "node=$npage";
		 		if ($npage != $shownode) {
		 			my $mid;
		 			if ($name ne "unknown") {
		 				$mid = "  $name  <br><small>$port</small>";
		 			} else {
		 				$mid = "$ip<br><small>$port</small>";
		 			}
		 			$ndata .= "<TR class='nodedata'><td class='ndatahdr'>";
	 				$ndata .= '<A href="' . $nodeurl . '"><div>' . $mid . '</div></a></td>';
				}
				my $checkin = ($now - $updated);
				if ($checkin > 120) {
					$locproblems++;	$problemnodes++; $totproblems++;
	  			if ($updated == 0) {
						if ($npage == $shownode) {
		  				$nddata .= "<div class='table' id='nodefail'>";
		  				$nddata .= "<div class='row'><i>This node has never been reached</i></div>";
		  			} else {
		  				$ndata .= "<td colspan=3><i>This node has never been reached</i></td>";
		  			}
	  			} else {
						my $missed = int($checkin/60);
						push(@nodemsg, "Missed $missed update");
						$nodemsg[@nodemsg-1] .= "s" if ($missed > 1);
						if ($npage == $shownode) {
							$nddata .= "<div class='table' id='nodefail'>";
							$nddata .= "<div class='row'><div class='warn'>$nodemsg[0]</div></div>";
						} else {
							$ndata .= "<td class='warn' colspan=3>$nodemsg[0]</td>";
						}
				    my $ach = "U";
				    $ach = "Miner Unavailable" if ($acheck eq "U");
				    $ach = "Connection Failed" if ($acheck eq "F");
				    $nodemsg[@nodemsg-1] .= " - " . $ach;
					}
					if ($npage == $shownode) {
						$nddata .= "<div class='row'>Miner Unavailable</div></div>" if ($acheck eq "U");
						$nddata .= "<div class='row'><div class='error'>Connection Failed</div></div></div>" if ($acheck eq "F");
					} else {
						$ddata .= "<td colspan=4>Miner Unavailable</td>" if ($acheck eq "U");
			    	$ddata .= "<td colspan=4 class='error'>Connection Failed</td>" if ($acheck eq "F");
			    }
				} else {
					if ($npage == $shownode) {
						$nddata .= "<div class='row'><div class='cell'>$loc</div>";
					}
					my $pname = "N/A"; my $pdata;
	 				if ($pools ne "None") {
	 				 	my $plm=0;
		 				while ($plm < 5) {
							while ($pools =~ m/POOL=(\d).+,?URL=(.+?),Status=(\w+?),Priority=(\d),/g) {
								my $poolid = $1; my $purl = $2; my $pstat = $3; my $ppri = $4;
								if ($ppri == $plm && $pstat eq "Alive") {
									$pname = $2 if ($purl =~ m|://(\w+-?\w+\.)+?(\w+-?\w+\.\w+:\d+)|);
								}
							}
							last if ($pname ne "N/A");
							$plm++;
						}
	 		    	$pdata .= "<td>" . $pname . "</td>";
						if ($npage == $shownode) {
							while ($pools =~ m/POOL=(\d),(.+)\n/g) {
								my $poolid = $1; my $pooldata = $2;
								my $purl = $1 if ($pooldata =~ m/URL=(.+?\/\/.+?:\d+?),/);
								my $pstat = $1 if ($pooldata =~ m/Status=(\w+?),/);
								my $ppri = $1 if ($pooldata =~ m/Priority=(\d),/);
								my $puser = $1 if ($pooldata =~ m/User=(.+?),/);
								my $pdiff = $1 if ($pooldata =~ m/Last.+Last Share Difficulty=(\d+\.\d+),/);
								my $prej = $1 if ($pooldata =~ m/Pool Rejected%=(\d+\.\d+),/);
								my @pdata = $dbh->selectrow_array("SELECT LastUsed, Alias FROM Pools WHERE URL= ? AND Worker= ?", undef, $purl, $puser);
	  						my ($plast, $palias) = @pdata;
	  						if ($plast > 0) {
		  						$plast = POSIX::strftime("%m-%d %H:%M", localtime($plast));
								} else { $plast = "never" }
								my $pusr = $puser;
								if (length($pusr) > 20) {
							    $pusr = substr($pusr, 0, 6) . " ... " . substr($pusr, -6, 6) if (index($pusr, '.') < 0);
							  }
							  if ($pstat eq "unknown") {
		    					$pstat = "<div class='warn'>$pstat</div>";
		  					} elsif ($pstat eq "Dead") {
		    					$pstat = "<div class='error'>$pstat</div>";
		  					} else {
		    					$pstat = "<div class='ok'>$pstat</div>";
								}
						  	$pdiff = sprintf("%.3f", $pdiff);
		  					$prej = sprintf("%.2f", $prej);
								$ndpdata .= "<div class='row' id='tablebody'>";
								$ndpdata .= "<div class='cell'>$poolid</div>";
								$ndpdata .= "<div class='cell'>$purl</div>";
								$ndpdata .= "<div class='cell'>$pusr</div>";
								$ndpdata .= "<div class='cell'>$palias</div>";
								$ndpdata .= "<div class='cell'>$ppri</div>";
								$ndpdata .= "<div class='cell'>$pstat</div>";
								$ndpdata .= "<div class='cell'>$pdiff</div>";
								$ndpdata .= "<div class='cell'>$prej</div>";
								$ndpdata .= "<div class='cell'>$plast</div>";
								$ndpdata .= "</div>";
							}
						}
	 				}
	 				my $shwe = 0; my $srrat = 0; my $shrl = 0;
		 			if ($devices ne "None") {
		 				my @dproblem;
						if ($npage == $shownode) {
							while ($devices =~ m/\b(GPU|ASC|PGA)\b=(.+?)\n/g) {
								$devtype = $1; my $devdata = $2;
								$devtype = "ASIC" if ($devtype eq "ASC"||$devtype eq "PGA");
								my $devid = $1 if ($devdata =~ m/^(\d),/);
								my $dstat = $1 if ($devdata =~ m/Status=(\w+),/);
								my $dhash = $1 * 1000 if ($devdata =~ m/MHS\s\d+s=(\d+\.\d+),/);
								$dhash = sprintf("%.0f", $dhash); my $hdhash = "$dhash Kh/s";
								$tothash += $dhash; $lochash += $dhash;
								if ($dhash < $hlow) {
									$dproblem[$devid]++; $problems++; $shrl++;
									push(@nodemsg, "Device $devid is below minimum hash rate");
									$hdhash = "<div class='error'>" . $hdhash . '</div>';
								}
								my $dpool = $1 if ($devdata =~ m/Pool=(\d),/);
								my $dacc = $1 if ($devdata =~ m/Accepted=(\d+),/);
								my $drej = $1 if ($devdata =~ m/Rejected=(\d+),/);
								my $drrat = $1 if ($devdata =~ m/Device Rejected%=(\d+\.\d+),/);
								my $rsum;
								if ($drrat > $rrhi) {
									$dproblem[$devid]++; $problems++; $srrat++;
									push(@nodemsg, "Device $devid is above reject rate");
									$rsum = "<div class='error'>$dacc / $drej ($drrat%)</div>";
								} else { $rsum = "$dacc / $drej ($drrat%)"; }
								my $dhwe = $1 if ($devdata =~ m/Hardware Errors=(\d+),/);
									if ($dhwe > $hwe) {
									$dproblem[$devid]++; $problems++; $shwe++;
									push(@nodemsg, "Device $devid is above hardware error limit");
									$dhwe = "<div class='error'>" . $dhwe . '</div>';
								}
								my $dtemp = $1 if ($devdata =~ m/Temperature=(\d+.\d+),/);
								my $dtemph;
								if ($dtemp > 0) {
							 		if ($dtemp > $tmphi) {
				 			 			$dproblem[$devid]++; $problems++;
								 		push(@nodemsg, "Device $devid is over maximum temp");
								 		$dtemph = "<div class='error'>" . sprintf("%.0f", $dtemp) . 'C</div>';
								 	} elsif ($dtemp < $tmplo) {
								 		$dproblem[$devid]++; $problems++;
								 		push(@nodemsg, "Device $devid is below minimum temp");
								 		$dtemph = "<div class='error'>" . sprintf("%.0f", $dtemp) . 'C</div>';
									} else {
								 		$dtemph = sprintf("%.0f", $dtemp) . 'C';
									}
								 	$notemp++
								}
								my ($dint, $dfans, $dfanp, $dcore, $dmem, $dpwr);
								if ($devtype eq "GPU") {
									$dfans = $1 if ($devdata =~ m/Fan Speed=(\d+),/);
									$dfanp = $1 if ($devdata =~ m/Fan Percent=(\d+),/);
									if (($dfans < $fanlo) && (! $dfans eq '0')) {
										$dproblem[$devid]++; $problems++;
										push(@nodemsg, "GPU $devid is below minimum fan rpm");
										$dfans = "<div class='error'>$dfans ($dfanp%)</div>";
									}  elsif ($dfans > $fanhi) {
										$dproblem[$devid]++; $problems++;
										push(@nodemsg, "GPU $devid is above maximum fan rpm");
										$dfans = "<div class='error'>$dfans ($dfanp%)</div>";
									} else {
										$dfans = "$dfans ($dfanp%)"
									}
									$dint = $1 if ($devdata =~ m/Intensity=(\d+),/);
									$dcore = $1 if ($devdata =~ m/GPU Clock=(\d+),/);
									$dmem = $1 if ($devdata =~ m/Memory Clock=(\d+),/);
									$dpwr = $1 if ($devdata =~ m/GPU Voltage=(\d+\.\d+),/);
								}
								$ndddata .= "<div class='row' id='tablebody'>";
								$ndddata .= "<div class='cell'>$devid</div>";
								$ndddata .= "<div class='cell'>$dstat</div>";
								$ndddata .= "<div class='cell'>$hdhash</div>";
								$ndddata .= "<div class='cell'>$dpool</div>";
								$ndddata .= "<div class='cell'>$rsum</div>";
								$ndddata .= "<div class='cell'>$dhwe</div>";
								$ndddata .= "<div class='cell'>$dtemph</div>" if ($notemp > 0);
								if ($devtype eq "GPU") {
									$ndddata .= "<div class='cell'>$dfans</div>";
									$ndddata .= "<div class='cell'>$dint</div>";
									$ndddata .= "<div class='cell'>$dcore Mhz</div>";
									$ndddata .= "<div class='cell'>$dmem Mhz</div>";
									$ndddata .= "<div class='cell'>$dpwr V</div>";
								}
								$ndddata .= "</div>";
							}
						} else {
							while ($devices =~ m/\b(GPU|ASC|PGA)\b=(\d).+,Device Rejected%=(\d+\.\d+),/g) {
								my $devid = $2; my $drrat = $3;
								if ($drrat > $rrhi) {
									$dproblem[$devid]++; $problems++; $srrat++;
									push(@nodemsg, "Device $devid is above reject rate");
								}
							}
							while ($devices =~ m/\b(GPU|ASC|PGA)\b=(\d).+,Hardware Errors=(\d+),/g) {
								my $devid = $2; my $dhwe = $3;
								if ($dhwe > $hwe) {
									$dproblem[$devid]++; $problems++; $shwe++;
									push(@nodemsg, "Device $devid is above hardware error limit");
								}
							}
							my $shdata = '<td> 0 </TD>';
							while ($devices =~ m/\b(GPU|ASC|PGA)\b=(\d).+,MHS\s\d+s=(\d+\.\d+),/g) {
								$devtype = $1; $devtype = "ASIC" if ($devtype eq "ASC"||$devtype eq "PGA");
								my $devid = $2; my $dhash = $3;
								if (defined $dhash) {
									$dhash = sprintf("%.0f", $dhash * 1000);
								} else {
								 	$dhash = 0;
								}
								if ($dhash < $hlow) {
									$dproblem[$devid]++; $problems++;
									push(@nodemsg, "Device $devid is below minimum hash rate");
									$shdata = "<td class='error'>" . $dhash . '</TD>';
								} else {
									$shdata = '<td>' . $dhash . '</TD>';
								}
								$ddata .= $shdata;
								$tothash += $dhash;
								$lochash += $dhash;
							}
							while ($devices =~ m/\b(GPU|ASC|PGA)\b=(\d).+,Temperature=(\d+.\d+),/g) {
								my $devid = $2; my $dtemp = $3;
								if ($dtemp > 0) {
							 		if ($dtemp > $tmphi) {
				 			 			$dproblem[$devid]++;
				 			 			$problems++;
								 		push(@nodemsg, "Device $devid is over maximum temp");
								 		$ddata .= "<td class='error'>";
								 	} elsif ($dtemp < $tmplo) {
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
								if (($gfans < $fanlo) && (! $gfans eq '0')) {
									$dproblem[$devid]++; $problems++;
									push(@nodemsg, "GPU $devid is below minimum fan rpm");
									$ddata .= "<td class='error'>" . $gfans . '</TD>';
								} elsif ($gfans > $fanhi) {
									$dproblem[$devid]++; $problems++;
									push(@nodemsg, "GPU $devid is above maximum fan rpm");
									$ddata .= "<td class='error'>" . $gfans . '</td>';
								} else {
									$ddata .= '<td>' . $gfans . '</TD>';
								}
							}
						}
						while ($devices =~ m/\b(GPU|ASC|PGA)\b=(\d+)/g) {
							my $devid = $2;
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

		 			if ($summary ne "None") {
		 				my $mrt = 0; $mrt = $1 if $summary =~ /Elapsed=(\d+),/;
		 				if ($mrt > 0) {
			 				$mmhs = $1 if $summary =~ /MHS\sav=(\d+\.\d+),/;
			 				$mmhs = sprintf("%.2f", $mmhs);
				 			my $mwu = $1 if $summary =~ /Work\sUtility=(\d+\.\d+),/;
			 				$mwu = sprintf("%.2f", $mwu);
			 				my $mrat = $1 if $summary =~ /Device Rejected%=(\d+.\d+),/;
							$mrat =  sprintf("%.2f%%", $mrat);
							my $mhwe = $1 if $summary =~ /Hardware Errors=(\d+),/;
			 				my $mrth = sprintf("%dD %02d:%02d",(gmtime $mrt)[7,2,1]);
							my $mname = ""; my $mvers = ""; my $avers;
							if ($vers =~ m/Miner=(\w+)?\s?(\d+\.\d+\.\d+),API=(\d+\.\d+)/) {
								$mname = $1 if (defined $1);
				  			$mvers = $2;
				  			$avers = $3;
							} else {
								$mname = "unknown";
							}
							if ($npage == $shownode) {
								$nddata .= "<div class='cell'>$mname v$mvers</div>";
						   	$acheck = "<div class='ok'>R W</div>" if ($acheck eq "S");
	    					$acheck = "<div class='warn'>R O</div>" if ($acheck eq "E");
								$nddata .= "<div class='cell'>$acheck</div>";
								$nddata .= "<div class='cell'>$mrth</div>";
								$nddata .= "<div class='cell'>$pname</div>";
								$nddata .= "<div class='cell'>$mwu</div>";
								$mrat = "<div class='error'>$mrat</div>" if (defined $mrat && $srrat > 0);
								$nddata .= "<div class='cell'>$mrat</div>";
							} else {
								$ndata .= "<td nowrap>$mname v$mvers";
			 				  $ndata .= "<br>" . $mrth . "</td>";
			 					$ndata .= $pdata;
								if ($shrl > 0) { $ndata .= "<td class='error'>" . $mmhs . " Mh/s</td>";
								} else { $ndata .= "<td>" . $mmhs . " Mh/s</td>"; }
			 					$ndata .= "<td>" . $mwu . "</td>";
								if ($srrat > 0) { $ndata .= "<td class='error'>" . $mrat . "</td>";
								} else { $ndata .= "<td>" . $mrat . "</td>"; }
					 			if ($shwe > 0) { $ndata .= "<td class='error'>" . $mhwe . "</td>";
					 			} else { $ndata .= "<td>" . $mhwe . "</td>"; }
				 			}
		 				} else {
		 				  $problems++;
		 				  push(@nodemsg, "Miner Stopped");
		 				  $ndata .= "<td class='error' colspan=4>Miner Stopped</td>";
		 				}
			 		} else { $ndata .= "<td colspan=4>Summary Info is Not Available</td>"; }


		 			if ($problems > 0) {
		 				$totproblems += $problems;
		 				$locproblems += $problems;
		 				$problemnodes++;
		 			} else { $oknodes++; }
			 	}


				if ($npage == $shownode) {
		 			$nddata .= "</div></div>";
		 		} else {
		 			$ddata .= "</tr>";
		 		}
				if ($npage == $shownode) {
					$ndhead .= '<div class="row" id="olink"><a href="farmstatus"><b>Back to Overview</b></a> ';
					$ndhead .= " | <div class='cell'>$adata</div>" if ($adata ne "");
					$ndhead .= "</div><br><div id='locsum'> $name ($ip / $port) - $mmhs Mh/s with $dcount Device";
					$ndhead .= "s" if ($dcount != 1);
					$ndhead .= "</div>";
					if ($checkin < 65) {
						$ndhead .= "<div class='table' id='nodedetail'>";
						$ndhead .= "<div class='header'>";
						$ndhead .= "<div class='row'>";
						$ndhead .= "<div class='cell'>Farm Group</div>";
						$ndhead .= "<div class='cell'>Miner</div>";
						$ndhead .= "<div class='cell'>Status</div>";
						$ndhead .= "<div class='cell'>Runtime</div>";
						$ndhead .= "<div class='cell'>Active Pool</div>";
						$ndhead .= "<div class='cell'>WU</div>";
						$ndhead .= "<div class='cell'>Rej %</div>";
						$ndhead .= "</div></div>";

						$nddhead .= "<div class='table' id='devdetail'>";
						$nddhead .= "<div class='header'>";
						$nddhead .= "<div class='row'>";
						$nddhead .= "<div class='cell'>$devtype</div>";
						$nddhead .= "<div class='cell'>Status</div>";
						$nddhead .= "<div class='cell'>Hashate</div>";
						$nddhead .= "<div class='cell'>Pool</div>";
						$nddhead .= "<div class='cell'>Accept/Reject</div>";
						$nddhead .= "<div class='cell'>HW</div>";
						$nddhead .= "<div class='cell'>Temp</div>" if ($notemp > 0);
						if ($devtype eq "GPU") {
							$nddhead .= "<div class='cell'>Fan</div>";
							$nddhead .= "<div class='cell'>I</div>";
							$nddhead .= "<div class='cell'>Core</div>";
							$nddhead .= "<div class='cell'>Memory</div>";
							$nddhead .= "<div class='cell'>Power</div>";
						}
						$nddhead .= "</div></div>";

						$ndphead .= "<div class='table' id='pooldetail'>";
						$ndphead .= "<div class='header'>";
						$ndphead .= "<div class='row'>";
					  $ndphead .= "<div class='cell'>Pool</div>";
					  $ndphead .= "<div class='cell'>URL</div>";
					  $ndphead .= "<div class='cell'>Worker</div>";
					  $ndphead .= "<div class='cell'>Alias</div>";
					  $ndphead .= "<div class='cell'>Pri</div>";
					  $ndphead .= "<div class='cell'>Status</div>";
					  $ndphead .= "<div class='cell'>Difficulty</div>";
					  $ndphead .= "<div class='cell'>Reject %</div>";
					  $ndphead .= "<div class='cell'>Last Used</div>";
						$ndphead .= "</div></div>";
					}

				} else {
		 			$nhead .= "<TR class='nodehdr'>";
					$nhead .= "<TD>ID</TD>";
					$nhead .= "<TD>Miner</TD>";
					$nhead .= "<TD>Active Pool</TD>";
					$nhead .= "<TD>Hashrate</TD>";
					$nhead .= "<TD>WU</TD>";
					$nhead .= "<TD>Rej</TD>";
					$nhead .= "<TD>HW</TD>";
		 			$nhead .= "<TD colspan=$dcount>$devtype Hashrate" if ($dcount > 0);
		 			$nhead .= "s" if ($dcount > 1);
					if ($notemp > 0) {
		 				$nhead .= "<TD colspan=$dcount>Temperature";
		 				$nhead .= "s" if ($dcount > 1);
		 				$nhead .= "</TD>";
		 			}
			 		if ((defined $devices && $devtype eq "GPU") && ($checkin < 120)){
		 				$nhead .= "<TD colspan=$dcount>Fan Speed";
			 			$nhead .= "s" if ($dcount > 1);
			 			$nhead .= "</TD>";
		 			}
		 			$nhead .= "</tr>";
		 		}

	 			$nhtml .= "<TABLE id='node'>";
				$nhtml .= $nhead;
				$nhtml .= $ndata;
				$nhtml .= $ddata;
				$nhtml .= '</table>';
				$ddata = ""; $ndata = ""; $nhead = "";
				$npage++;
			}

		# Location

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

		$ndhtml .= $ndhead;
		$ndhtml .= $nddata;
		$ndhtml .= $nddhead;
		$ndhtml .= $ndddata;
		$ndhtml .= "</div>";
		$ndhtml .= $ndphead;
		$ndhtml .= $ndpdata;
		$ndhtml .= "</div>";

		#POOLS

		$phtml = "<div class='table' id='pooltable'>";
		$phtml .= "<div class='header' id='pthdr'>";
	  $phtml .= "<div class='row'>";
	  $phtml .= "<div class='cell'>URL</div>";
	  $phtml .= "<div class='cell'>Worker</div>";
	  $phtml .= "<div class='cell'>Difficulty</div>";
	  $phtml .= "<div class='cell'>Reject %</div>";
	  $phtml .= "<div class='cell'>Node Pri</div>";
	  $phtml .= "<div class='cell'>Alias</div>";
		$phtml .= "</div></div>";

		my $pcount = 0;
		my $pall = $dbh->selectall_arrayref("SELECT * FROM Pools");
		foreach my $prow (@$pall) {
	 		my ($purl, $puser, $ppass, $pupdated, $pstatus, $ppri, $pdiff, $prej, $palias, $plast) = @$prow;
	 		if ($plast +90 > $now) {
				$phtml .= "<div class='row' id='tablebody'>";
		    $phtml .= "<div class='cell'>$purl</div>";
				if (length($puser) > 20) {
		    	$puser = substr($puser, 0, 6) . " ... " . substr($puser, -6, 6) if (index($puser, '.') < 0);
		  	}
		  	$pdiff = sprintf("%.3f", $pdiff) if (defined $pdiff);
		  	$prej = sprintf("%.2f", $prej) if (defined $prej);
		    $phtml .= "<div class='cell'>$puser</div>";
		    $phtml .= "<div class='cell'>$pdiff</div>" if (defined $pdiff);
		    $phtml .= "<div class='cell'>$prej</div>" if (defined $prej);
		    $phtml .= "<div class='cell'>$ppri</div>";
		    $phtml .= "<div class='cell'>$palias</div>";
		    $phtml .= "</div>";
		    $pcount++;
		  }
	  }

		my $phdr = "<div id='pools'><div id='locsum'>$pcount Active Pool Account";
		$phdr .= 's' if ($pcount != 1);
		$phdr .= "</div>";
		$html .= $phdr;
		$html .= $phtml;
		$html .= "</div>";

		# Overview

		$head = "<div id='overview' nowrap>";
			$head .= '<div id="logo" class="odata"><a href="https://miner.farm/"><IMG src="/images/IFMI-FM-logo.png"></a></div>';

			$head .= "<div id='overviewhash' class='odata'>";
			$thrh = sprintf("%.2f", $tothash / 1000 );
			$head .= "$thrh Mh/s</div>";

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
			$head .= "<br>$pcount active pool account";
			$head .= 's' if ($pcount != 1);
			$head .= "</div>";
			$head .= "<div id='icon' class='odata'><a href='farmsettings'><img src='/images/gear.png'></a></div>";
		$head .= "</div>";
		$dbh->disconnect();
	} else {
		$html .= "<div id='waiting' class='content'><h1>Miner database not available!</H1><P>&nbsp;<P></div>";
	}
	return ($thrh, $head, $shownode > -1 ? $ndhtml : $html);
}

sub run_farmstatus_as_cgi {
	use CGI;
	my $dbname = "/opt/ifmi/fm.db";

	# Now carry on
	my $shownode = -1;
	my $fm_name = `hostname`; chomp $fm_name;
	my $q=CGI->new();
	if (defined($q->param('node'))) {
		$shownode = $q->param('node');
	}
	my $url = "?";
	if ($shownode > -1) {
		$url .= "node=$shownode\&";
	}

	# Put it all together
	my ($thrh, $head, $html) = make_farm_html($dbname, $shownode);

	print $q->header;
	if ($url =~ m/\?.+/) {
		print $q->start_html( -title=>$fm_name . ' - ' . $thrh  . ' Mh/s',
			-style=>{-src=>'/IFMI/fwdefault.css'},
			-head=>$q->meta({-http_equiv=>'REFRESH',-content=>'30'})
		);
	} else {
		$url .= "overview";
		print $q->start_html( -title=>$fm_name . ' - ' . $thrh  . ' Mh/s',
			-style=>{-src=>'/IFMI/fwdefault.css'},
			-head=>$q->meta({-http_equiv=>'REFRESH',-content=>'30; url=' . $url })
		);
	}
	print "<div id='wrap'>";
	print $head;
	print $html;
	print "</div></BODY></HTML>";
}

run_farmstatus_as_cgi() unless caller;

1;
