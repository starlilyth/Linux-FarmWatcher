#!/usr/bin/perl

#    This file is part of IFMI FarmWatcher.
#
#    PoolManager is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#

use warnings;
use strict;
require '/opt/ifmi/fw-getdata.pl';
use Proc::Daemon;
use Proc::PID::File;

Proc::Daemon::Init;
if (Proc::PID::File->running()) { exit(0); }
my $continue = 1;
$SIG{TERM} = sub { $continue = 0 };
while ($continue) {
	&doGetData;
	&dolistener;
 # Get the ad
  `cd /tmp ; wget --quiet -N http://ads.miner.farm/pm.html ; cp pm.html fwadata`;
	sleep 30;
}

sub dolistener {
  my $fcheck = `/bin/ps -eo command | /bin/grep -Ec /opt/ifmi/fw-listener\$`;
  if ($fcheck == 0) {
    my $pid = fork();
    if (not defined $pid) {
      die "out of resources";
    } elsif ($pid == 0) {
	    exec('/opt/ifmi/fw-listener');
    }
  }
}

1;