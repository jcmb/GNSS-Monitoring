#! /usr/bin/perl
use strict;

use Monitoring::Plugin;
use WWW::Mechanize;
use File::Basename;
use Data::Dumper;

use constant VERSION => "1.0.0";
use constant URL => "http://jcmbsoft.com";
use constant BLURB => "NAGIOS Plug in for montitoring Trimble SPS receivers, will work with any modern Trimble high precision GNSS receiver with the programatic interface enabled";
use constant EXTRA => "Extra";

my $np = Monitoring::Plugin->new(
    usage => "Usage: %s [ -v|--verbose ] [-H <host>] [-t <timeout>]  [-h Help] [-A|--auth yes|anonymous|no] ",
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
    spec       => 'Auth|A=s',
    help       => [
    "Authorization",
    "Expected Authorization",
    ],
    label      => [ 'Authorization', 'Auth' ],
    required   => 1,
);

$np->getopts;
my $opts=$np->opts;
my $host=$opts->hostname();
my $auth=$opts->Auth();
my $verbose=$opts->verbose();

my $got_opt=1;

my $code;
my $message;

my $mech = WWW::Mechanize->new(autocheck=>0, timeout=>$opts->timeout());

print "Host: $host\n" if $verbose>1;

my $result=$mech->get("http://$host/prog/show?PdopMask");

#print "After Get\n";
#print $result->code."\n";

if ($result->code == 403) {
   $np->nagios_exit(UNKNOWN, 'Error Connecting to Server');
   } 

if ($result->code == 401) {
    if ($auth eq "yes") {
       $np->nagios_exit(OK, 'AUTHORIZATION is set as expected');
       }
    else {
       $np->nagios_exit(CRITICAL, 'AUTHORIZATION is required but should not be');
       }
   } 


my $PDOP=-99;
my @fields = split(/\n/,$mech->content);

if (@fields[0] =~ /^PdopMask mask=(.*)$/) {
#   print "@fields[0] *$1*\n";
   $PDOP=$1;
#   print $PDOP;
   }
else
   {
   $np->nagios_exit(UNKNOWN, 'Invalid PDOP  Reply.');
   }

$result=$mech->get("http://$host/prog/set?PdopMask&mask=$PDOP");
my @fields = split(/\n/,$mech->content);

#print Dumper(@fields);
if (@fields[0] =~ /^ERROR/) 
   {
   if ($auth eq "anonymous") {
      $np->nagios_exit(OK, 'AUTHORIZATION is anonymous as expected');
      }
   else {
      $np->nagios_exit(CRITICAL, "AUTHORIZATION is anonymous but should be $auth");
      }
   }
else  
   {
   if ($auth eq "no") {
      $np->nagios_exit(OK, 'AUTHORIZATION is none as expected');
      }
   else {
      $np->nagios_exit(CRITICAL, "AUTHORIZATION is none should be $auth");
      }
   }
   
$np->nagios_exit(UNKNOWN, "Internal Error");
