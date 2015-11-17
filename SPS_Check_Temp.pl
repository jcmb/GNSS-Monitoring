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
    usage => "Usage: %s [ -v|--verbose ]  [-H <host>] [-t <timeout>]  [-h Help] [ -c|--critical=<threshold> ] [ -w|--warning=<threshold> ] ",
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
     default => '-10:50',
     help => '-w, --warning=INTEGER:INTEGER .  See '
       . 'http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT '
       . 'for the threshold format. ',
    );

 $np->add_arg(
     spec => 'critical|c=s',
     default => '-30:60',
     help => '-c, --critical=INTEGER:INTEGER .  See '
       . 'http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT '
       . 'for the threshold format. ',
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

#print "$warning_threshold\n";
$np->get("http://$host/prog/show?Temperature");

my $temp=-99;
my @fields = split(/\n/,$np->content);
   #print Dumper(@fields);
if (@fields[0] =~ /^Temperature temp=(.*)$/) {
#   print "@fields[0] *$1*\n";
   $temp=$1;
   }
else
   {
   $np->nagios_exit(UNKNOWN, 'Invalid Temperature Reply.');
   }

#print $expected_pos."\n";
#print $opts->Pos()."\n";
print "Host: $host\n" if $verbose>1;



$code = $np->check_threshold(
   check => $temp,
   warning => $warning_threshold,
   critical => $critical_threshold,
   );

$np->nagios_exit($code, "Temperature is $temp");
