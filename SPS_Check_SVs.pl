#! /usr/bin/perl
# nagios: -epn
use strict;

use Nagios::Plugin;
use Nagios::Plugin::WWW::Mechanize;
use WWW::Mechanize;
use File::Basename;
use Data::Dumper;

use constant VERSION => "0.1.0";
use constant URL => "http://jcmbsoft.dyndns.info";
use constant BLURB => "NAGIOS Plug in for montitoring Trimble SPS receivers, will with any modern high precision GNSS receiver with web interface with the programatic interface enabled";
use constant EXTRA => "Extra";

my $np = Nagios::Plugin::WWW::Mechanize->new(
    usage => "Usage: %s [ -v|--verbose ]  [-H <host>] [-t <timeout>]  [-h Help] [ -c|--critical=<threshold> ] [ -w|--warning=<threshold> ] [ -s|--SV <SV System> ]",
    version => VERSION,
    blurb   => BLURB,
    extra   => EXTRA,
    url     => URL,
    plugin  => basename $0,
    timeout => 15,
);

if (open (PROXY, '/usr/lib/nagios/plugins/proxy.perl')) {

    if (my $proxy = <PROXY>) {
	chomp($proxy);
	$np->mech->proxy(['http', 'ftp'], $proxy);
    }
    close PROXY;
}

$np->add_arg(
    spec       => 'hostname|H=s',
    help       => [
    "Hostname to query",
    "IP address to query",
    ],
    label      => [ 'HOSTNAME', 'IP' ],
    required   => 1,
);


$np->add_arg(
    spec       => 'User|U=s',
    help       => [
    "User name and password, if security is enabled. Format user:password"
    ],
    label      => [ 'User_Password'],
    required  => 0
);

 $np->add_arg(
     spec => 'warning|w=s',
     default => '4',
     help => '-w, --warning=INTEGER. Minimum Number of SV\'s needed to be tracked',
    );

 $np->add_arg(
     spec => 'critical|c=s',
     default => '1',
     help => '-c, --critical=INTEGER. Minimum Number of SV\'s needed to be tracked');

 $np->add_arg(
     spec => 'SV|s=s',
     help => '-s --SV, SV System is GPS GLN or SBS',
    );


$np->getopts;
my $opts=$np->opts;
my $host=$opts->hostname();
my $user=$opts->User();
if ($user) {
   $host=$user."@".$host;
   }

my $verbose=$opts->verbose();
#print $verbose;
#my $xs = XML::Simple->new();
#print "hello";
#print "there";
#exit;
my $got_opt=1;

my $code;
my $message;
my $warning_threshold = $opts->warning();
my $critical_threshold= $opts->critical();
$warning_threshold  .= ":" unless $warning_threshold =~ /:/;
$critical_threshold .= ":" unless $critical_threshold =~ /:/;
print "Host: $host\n" if $verbose>1;

#print "$warning_threshold\n";
$np->get("http://$host/prog/show?TrackingStatus");

my $num_sv=0;
my @fields = split(/\n/,$np->content);
my $SV_System=$opts->SV();
if ($SV_System) {
   for (my $i=1;$i<@fields;$i++) {
      if (@fields[$i] =~ /Sys=$SV_System/) {
#         print "$i @fields[$i] $1\n";
         $num_sv++;
         }
      }
   }
else
   {
   $num_sv=@fields-1;
   }

#print $expected_pos."\n";
#print $opts->Pos()."\n";


$code = $np->check_threshold(
   check => $num_sv,
   warning => $warning_threshold,
   critical => $critical_threshold,
   );

$np->nagios_exit($code, "Number of $SV_System SV's Tracked: $num_sv");
