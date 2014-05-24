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

require '/opt/ifmi/fm-getdata.pl';
#require '/opt/ifmi/pmnotify.pl';

use Proc::PID::File;
if (Proc::PID::File->running()) {
  # one at a time, please
  print "Another run-farmmanager is running.\n";
  exit(0);
}

# Get data
 &doGetData;

# # Email 
# if ($conf{monitoring}{do_email} == 1) { 
#   if (-f "/tmp/pmnotify.lastsent") {
#     if (time - (stat ('/tmp/pmnotify.lastsent'))[9] > ($conf{email}{smtp_min_wait} -10)) {
#       &doEmail;
#     }
#   } else { &doEmail; }
# }

# # Graphs should be no older than 5 minutes
# my $graph = "/var/www/IFMI/graphs/msummary.png";
# if (-f $graph) {
#   if (time - (stat ($graph))[9] > 290) { 
#     exec('/opt/ifmi/pmgraph.pl'); 
#   }
# } else { 
#   exec('/opt/ifmi/pmgraph.pl'); 
# }

