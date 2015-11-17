#! /usr/bin/perl
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
    usage => "Usage: %s [ -v|--verbose ]  [-H <host>] [-t <timeout>] [-U|--User User:Pass] [-h Help] [ -c|--critical=<threshold> ] [ -w|--warning=<threshold> ] [ -p|--port Power_Port ]",
    version => VERSION,
    blurb   => BLURB,
    extra   => EXTRA,
    url     => URL,
    plugin  => basename $0,
    timeout => 15,
);

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
     default => '9',
     help => '-w, --warning=INTEGER. Minimum voltage on the port',
    );

 $np->add_arg(
     spec => 'critical|c=s',
     default => '2',
     help => '-c, --critical=INTEGER. Minimum voltage on the port. ');

 $np->add_arg(
     spec => 'port|p=s',
     help => '-p --port=INTEGER the port that the power is being monitored on',
     required  => 1
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
$np->get("http://$host/prog/show?Voltages");

my $volts=-1;
my @fields = split(/\n/,$np->content);
my $port=$opts->port()+1;
print "@fields[$port]\n";

if (@fields[$port] =~ /volts=(.*)$/) {
   print "$port @fields[$port] $1\n";
   $volts=$1;
   }

$code = $np->check_threshold(
   check => $volts,
   warning => $warning_threshold,
   critical => $critical_threshold,
   );

$np->nagios_exit($code, "Voltage on $port is $volts");
