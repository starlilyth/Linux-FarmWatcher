#!/usr/bin/perl
#    This file is part of IFMI FarmManager.
#
package farmsettings;

use warnings;
use strict;
use CGI qw(:cgi-lib :standard);
use DBI;
use POSIX;
my $now = time;

use base qw(Exporter);
our @EXPORT = qw(make_settings_html);

sub make_settings_html {
	my ($dbname, $in) = @_;
	my %in = %{$in};
	require '/opt/ifmi/fw-common.pl';

	my $apooln = $in{'npoolurl'};
	if (defined $apooln) {
		my $apoolu = $in{'npooluser'};
		my $apoolp = $in{'npoolpw'};
		my $apoola = $in{'npoola'};
		my $userid = ""; $userid = $in{'user_id'} if (defined $in{'user_id'});
	  &addFMPool($apooln, $apoolu, $apoolp, $apoola, $userid);
	  $apooln = ""; $apoolu = ""; $apoolp = ""; $apoola = "";
	}
	my $upoolnu = $in{'upoolurluser'};
	if (defined $upoolnu) {
		my @upu = split(/,/, $upoolnu);
		my $upooln = $upu[0];
		my $upoolu = $upu[1];
		my $upoolp = $in{'upoolpw'};
		my $upoola = $in{'upoola'};
		my $userid = ""; $userid = $in{'user_id'} if (defined $in{'user_id'});
		&updateFMPool($upooln, $upoolu, $upoolp, $upoola, $userid);
		$upooln = ""; $upoolu = ""; $upoolp = ""; $upoola = "";
	}
	my $dpool = $in{'delpool'};
	if (defined $dpool) {
		my $duser = $in{'deluser'};
		my $userid = ""; $userid = $in{'user_id'} if (defined $in{'user_id'});
	  &deleteFMPool($dpool, $duser, $userid);
	  $dpool = "";
	}
	my $anodeip = $in{'nnip'};
	if (defined $anodeip) {
		my $anodep = $in{'nnport'};
		my $anodeh = $in{'nnname'};
		my $anodeu = $in{'nnuname'};
		my $anodepw = $in{'nnpass'};
		my $anodeg = $in{'nngroup'};
		my $userid = ""; $userid = $in{'user_id'} if (defined $in{'user_id'});
	  &addFMNode($anodeip, $anodep, $anodeh, $anodeu, $anodepw, $anodeg, $userid);
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
		my $userid = ""; $userid = $in{'user_id'} if (defined $in{'user_id'});
		&updateFMNode($unodeip, $unodeh, $unodep, $unodeg, $unodeu, $unodepw, $userid);
		$unodeip = ""; $unodeh = ""; $unodep = ""; $unodeg = ""; $unodeu = ""; $unodepw = "";
	}
	my $dnode = $in{'delnode'};
	if (defined $dnode) {
		my $dport = $in{'delport'};
		my $userid = ""; $userid = $in{'user_id'} if (defined $in{'user_id'});
	  &deleteFMNode($dnode, $dport, $userid);
	  $dnode = ""; $dport = "";
	}

	my $delmp = $in{'delmprof'};
	if (defined $delmp) {
		my $userid = ""; $userid = $in{'user_id'} if (defined $in{'user_id'});
	  &deleteMonProf($delmp, $userid);
	  $delmp = "";
	}
	my $ummonprof = $in{'mprofid'};
	if (defined $ummonprof) {
		my $umpname = $in{'mpname'};
		my $umphr = $in{'mprate'};
		my $umprr = $in{'mprr'};
		my $umphw = $in{'mphw'};
		my $umpthi = $in{'mpthi'};
		my $umptlo = $in{'mptlo'};
		my $umpfhi = $in{'mpfhi'};
		my $umpflo = $in{'mpflo'};
		my $umpllo = $in{'mpllo'};
		my $userid = ""; $userid = $in{'user_id'} if (defined $in{'user_id'});
		&updateMonProf($ummonprof, $umpname, $umphr, $umprr, $umphw, $umpthi, $umptlo, $umpfhi, $umpflo, $umpllo, $userid);
		$ummonprof = ""; $umphr = ""; $umprr = ""; $umphw = ""; $umpthi = ""; $umptlo = ""; $umpfhi = ""; $umpflo = ""; $umpllo = "";
	}

	my $nmmp = $in{'mprofid'};
	if (defined $nmmp) {
		my $nmpnip = $in{'mprofip'};
		my $nmpnport = $in{'mprofport'};
		my $userid = ""; $userid = $in{'user_id'} if (defined $in{'user_id'});
		&setNodeMP($nmmp, $nmpnip, $nmpnport, $userid);
		$nmmp = "";
	}

	my $npn = $in{'pnotify'};
	if (defined $npn) {
		my $paurl = $in{'purln'};
		my $acount = 0;
		$npn = "";
	}

	my $nfwt = $in{'fwtheme'};
	my $nfwp = $in{'ufwp'};
	if (defined $nfwt || defined $nfwp) {
		&setSettings($nfwt, $nfwp);
		$nfwt = ""; $nfwp = "";
	}


	my $dbh; my $nodeh; my $phtml; my $head; my $mhtml; my $sethtml; my $fwt;
	if (-e $dbname) {
		$dbh = DBI->connect("dbi:SQLite:dbname=$dbname", { RaiseError => 1 }) or die $DBI::errstr; my $sth;
		my $adata = `cat /opt/ifmi/fwadata`;
		$nodeh .= "<div class='cell' id=adblock>$adata</td></div><br>" if ($adata ne "");
		$nodeh .= "<div id='nodelist' class='form'>";
		my $ncount = $dbh->selectrow_array("SELECT COUNT() FROM Miners");
		$nodeh .= "<div class='table'>";
		$nodeh .= "<div class='title'>$ncount Nodes</div><br>";

		$nodeh .= "<div class='row'>";
		$nodeh .= "<form name='nadd' method='POST'><b>Add Node</b> ";
		$nodeh .= "<input type='text' placeholder='IP or Hostname' size='18' name='nnip' required> ";
		$nodeh .= "<input type='text' size='4' placeholder='4028' name='nnport'> ";
		$nodeh .= "<input type='text' placeholder='Alias' name='nnname'> ";
		$nodeh .= "<input type='text' placeholder='Farm Group' name='nngroup'> ";
		$nodeh .= "<input type='submit' value='Add'>";
		$nodeh .= "</form></div><br>";

		$nodeh .= "<div class='row'>";
		$nodeh .= "<form name=nupdate method=post>";
		$nodeh .= "<b>Edit Node</b> ";
	  $nodeh .= "<select name=unipport>";
		my $mallm = $dbh->selectall_arrayref("SELECT IP, Port FROM Miners");
	 	foreach my $nrow (@$mallm) {
	 		my ($nodeip, $nodeport) = @$nrow;
	  	$nodeh .= "<option value=$nodeip,$nodeport>$nodeip | $nodeport</option>";
	  }
	  $nodeh .= "</select> ";
		$nodeh .= "<input type='text' placeholder='Alias' name='unname'> ";
		$nodeh .= "<input type='text' placeholder='Farm Group' name='ungroup'> ";
		$nodeh .= "<input type='submit' value='Change'></form>";
	  $nodeh .= "</div><br>";

		$nodeh .= "</div><div class='table'>";

	  $nodeh .= "<div class='header'>";
		$nodeh .= "<div class='row'>";
	  $nodeh .= "<div class='cell'>IP</div>";
	  $nodeh .= "<div class='cell'>Port</div>";
	  $nodeh .= "<div class='cell'>Hostname</div>";
	  $nodeh .= "<div class='cell'>Farm Group</div>";
	  $nodeh .= "<div class='cell'>Last Update</div>";
	  $nodeh .= "<div class='cell'>Status</div>";
	  $nodeh .= "<div class='cell'>Version</div>";
	  $nodeh .= "<div class='cell'>Active Pool</div>";
	  $nodeh .= "<div class='cell'>Mon. Profile</div>";
	  $nodeh .= "<div class='cell'>Remove</div>";
		$nodeh .= "</div></div>";
		my $mall = $dbh->selectall_arrayref("SELECT * FROM Miners");
		foreach my $mrow (sort { $a->[0] cmp $b->[0] } @$mall) {
	 		my ($mip, $mport, $mhost, $muser, $mpass, $mfg, $mupdated, $mdevs, $mpools, $msum, $vers, $macc, $monprof, $amail) = @$mrow;
			$nodeh .= "<div class='row'>";
	    $nodeh .= "<div class='cell'><A href=ssh://root@" . $mip . '>' . $mip . '</a></div>';
	    $nodeh .= "<div class='cell'>$mport</div>";
	    $nodeh .= "<div class='cell'><A href=https://$mip/index.html target='_blank'>$mhost</a></div>";
	    $nodeh .= "<div class='cell'>$mfg</div>";
	 		if ($mupdated != 0) {
	 			if ($now > $mupdated+65) {
	 				$mupdated = POSIX::strftime("%m-%d %H:%M", localtime($mupdated));
	    		$mupdated = "<div class='warn'>$mupdated";
	 			} else {
	 				$mupdated = POSIX::strftime("%m-%d %H:%M", localtime($mupdated));
	  	  	$mupdated = "<div class='ok'>$mupdated";
	    	}
	    } else { $mupdated = "<div class='warn'>never"; }
	    $nodeh .= "<div class='cell'>$mupdated</div></div>";
	    my $macch = "<div class='warn'>Unknown";
	    $macch = "<div class='ok'>R W" if ($macc eq "S");
	    $macch = "<div class='warn'>R O" if ($macc eq "D");
	    $macch = "<div class='warn'>R O" if ($macc eq "E");
	    $macch = "<div class='warn'>U<small>navailable</small>" if ($macc eq "U");
	    $macch = "<div class='error'>F<small>ailed<br>connection</small>" if ($macc eq "F");
	    $nodeh .= "<div class='cell'>$macch</div></div>";

			my $mname = ""; my $mvers = "";
			if (defined $vers && $vers =~ m/Miner=(\w+)?\s?(\d+\.\d+\.\d+),API/) {
				$mname = $1 if (defined $1);
				$mvers = $2;
			} else {
				$mname = "unknown";
			}
	    $nodeh .= "<div class='cell'>$mname $mvers</div>";
	    $nodeh .= "<div class='cell'>";
			my $mplm=0; my $mpname;
			if (defined $mpools && $mpools =~ m/^POOL=/) {
				while ($mplm < 5) {
					while ($mpools =~ m/POOL=(\d).+,?URL=(.+?),Status=(\w+?),Priority=(\d),.+,User=(.+?),/g) {
						my $mpoolid = $1; my $mpurl = $2; my $mpstat = $3; my $mppri = $4; my $mpusr = $5;
						if ($mppri == $mplm && $mpstat eq "Alive") {
							$mpname = $2 if ($mpurl =~ m|://(\w+-?\w+\.)+?(\w+-?\w+\.\w+:\d+)|);
						}
					}
					last if ($mpname ne "");
					$mplm++;
				}
			}
			$mpname = "N/A" if (!defined $mpname);
	  	$nodeh .= "" . $mpname . "";
	    $nodeh .= "</div>";
      $nodeh .= "<div class='cell'>";
			$nodeh .= "<form name=mpselect method=post>";
	  	$nodeh .= "<select name=mprofid>";
			my $mpallm = $dbh->selectall_arrayref("SELECT ID FROM MProfiles");
		 	foreach my $mprow (@$mpallm) {
	 			my ($mpid) = @$mprow;
	 			if ((defined $monprof) && ($mpid eq $monprof)) {
		  		$nodeh .= "<option selected='selected' value=$mpid>$mpid</option>";
		  	} else {
		  		$nodeh .= "<option value=$mpid>$mpid</option>";
		  	}
	  	}
	  	$nodeh .= "</select> ";
			$nodeh .= "<input type='hidden' name='mprofip' value='$mip'><input type='hidden' name='mprofport' value='$mport'>";
			$nodeh .= "<input type='submit' value='Set'></form>";
	    $nodeh .= "</div>";
	    $nodeh .= "<div class='cell'>";
	    $nodeh .= "<form name='mdelete' method='POST'><input type='hidden' name='delport' value='$mport'>";
	    $nodeh .= "<input type='hidden' name='delnode' value='$mip'><input type='submit' value='X'>";
		  $nodeh .= "</form></div>";
	    $nodeh .= "</div>";
	 	}
		$nodeh .= "</div></div>";

		$mhtml .= "<div id='monlist' class='form'>";
		$mhtml .= "<div class='table'>";
		$mhtml .= "<div class='title'>Monitoring Profiles</div><br>";
		$mhtml .= "<div class='row'>Values not reported by a device are not used</div>";
		$mhtml .= "<form name=mpupdate method=post>";
		$mhtml .= "<b>Edit Profile</b> ";
	  $mhtml .= "<select name=mprofid>";
		my $mpallm = $dbh->selectall_arrayref("SELECT ID FROM MProfiles");
	 	foreach my $mprow (@$mpallm) {
	 		my ($mpid) = @$mprow;
	  	$mhtml .= "<option value=$mpid>$mpid</option>";
	  }
	  $mhtml .= "<option value='new'>New</option>";
	  $mhtml .= "</select> ";
		$mhtml .= "<input type='text' placeholder='Name' name='mpname'> ";
		$mhtml .= "<input type='text' size='4' placeholder='Lo H' name='mprate'> ";
		$mhtml .= "<input type='text' size='4' placeholder='Rej %' name='mprr'> ";
		$mhtml .= "<input type='text' size='3' placeholder='HW E' name='mphw'> ";
		$mhtml .= "<input type='text' size='3' placeholder='T Hi' name='mpthi'> ";
		$mhtml .= "<input type='text' size='3' placeholder='T Lo' name='mptlo'> ";
		$mhtml .= "<input type='text' size='4' placeholder='F Hi' name='mpfhi'> ";
		$mhtml .= "<input type='text' size='4' placeholder='F Lo' name='mpflo'> ";
		$mhtml .= "<input type='text' size='3' placeholder='L Lo' name='mpllo'> ";
		$mhtml .= "<input type='submit' value='Update'></form>";

		$mhtml .= "</div><div class='table'>";

	  $mhtml .= "<div class='header'>";
		$mhtml .= "<div class='row'>";
	  $mhtml .= "<div class='cell'>Profile</div>";
	  $mhtml .= "<div class='cell'>Name</div>";
	  $mhtml .= "<div class='cell'>Hash Low</div>";
	  $mhtml .= "<div class='cell'>Reject %</div>";
	  $mhtml .= "<div class='cell'>HW Errors</div>";
	  $mhtml .= "<div class='cell'>Temp High</div>";
	  $mhtml .= "<div class='cell'>Temp Low</div>";
	  $mhtml .= "<div class='cell'>Fan High</div>";
	  $mhtml .= "<div class='cell'>Fan Low</div>";
	  $mhtml .= "<div class='cell'>Load Low</div>";
	  $mhtml .= "<div class='cell'>Remove</div>";
		$mhtml .= "</div></div>";
		my $mpall = $dbh->selectall_arrayref("SELECT * FROM MProfiles");
		foreach my $mprow (@$mpall) {
	 		my ($mpid, $mpname, $hlow, $rrhi, $hwe, $tmphi, $tmplo, $fanhi, $fanlo, $loadlo) = @$mprow;
			$mhtml .= "<div class='row'>";
	  	$mhtml .= "<div class='cell'>$mpid</div>";
	  	$mhtml .= "<div class='cell'>$mpname</div>";
	  	$mhtml .= "<div class='cell'>$hlow Kh/s</div>";
	  	$mhtml .= "<div class='cell'>$rrhi %</div>";
	  	$mhtml .= "<div class='cell'>$hwe</div>";
	  	$mhtml .= "<div class='cell'>$tmphi C</div>";
	  	$mhtml .= "<div class='cell'>$tmplo C</div>";
	  	$mhtml .= "<div class='cell'>$fanhi RPM</div>";
	  	$mhtml .= "<div class='cell'>$fanlo RPM</div>";
	  	$mhtml .= "<div class='cell'>$loadlo %</div>";
	    $mhtml .= "<div class='cell'>";
	    if ($mpid >0) {
		    $mhtml .= "<form name='mpdel' method='POST'><input type='hidden' name='delmprof' value='$mpid'>";
		    $mhtml .= "<input type='hidden' name='mpdel' value='$mpid'><input type='submit' value='X'>";
			  $mhtml .= "</form>";
			}
			$mhtml .= "</div></div>";
		}
		$mhtml .= "</div></div>";

		$phtml .= "<div id='poollist' class='form'>";
		my $pcount = $dbh->selectrow_array("SELECT COUNT() FROM Pools");
		$phtml .= "<div class='table'><div class='title'>$pcount Pools</div><br>";
		# $phtml .= "<div class='row'>";
		# $phtml .= "<form name='padd' method='POST'><b>Add Pool</b> ";
		# $phtml .= "<input type='text' size='45' placeholder='MiningURL:portnumber' name='npoolurl' required> ";
		# $phtml .= "<input type='text' placeholder='username.worker' name='npooluser' required> ";
		# $phtml .= "<input type='text' placeholder='worker password' name='npoolpw'> ";
		# $phtml .= "<input type='text' placeholder='Pool Alias' name='npoola'> ";
		# $phtml .= "<input type='submit' value='Add'></form>";
	  # $phtml .= "</div><br>";
		$phtml .= "<div class='row'>";
		$phtml .= "<form name=pupdate method=post>";
		$phtml .= "<b>Edit Pool</b> ";
	  $phtml .= "<select name=upoolurluser>";
		my $pallm = $dbh->selectall_arrayref("SELECT URL, Worker FROM Pools");
	 	foreach my $prow (@$pallm) {
	 		my ($poolurl, $pooluser) = @$prow;
	 		my $plusr = $pooluser;
			if (length($plusr) > 20) {
		    $plusr = substr($pooluser, 0, 6) . " ... " . substr($pooluser, -6, 6) if (index($pooluser, '.') < 0);
		  }
			my $plurl = $1 if ($poolurl =~ m/^.+?:\/\/(.+)/);
	  	$phtml .= "<option value=$poolurl,$pooluser>$plurl | $plusr</option>";

	  }
	  $phtml .= "</select> ";
#		$phtml .= "<input type='text' placeholder='worker password' name='upoolpw'> ";
		$phtml .= "<input type='text' placeholder='Pool Alias' name='upoola'> ";
		$phtml .= "<input type='submit' value='Change'></form>";
	  $phtml .= "</div><br>";
		$phtml .= "</div><div class='table'>";


	  $phtml .= "<div class='header'>";
		$phtml .= "<div class='row'>";
	  $phtml .= "<div class='cell'>URL</div>";
	  $phtml .= "<div class='cell'>Worker</div>";
#	  $phtml .= "<div class='cell'>Password</div>";
	  $phtml .= "<div class='cell'>Alias</div>";
	  $phtml .= "<div class='cell'>Status</div>";
#	  $phtml .= "<div class='cell'>Notify</div>";
	  $phtml .= "<div class='cell'>Last Used</div>";
		$phtml .= "</div></div>";
		my $pall = $dbh->selectall_arrayref("SELECT * FROM Pools");
		foreach my $prow (sort { $b->[9] <=> $a->[9] } @$pall) {
	 		my ($purl, $puser, $ppass, $pupdated, $pstatus, $ppri, $pdiff, $prej, $palias, $plast) = @$prow;
			my $pusr = $puser;
			if (length($pusr) > 20) {
		    $pusr = substr($pusr, 0, 6) . " ... " . substr($pusr, -6, 6) if (index($pusr, '.') < 0);
		  }
			$phtml .= "<div class='row'>";
	    $phtml .= "<div class='cell'>$purl</div>";
	    $phtml .= "<div class='cell'>$pusr</div>";
	    $ppass = "(none)" if ($ppass eq "");
#	    $phtml .= "<div class='cell'>$ppass</div>";
	    $phtml .= "<div class='cell'>$palias</div>";
	    if ($pstatus eq "unknown") {
		    $pstatus = "<div class='warn'>$pstatus";
		  } elsif ($pstatus eq "Dead") {
		    $pstatus = "<div class='error'>$pstatus";
		  } else {
		    $pstatus = "<div class='ok'>$pstatus";
			}
	    $phtml .= "<div class='cell'>$pstatus</div></div>";
	  # 	$phtml .= "<div class='cell'>";
			# $phtml .= "<form name='pooln' method='POST'>";
			# $phtml .= "<input type=hidden name='purln' value=$purl>";
		 #  my $pdnotify;
	  # 	if ((defined $pdnotify) && ($pdnotify==1)) {
		 #  	$phtml .= "<input type='checkbox' name='pdnotify' checked>Dead ";
		 #  } else {
	 	#   	$phtml .= "<input type='checkbox' name='pdnotify'>Dead ";
		 #  }
		 #  my $plnotify;
	  # 	if ((defined $plnotify) && ($plnotify==1)) {
		 #  	$phtml .= "<input type='checkbox' name='plnotify' checked>Live ";
		 #  } else {
	 	#   	$phtml .= "<input type='checkbox' name='plnotify'>Live ";
		 #  }
		 #  $phtml .= "<input type='submit' value='Save'></form>";
	  #   $phtml .= "</div>";
			if ($plast != 0) {
	 			if ($plast +90 > $now) {
	 				$plast = "<div class='ok'>Active</div>";
				} else {
			 		$plast = POSIX::strftime("%m-%d %H:%M", localtime($plast));
			 	}
	 		} else { $plast = "unknown"; }
	    if ($pupdated + 120 < $now) {
	 			$phtml .= "<div class='cell'>";
	    	$phtml .= "<form name='pdelete' method='POST'><input type='hidden' name='deluser' value='$puser'>";
	    	$phtml .= "<input type='hidden' name='delpool' value='$purl'><input type='submit' value='Remove'>";
		  	$phtml .= "</form></div>";
	 	  } else {
		    $phtml .= "<div class='cell'>$plast</div>";
		  }

	    $phtml .= "</div>";
	 	}
		$phtml .= "</div></div>";

		my @sall = $dbh->selectrow_array("SELECT * FROM Settings");
		my ($fcss, $fport, $unpdel, $supdated, $sstatus) = @sall;
		$fwt = $fcss;
		$sethtml .= "<div id='settings' class='form'>";
	  $sethtml .= "<div class='table'>";
		$sethtml .= "<div class='title'>Settings</div><br>";
		$sethtml .= "<form name=setupdate method=post>";
		$sethtml .= "<b>Edit Settings</b><br>";
		$sethtml .= "<select name=fwtheme>";
		my @csslist = glob("/var/www/IFMI/themes/fw*.css");
    foreach my $file (@csslist) {
      $file =~ s/\/var\/www\/IFMI\/themes\///;
      if ("$file" eq "$fcss") {
          $sethtml .= "<option value=$file selected>$file</option>";
        } else {
       		$sethtml .= "<option value=$file>$file</option>";
        }
    }
		$sethtml .= "</select> ";
		$sethtml .= "<input type='text' placeholder='Port' size=5 name='ufwp'> ";
		$sethtml .= "<input type='submit' value='Set'>";
		$sethtml .= "</form></div>";
	  $sethtml .= "<div class='table'>";
	  $sethtml .= "<div class='header'>";
	  $sethtml .= "<div class='row'>";
	  $sethtml .= "<div class='cell'>Theme</div>";
	  $sethtml .= "<div class='cell'>Port</div>";
	  # $sethtml .= "<div class='cell'>Auto Pool Delete</div>";
	  # $sethtml .= "<div class='cell'>Last Update</div>";
	  # $sethtml .= "<div class='cell'>Status</div>";
		$sethtml .= "</div></div>";
		$sethtml .= "<div class='row'>";
		$sethtml .= "<div class='cell'>$fcss</div>";
		$sethtml .= "<div class='cell'>$fport</div>";
		# $sethtml .= "<div class='cell'>$unpdel</div>";
		# $sethtml .= "<div class='cell'>$supdated</div>";
		# $sethtml .= "<div class='cell'>$sstatus</div>";
		$sethtml .= "</div>";
		$sethtml .= "</div></div>";

		$dbh->disconnect();
	} else {
		$nodeh .= "<div id='nodelist'><h1>Miner database not available!</H1></div>";
		$phtml .= "";
	}
	return ($nodeh, $phtml, $mhtml, $sethtml, $fwt);
}

sub run_farmsettings_as_cgi {
	use CGI;
	my $dbname = "/opt/ifmi/fm.db";
	my %in = Vars;
	my $fm_name = `hostname`; chomp $fm_name;
	my $iptxt = "1.1.1.1"; my $nicget = `/sbin/ifconfig`;
	  while ($nicget =~ m/(\w\w\w\w?\d)(:0)?\s.+\n\s+inet addr:(\d+\.\d+\.\d+\.\d+)\s/g) {
	  $iptxt = $3;
	}
	my ($nodeh, $phtml, $mhtml, $sethtml, $fwt) = make_settings_html($dbname, \%in);
	my $q=CGI->new();
	print header;
	print start_html( -title=>$fm_name . ' - FW Settings',
										-style=>{-src=>"/IFMI/themes/$fwt"},
										-head=>$q->meta({-http_equiv=>'REFRESH',-content=>'30'}));

	my $html;
	$html .= "<div id='overview' nowrap>";
	$html .= "<div id='logo' class='odata'><IMG src='/images/IFMI-FM-logo.png'></div>" ;
	$html .= "<div class='odata'><h2>$fm_name \@ $iptxt</h2></div>";
	$html .= "<div id='icon' class='odata'><a href='farmstatus'><img src='/images/overview.png'></a></div>";
	$html .= "</div>";
	$html .= "<div id='confpage' class='container'>";
	$html .= "<div id='confform' class='content'>";

	print $html;
	print $nodeh;
	print $mhtml;
	print $phtml;
	print "<br>" . $sethtml;
	print "</div></div></BODY></HTML>";
}

run_farmsettings_as_cgi(my $in) unless caller;

1;
