#!/usr/local/bin/perl

my @date = localtime (time());
my $day = $date[3];
my $num_month = 1+$date[4];
my $year = 1900+$date[5];
my $month;

if ($num_month == "1") {
   $month = "January";
} elsif ($num_month == "2") {
   $month = "February"; 
} elsif ($num_month == "3") { 
   $month = "March"; 
} elsif ($num_month == "4") { 
   $month = "April"; 
} elsif ($num_month == "5") { 
   $month = "May"; 
} elsif ($num_month == "6") { 
   $month = "June"; 
} elsif ($num_month == "7") { 
   $month = "July"; 
} elsif ($num_month == "8") { 
   $month = "August"; 
} elsif ($num_month == "9") { 
   $month = "September"; 
} elsif ($num_month == "10") { 
   $month = "October"; 
} elsif ($num_month == "11") { 
   $month = "November"; 
} elsif ($num_month == "12") { 
   $month = "December"; 
} else {
   $month = "UNKNOWN";
}

open (MOTD, "/etc/motd");
my @motd = <MOTD>;
close (MOTD);

my $daymonthyear = "$day $month $year\n";

push @motd, "                                        installed $daymonthyear";
push @motd, "                                        patched $daymonthyear";

open (MOTD_WRITE, ">/etc/motd");
print MOTD_WRITE @motd;
close (MOTD_WRITE);
