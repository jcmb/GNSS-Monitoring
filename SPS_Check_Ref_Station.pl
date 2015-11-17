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
    usage => "Usage: %s [ -v|--verbose ]  [-H <host>] [-t <timeout>] [-U|--User User:Pass] [-h|--Help] [-l|--Latitude Latitude] [-o|--Longitude Longitude] [-z|--Height Height] [-n|--Name Name] [-c|--Code Code]",
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
     spec => 'Latitude|l=s',
     help => '-l --Latitude=REAL the Latitude of the reference station',
     required  => 1
    );

 $np->add_arg(
     spec => 'Longitude|o=s',
     help => '-o --Longitude=REAL the Longitude of the reference station',
     required  => 1
    );

 $np->add_arg(
     spec => 'Height|z=s',
     help => '-o --Height=REAL the height of the reference station',
     required  => 1
    );

 $np->add_arg(
     spec => 'Name|n=s',
     help => '-n --Name=String the pointname of the reference station',
     required  => 0
    );

 $np->add_arg(
     spec => 'Code|c=s',
     help => '-o --Height=String the code of the reference station',
     required  => 0
    );
$np->getopts;
my $opts=$np->opts;
my $host=$opts->hostname();
my $user=$opts->User();
if ($user) {
   $host=$user."@".$host;
   }

my $verbose=$opts->verbose();

my $Ref_Latitude  = $opts->Latitude();
my $Ref_Longitude = $opts->Longitude();
my $Ref_Height    = $opts->Height();
my $Ref_Name      = $opts->Name();
my $Ref_Code      = $opts->Code();

my $code;
my $message;

print "Host: $host\n" if $verbose>1;

#print "$warning_threshold\n";
$np->get("http://$host/prog/show?RefStation");

my $had_error=0;
$np->add_message('OK',"Latitude: $Ref_Latitude, Longitude: $Ref_Longitude, Height: $Ref_Height, Name: ". ($Ref_Name?$Ref_Name:"Not Checked"). ", Code: ". ($Ref_Code?$Ref_Code:"Not Checked"));

my @fields = split(/\n/,$np->content);
if (@fields[0] =~ /RefStation lat=(.*) lon=(.*) height=(.*) Rtcm2Id=.* Name='(.*)' Code='(.*)'$/) {
   my $Latitude=$1;
   my $Longitude=$2;
   my $Height=$3;
   my $Name=$4;
   my $Code=$5;
   if ($Ref_Latitude != $Latitude) {
       $np->add_message('CRITICAL',"Latitude should be $Ref_Latitude it is $Latitude.");
      }

   if ($Ref_Longitude != $Longitude) {
       $np->add_message('CRITICAL',"Longitude should be $Ref_Longitude it is $Longitude.");
      }

   if ($Ref_Height != $Height) {
       $np->add_message('CRITICAL',"Height should be $Ref_Height it is $Height.");
      }

   if ($Ref_Name && ($Ref_Name ne $Name)) {
       $np->add_message('CRITICAL',"Name should be $Ref_Name it is $Name.");
      }

   if ($Ref_Code && ($Ref_Code ne $Code)) {
       $np->add_message('CRITICAL',"Code should be $Ref_Code it is $Code.");
      }
   }

($code,$message) = $np->check_messages;
$np->nagios_exit($code, $message);
