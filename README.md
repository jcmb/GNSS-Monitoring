Simple Monitoring for NTRIP and Trimble GNSS recievers using nagios.

The state monitoring, for lots of GNSS receivers, it better done using GNSS-Dasboard

There is no installer.

The nagios directory goes somewhere in nagioss config system. It is recommended to use cfg_dir to put them all in a directory.

The scripts in the root of the project shoud go in the libexec directory

perl needs

cpan install Monitoring::Plugin
cpan install WWW::Mechanize module

and maybe

cpan install libmonitoring-plugin-perl

you need to make them executeable chmod a+x *
