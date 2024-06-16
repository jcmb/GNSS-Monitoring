#! /usr/bin/awk -f
BEGIN {
FS=";";
#RS="\n";
GOT_HEADER=0;
GOT_MOUNT=0
if (ARGC != 5) {
   print "Usage: NTRIP_Check_LL HOST MOUNT_POINT LAT LONG"
   exit (100);
   }
LONG=ARGV[4];
LAT=ARGV[3];
MOUNT_POINT=ARGV[2];
HOST=ARGV[1]
#print "Mount: " MOUNT_POINT;
ARGC=1;
}

{
#print $0"@";
   if (NR==1) {
      GOT_MOUNT=1 # Say we have the mount point to avoid double error messages
      if ($0 != "SOURCETABLE 200 OK") {
         if ($0 == "ERROR - Bad Password") {
            print "NTRIP_CHECK_LL CRITICAL - " HOST ": ERROR - Bad Password: " $0;
            }
         else {
            print "NTRIP_CHECK_LL CRITICAL - " HOST ": SOURCETABLE 200 OK not found: " $0;
            }
         exit(1);
         }
      }
   else {
      if (GOT_HEADER) {
         if ($2==MOUNT_POINT) {
            GOT_MOUNT=1
            if ($10 != LAT) {
               print "NTRIP_CHECK_LL CRITICAL - " HOST"/" MOUNT_POINT ": LAT wrong " $10 " instead of " LAT;
               exit(2);
               }
            if ($11 != LONG) {
               print "NTRIP_CHECK_LL CRITICAL - " HOST "/" MOUNT_POINT ": LONG wrong " $11 " instead of " LONG;
               exit(2);
               }
            print "NTRIP_CHECK_LL OK - " HOST "/" MOUNT_POINT ": Data OK ( "LAT" , "LONG" )";
            exit(0); # Got it valid so exit out
            }
      }
   else {
#      print "+"$0"*";
      GOT_HEADER = ($0 == "");
      }
   }
}

END {
   if (! GOT_MOUNT) {
      if (GOT_HEADER) {
         print "NTRIP_CHECK_LL CRITICAL - " HOST "/" MOUNT_POINT ": Did Not find the mount point";
         exit(3);
         }
      else {
         print "NTRIP_CHECK_LL CRITICAL - " HOST "/" MOUNT_POINT ": Did Not find the header end";
         exit(3);
         }
      }
}
