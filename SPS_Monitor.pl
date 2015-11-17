#! /usr/bin/perl
# nagios: -epn

use strict;

use Nagios::Plugin;
use Nagios::Plugin::WWW::Mechanize;
use WWW::Mechanize;
use File::Basename;
use Data::Dumper;
use XML::Simple;

use constant VERSION => "0.1.0";
use constant URL => "http://jcmbsoft.dyndns.info";
use constant BLURB => "NAGIOS Plug in for montitoring Trimble SPS receivers, will with any modern high precision GNSS receiver with web interface with the programatic interface enabled";
use constant EXTRA => "Extra";

my $np = Nagios::Plugin::WWW::Mechanize->new(
    usage => "Usage: %s [ -v|--verbose ]  [-H <host>] [-t <timeout>]   [-U|--User User:Pass] [-h Help] [-P|--Pos Pos_Type] [-D|--Data Data_Setting] [-B|--Battery] [-C|--Clock] [--PDOP PDOP] [--Elev Elev] [--TestMode yes|no] [--Everest yes|no] [--Motion static|kinematic]",

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
    spec       => 'Pos|P=s',
    help       => [
    "Expected Position Type"
    ],
    label      => [ 'Position Type'],
    required  => 0,
);

$np->add_arg(
    spec       => 'Data|D=s',
    help       => [
    "L,M,P Receiver should be Data Logging with files of length L minutes, with Measurements at M Seconds, and Positions at P seconds. M and P default to 1 second"
    ],
    label      => [ 'Data Logging'],
    required  => 0
);

$np->add_arg(
    spec       => 'User|U=s',
    help       => [
    "User name and password, if security is enabled. Format user:password"
    ],
    label      => [ 'Data Logging'],
    required  => 0
);

$np->add_arg(
    spec       => 'Battery|B',
    help       => [
    "Receiver should be on external power not battery"
    ],
    label      => [ 'Battery'],

    required  => 0,
);

$np->add_arg(
    spec       => 'Clock|C=s',
    help       => [
    "Receiver should have clock steering in this mode"
    ],
    label      => [ 'Clock steering'],
    required  => 0,
);

$np->add_arg(
    spec       => 'PDOP=i',
    help       => [
    "PDOP Mask the Reciever should have."
    ],
    label      => [ 'PDOP'],

    required  => 0,
);

$np->add_arg(
    spec       => 'Elev=i',
    help       => [
    "Elevation Mask the receiver should have."
    ],
    label      => [ 'Elevation Mask'],

    required  => 0,
);

$np->add_arg(
    spec       => 'TestMode=s',
    help       => [
    "If the Receiver is in Test Mode, options are no or yes."
    ],
    label      => [ 'Test Mode'],
    required  => 0,
);

$np->add_arg(
    spec       => 'Everest=s',
    help       => [
    "If the Receiver has Everest enabled, options are no or yes."
    ],
    label      => [ 'Test Mode'],
    required  => 0,
);

$np->add_arg(
    spec       => 'Motion=s',
    help       => [
    "If the Receiver is in the given motion state."
    ],
    label      => [ 'Test Mode'],
    required  => 0,
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
my $xs = XML::Simple->new();
#print "hello";
my $expected_pos = $opts->Pos();
#print "there";
#exit;
my $got_opt=0;

my $code;
my $message;
my $ref;
my $pos;

#print $expected_pos."\n";
#print $opts->Pos()."\n";
print "Host: $host\n" if $verbose>1;

print "Checking programatic enabled\n" if $verbose>1;
#$np->get("http://$host/prog/show?commands");

if ($opts->Pos()) {
   $got_opt=1;

   print "Checking position\n" if $verbose;

   $np->get("http://$host/prog/show?position");
#   $ref = $xs->XMLin($np->content);
#   $pos = $ref->{'position'}->{'soln'};
   my @fields = split(/\n/,$np->content);
#   print $opts->Pos()."*\n";
#   print Dumper(@fields);

   for (my $i=0;$i<=@fields;$i++) {
      if (@fields[$i] =~ /^Qualifiers *(.*)$/) {
#         print "$i @fields[$i] $1\n";
         my @pos_type = split(/,/,$1);
#         print Dumper(@pos_type);
         my $pos_types=$1;
#	 print "type $pos_types\n";
	 my $pos_opts = $opts->Pos();
#	 print "opts $pos_opts\n";
         if ($pos_types =~ $pos_opts) {
            $np->add_message('OK',"Position type is $pos_types.");
            }
         else
            {
            $np->add_message('CRITICAL',"Position type is $pos_types which does not contain $expected_pos.");
            }
         }
      }
   }

#print "After check\n";

if ($opts->Data()) { #Can't get Auto Delete so we need to get it in two parts
   my @Data_Setting=split(/,/,$opts->Data());
   @Data_Setting[1] = "1" unless defined(@Data_Setting[1]);
   @Data_Setting[2] = "1" unless defined(@Data_Setting[2]);
   @Data_Setting[1] .= ".0" unless @Data_Setting[1] =~ /\./;
   @Data_Setting[2] .= ".0" unless @Data_Setting[2] =~ /\./;

#   print @Data_Setting[1]."\n\n";
   print "Checking data: @Data_Setting[0] @Data_Setting[1] @Data_Setting[2]\n" if $verbose;
   $got_opt=1;
   my $A_session_valid=0; #if at least one session is valid;
   $np->get("http://$host/prog/show?sessions");
   my $data_logging_enabled = 1;
   my @fields = split(/\n/,$np->content);
   #print Dumper(@fields);
   for (my $i=1;$i<@fields;$i++) {
      if (@fields[$i] =~ /^session *(.*)$/) {
#         print "$i @fields[$i] $1\n";
         my $session_details=$1;
         my $session_valid =1;
         if (!($session_details =~ "enabled=yes")) {
            print "Data Session $i is not enabled\n" if $verbose;
            $session_valid=0;
            }
         else {
            if (!($session_details =~ "schedule=continuous")) {
               print "Data Session $i is not continuous\n" if $verbose;
               $session_valid=0;
               }
            else {
               if (!($session_details =~ "durationMin=@Data_Setting[0]")) {
                  print "Data Session $i is not @Data_Setting[0] long\n" if $verbose;
                  $session_valid=0;
                  }
               else {
                  if (!($session_details =~ "measInterval=@Data_Setting[1]")) {
                     print "Data Session $i is not logging measurements at @Data_Setting[1]\n" if $verbose;
                     $session_valid=0;
                     }
                  else {
                     if (!($session_details =~ "posInterval=@Data_Setting[2]")) {
                        print "Data Session $i is not logging positions at @Data_Setting[2]\n" if $verbose;
                        $session_valid=0;
                        }
                     else {
                        if (!($session_details =~ "nameStyle=YYMMDDhh")) {
                           print "Data Session $i is not using name Style YYMMDDhh\n" if $verbose;
                           $session_valid=0;
                           };
                        };
                     };
                  };
               };
            };
         $A_session_valid |= $session_valid; #if at least one session is valid;
         };
      };


   if (!$A_session_valid) { #The error reporting is poor because of the fact there could be mutiple sessions
      $np->add_message('CRITICAL','Data Logging is not configured correctly.');
      }
   else {
      $np->add_message('OK','Data Logging is configured correctly.');
      }

   $np->get("http://$host/xml/dynamic/dataLogger.xml");
   $ref = $xs->XMLin($np->content);

   my $Auto_Delete = $ref ->{'fileSystem'}->{'/Internal'}->{'autoDelete'};
   if ($Auto_Delete ne '1') {
      $np->add_message('CRITICAL','Auto Delete not enabled.');
      }
   else {
      $np->add_message('OK','Auto Delete is enabled.');
      }
   };

if ($opts->Battery) {
   $got_opt=1;
   $np->get("http://$host/xml/dynamic/powerData.xml");
   $ref = $xs->XMLin($np->content);
#   print Dumper($ref);
   my $battery_active = $ref->{'B1'}->{'active'};
#   print Dumper($battery_active);
#   print $battery_active;
   if (defined($battery_active) && ($battery_active eq 'TRUE')) {
#      print "failed";
      $np->add_message('CRITICAL','Battery is being used.');
   }
   else {
#      print "worked";
      $np->add_message('OK','Battery is not being used.');
   }
}

if ($opts->Clock()) {
   $got_opt=1;

   print "Checking ClockSteering\n" if $verbose;
   my $Clock = $opts->Clock();

   $np->get("http://$host/prog/show?ClockSteering");

   my $Clock_Reply = $np->content;
   print $Clock_Reply if $opts->verbose>2;
   chomp($Clock_Reply);


   my @fields = split(/\n/,$np->content);
   if (@fields[0] =~ /^ClockSteering enable=(.*)$/) {
#      print "@fields[0] $1\n";
      if ($1 eq $Clock) {
         $np->add_message('OK',"ClockSteering is correct at $Clock.");
         }
      else
         {
         $np->add_message('CRITICAL',"ClockSteering is incorrect at $1 not $Clock.");
         }
      }
   else {
      $np->add_message('CRITICAL',"ClockSteering could not be determined.");
      }
   }

if ($opts->PDOP()) {
   $got_opt=1;

   print "Checking PDOP\n" if $verbose;

   $np->get("http://$host/prog/show?PdopMask");
   my $PDOP_Reply = $np->content;
   chomp($PDOP_Reply);
   my $PDOP = $opts->PDOP();

   if ($PDOP_Reply =~ /^PdopMask mask=/) {
      if ($PDOP_Reply =~ /^PdopMask mask=$PDOP/) {
         $np->add_message('OK',"PDOP is $PDOP.");
         }
      else
         {
         $PDOP_Reply =~ /^PdopMask mask=(\d*)/;
         $np->add_message('CRITICAL',"PDOP not $PDOP it is $1.");
         }
      }
   else {
      $np->add_message('CRITICAL',"PDOP not be determined.");
      }
   }

if ($opts->Elev()) {
   $got_opt=1;

   my $Elev = $opts->Elev();
   print "Checking Elevation is $Elev\n" if $verbose;

   $np->get("http://$host/prog/show?ElevationMask");
   my $Elev_Reply = $np->content;
   print $Elev_Reply if $verbose>2;
   chomp($Elev_Reply);

   if ($Elev_Reply =~ /^ElevationMask mask=/) {
      if ($Elev_Reply =~ /^ElevationMask mask=$Elev/) {
         $np->add_message('OK',"Elevation Mask is $Elev.");
         }
      else
         {
         $Elev_Reply =~ /^ElevationMask mask=(\d*)/;
         $np->add_message('CRITICAL',"Elev not $Elev it is $1.");
         }
      }
   else {
      $np->add_message('CRITICAL',"Elev not be determined.");
      }
   }

if ($opts->TestMode()) {
   $got_opt=1;
   my $Test = $opts->TestMode();
   print "Checking Test Mode is $Test\n" if $verbose;

   $np->get("http://$host/prog/show?TestMode");
   my $Test_Reply = $np->content;
   print $Test_Reply if $opts->verbose>2;
   chomp($Test_Reply);

   if ($Test_Reply =~ /^testMode enable=/) {
      if ($Test_Reply =~ /^testMode enable=$Test/) {
         $np->add_message('OK',"Test Mode is $Test.");
         print "Test Mode is correct at $Test.\n" if $verbose>1;
         }
      else
         {
         $Test_Reply =~ /^testMode enable=(\w*)/;
         $np->add_message('CRITICAL',"Test Mode is not $Test it is $1.");
         print "Test Mode is incorrect at $1 not $Test.\n" if $verbose>1;
         }
      }
   else {
      $np->add_message('CRITICAL',"Test Mode not be determined.");
      }
   }

if ($opts->Everest()) {
   $got_opt=1;

   print "Checking Everest\n" if $verbose;

   $np->get("http://$host/prog/show?MultipathReject");
   my $Everest_Reply = $np->content;
   chomp($Everest_Reply);
   my $Everest = $opts->Everest();

   if ($Everest_Reply =~ /^MultipathReject enable=/) {
      if ($Everest_Reply =~ /^MultipathReject enable=$Everest/) {
         $np->add_message('OK',"Everest Mode is $Everest.");
         }
      else
         {
         $Everest_Reply =~ /^MultipathReject enable=(\w*)/;
         $np->add_message('CRITICAL',"Everest is not $Everest it is $1.");
         }
      }
   else {
      $np->add_message('CRITICAL',"Everest setting could not be determined.");
      }
   }

if ($opts->Motion()) {
   $got_opt=1;

   print "Checking Motion\n" if $verbose;

   $np->get("http://$host/prog/show?RtkControls");
   my $Motion_Reply = $np->content;
   chomp($Motion_Reply);
   my $Motion = $opts->Motion();

   if ($Motion_Reply =~ /motion=/) {
      if ($Motion_Reply =~ /motion=$Motion/) {
         $np->add_message('OK',"Motion is $Motion.");
         }
      else
         {
         $Motion_Reply =~ /motion=(\w*)/;
         $np->add_message('CRITICAL',"Motion is not $Motion it is $1.");
         }
      }
   else {
      $np->add_message('CRITICAL',"Motion setting could not be determined.");
      }
   }

if ($got_opt) {
   ($code,$message) = $np->check_messages;
    $np->nagios_exit($code,$message);
   }
else
   {
   $np->nagios_exit(CRITICAL, "Did not get something to check on the command line");
   }
