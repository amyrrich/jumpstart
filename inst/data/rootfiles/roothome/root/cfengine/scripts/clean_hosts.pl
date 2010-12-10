#!/usr/local/bin/perl

######################| clean_hosts.pl |########################
##
##  This program:
##  * cleans up /etc/hosts after jumpstart, adding the public
##    IP as well as the private one and installing the jumpstart
##    naming convention. (This is just until cfengine runs.)
##  * sets up the default route
##  * sets up the /etc/hostname.interface files
##  * plumbs the ethernet interfaces
##
##  This version of the program does runs out of jumpstart.
##
######################| clean_hosts.pl |########################

use warnings;
use strict;

use Sys::Hostname;
use File::Copy;

use Net::Netmask;

$ENV{'PATH'} = '/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin';

######
## Global Variable Declaration
######

# If this host is on jumpstart, the rootdir might not be "/"
my $rootdir = "/";

# Where are the files we're editing?
my $etc_hosts = "$rootdir/etc/inet/hosts";	## Hey, ya never know...
my $netmasks = "$rootdir/etc/inet/netmasks";
my $defaultrouter_file = "$rootdir/etc/defaultrouter";

my $jumpnet_insert = "jumpnet";
my $domain_name = "my.domain";

my @adapter_types = ("eri0", "eri1", "hme0", "hme1", "dmfe0", "dmfe1", "ce0", "ce1", "fcip0", "fcip1", "bge0", "bge1", "bge2", "bge3", "qfe0", "qfe1", "qfe2", "qfe3", "e1000g0", "e1000g1", "e1000g2", "e1000g3", "e1000g4", "e1000g5", "ipge0", "ipge1", "ipge2", "ipge3", "pcn0", "pcn1");

##########################| subroutine stubs |##############################

######
## returnIP takes a hostname, a subdomain, and a domain and returns the
## IP of that fqdn.
######

sub returnIP;

######################| main body of the code |#########################

my $fqdn = hostname;
my @temp_fqdn = split /\./, $fqdn, 3;
my $hostname = $temp_fqdn[0];
my $subdomain = $temp_fqdn[1];

my $jqdn = "$temp_fqdn[0]\.$subdomain\.$jumpnet_insert\.$domain_name";;
if ($subdomain =~ "my") {
  $jqdn = "$temp_fqdn[0]\.$jumpnet_insert\.$domain_name";
}

my $local_jnet_prefix;
my $found_jnet;

#####
## read in /etc/hosts
#####

open (HOSTS, "$etc_hosts") or die "Can't open $etc_hosts: $!";
my @hosts = <HOSTS>;
foreach (@hosts) {
  if (m/192\.168\..*$hostname/) {
     my @temp = split;
     @temp = split /\./, $temp[0], 4;
     $local_jnet_prefix = $temp[2];
     $found_jnet = 'yes';
  } else {
     next;
  }
}
close (HOSTS) or die "Can't close $etc_hosts: $!";

if (! $found_jnet) {
  die "HOSTS: Can't get local jumpnet numbers!";
}

#####
## OK, first we clean up the incorrect info in /etc/hosts so it doesn't screw
## up things (nsswitch.conf: resolv - hosts dns)
##
## First, make a backup.
#####

copy ("$etc_hosts", "$etc_hosts\.backup") 
   or die "HOSTS: Couldn't backup $etc_hosts: $!";

#####
## Set the private DNS server based on the jnet_prefix that we got out
## of /etc/hosts
#####

my $dns_server = "192.168.$local_jnet_prefix.254";
my $private_subnet = "192.168.$local_jnet_prefix."; 

   ######
   ## If the jnet prefix is 0, we want the dns server on jnet 1.
   ######

   $dns_server = "192.168.1.254" if $local_jnet_prefix == 0;

#####
## Now find the line that's got 192.168 in it and rename that line to 
## host.sub.$jumpnet
#####

my $cfd_jump="$dns_server	cfd-jump.my.domain";
my $jump_there;

foreach (@hosts) {
   if (m/$private_subnet/) {
      if (m/$fqdn/g) {
         s/$fqdn/$jqdn/g;
         s/loghost//;
      }
   }
   if (m/$cfd_jump/) {
      $jump_there = 1;
   }
}

if (! $jump_there) {
   push @hosts, "$cfd_jump\n";
}

#####
## now output the fixed file to wherever the hostfile is.
#####

open (HOSTS_OUT, ">$etc_hosts");
print HOSTS_OUT @hosts;
## Don't close hosts yet, we still have one more thing to stick in there...

#####
## OK, make sure we can get to dns somewhere; cfengine should clear this out
## the next time it runs, so don't worry about getting rid of it.
#####

open (RESOLV, ">/etc/resolv.conf");
print RESOLV "nameserver $dns_server\n";
print "HOSTS: Temporary nameserver $dns_server\n";
close (RESOLV);

#####
## Now what the hell is my public IP?
#####

my $new_IP = returnIP($fqdn);
print "HOSTS: New IP: $new_IP\n";
chomp($new_IP);

#####
## OK, now stick that new information in at the end of the file
#####

print HOSTS_OUT "$new_IP\t$fqdn\tloghost\n";

#####
## NOW close the hosts file for writing.
#####
close (HOSTS_OUT);

#######################

#####
## /etc/defaultrouter fixing
#####

my $defaultrouter;

open (NETMASKS, "$netmasks")
   or die "DEFAULT ROUTER: Could not open $netmasks: $!";

while (<NETMASKS>) {
   ######
   ## The 192.168 addresses are never going to be the default router.
   ######
   if (m/PUB\.IP\./) {
      ## Yoink the excess white space.
      s/\s+/ /;

      ## Now figure out what this network/netmask pair is.
      my @temp_storage = split / /, $_;
      my $network = $temp_storage[0];
      my $netmask = $temp_storage[1];
      chomp($netmask);

      ## What netblock is defined by them?
      my $netblock = new Net::Netmask ($network, $netmask);

      ## Does my IP fit in that netblock?
      my $match = $netblock->match($new_IP);

      ## If it does, then bingo!
      if ($match > 0) {
         $defaultrouter = $netblock->nth(1);
         print "DEFAULT ROUTER: Checking $network $netmask - match: $match \n";
         last;
      } else {
         print "DEFAULT ROUTER: Checking $network $netmask - no match\n";
      }
   }
}
close (NETMASKS) or die "DEFAULT ROUTER: Could not close /etc/inet/netmasks: $!";

######
## Now, hopefully after all that, we've figured out what the defaultrouter
## for this box is, so if we have it, plop it into /etc/defaultrouter
## Otherwise, die ugly, because without defaultrouter, many things break.
######

if ($defaultrouter) {
   open (DEFAULTROUTER, ">$defaultrouter_file")
      or die "DEFAULT ROUTER: Could not open $defaultrouter_file for writing: $!";
   print DEFAULTROUTER "$defaultrouter\n";
   print "DEFAULT ROUTER: My defaultrouter: $defaultrouter\n\n";
   close (DEFAULTROUTER) 
      or die "DEFAULT ROUTER: Could not close $defaultrouter_file: $!";
} else {
   die "DEFAULT ROUTER: I did not find a netblock this machine fit in!\n";
}

######
## Set up the new public interface, and fix the old jumpstart one's name.
## First, figure out what interface is currently set up - there should
## only be one and localhost.
######

my @initial_ifconfig_output;
open (INITIAL_IFCONFIG_OUTPUT, "ifconfig -a|");
while (<INITIAL_IFCONFIG_OUTPUT>) {
   if (/^\s/) {
        $initial_ifconfig_output[$#initial_ifconfig_output] .= $_;
   } else {
        push @initial_ifconfig_output, $_;
   }
}
close (INITIAL_IFCONFIG_OUTPUT);

my $jumpnet_interface;

######
## If it's up, and it's not the localhost interface, and it's got the 
## jumpstart IP range, then it's the jumpnet interface.
######

foreach (@initial_ifconfig_output) {
  if (! m/lo0:/ ) {
     if ((m/flags=.*UP,/)&&(m/$private_subnet/)) {
        $jumpnet_interface = $_;
     }
  }
}

######
## If -nothing's- up but the lo0 interface, then there's a problem somewhere.
######

if (! defined($jumpnet_interface)) {
   die "Couldn't find the jumpnet interface.";
}

my @temp_jumpnet_interface = split /:/, $jumpnet_interface, 2;
$jumpnet_interface = $temp_jumpnet_interface[0];

######
## Now give that interface the correct /etc/hostname.interface file.
######

open (JUMPNET_HOSTNAME, ">/etc/hostname\.$jumpnet_interface")
  or die "Could not open /etc/hostname\.$jumpnet_interface: $!";
print JUMPNET_HOSTNAME "$jqdn\n";
close (JUMPNET_HOSTNAME)
  or die "Could not close /etc/hostname\.$jumpnet_interface: $!";

######
## -Now- find the what other interfaces exist that are not lo0 or
## $jumpnet_interface
######

print "ifconfig will now make some pretty error messages for you.\n";
print "\nIt can take up to a minute to plumb each interface, so don't worry\n";
print "if this takes a few minutes.\n";

foreach my $i (@adapter_types) {
  system("ifconfig $i plumb 2>&1 > /dev/null");
}

open (IFCONFIG_NOT_JUMP_LO, "ifconfig -a|") or die "Could not run ifconfig: $!";
my @ifconfig_not_jump_lo = <IFCONFIG_NOT_JUMP_LO>;
close (IFCONFIG_NOT_JUMP_LO) or die "Could not close ifconfig: $!";

my $new_interface;
my @ifconfig_split_array;
my $right_interface;
my $ping_response;
my @ping_response_array;

foreach (@ifconfig_not_jump_lo) {
   if ((m/flags=/)&&(!($right_interface))) {
      if (! m/<UP.*>/) {
         @ifconfig_split_array = split /:/, $_, 2;
         $new_interface = $ifconfig_split_array[0];

         system("ifconfig $new_interface $new_IP");
         system("ifconfig $new_interface netmask + broadcast +");
         system("ifconfig $new_interface up");
         sleep 5;

         ######
         ## Give the system a chance to catch up, then ping the default
         ## router over the new interface.  If it's the -right- interface, 
         ## we'll get an answer.
         ######

         open (PING_RESPONSE_ARRAY, 
               "ping -i $new_interface $defaultrouter 56 60|");
         @ping_response_array = <PING_RESPONSE_ARRAY>;
         close (PING_RESPONSE_ARRAY);

         $ping_response = $ping_response_array[0];
         if ($ping_response) {
            print $ping_response;

            if ($ping_response =~ /is alive/) {
               $right_interface = $new_interface;
	       print "IFCONFIG: $new_interface is the public interface.\n";
            } else {
               print "IFCONFIG: $new_interface is not the public interface.\n";
               system("ifconfig $new_interface down");
               system("ifconfig $new_interface unplumb");
            }
         }
      }
   } else {
      next;
   }
}
if ($right_interface) { 
   open (PUBLIC_HOSTNAME_OUT, ">/etc/hostname\.$right_interface");

   my $osversion = `uname -r`;
   chomp($osversion);
   if ($osversion =~ "5.10") {
     print PUBLIC_HOSTNAME_OUT "$new_IP\n";
   } elsif ($osversion =~ "5.11") {
     print PUBLIC_HOSTNAME_OUT "$new_IP\n";
   } else {
     print PUBLIC_HOSTNAME_OUT "$fqdn\n";
   }
   close (PUBLIC_HOSTNAME_OUT);
} else {
   print "ERROR: Machine's public interface wasn't determined.  Please ",
         "run \n/root/cfengine/manual_initial_cfengine_1.sh, manually ",
         "plumb the \ninterface, and reboot the box." 
}

###########################################################################
######
## Subroutine returnIP takes a hostname, a subdomain, and a domain
## and digs out the host's IP from that information.
##
## It then returns the IP.
######

sub returnIP {

   ######
   ## First we need to know what the full hostname is - if it's in the
   ## .my.domain domain proper, then we can't use the subdomain.
   ######

   my $rHostname = $_[0];

   ######
   ## OK, now we dig the IP up.
   ######

   #### We'd love to use this, but it doesn't work during jumpstart for some 
   #### strange reason.
   #### It works JUST FINE from the command line, dammit...
   ## my @gethostbyname_output = gethostbyname $rHostname;
   ## my @octets = unpack('C4',$gethostbyname_output[4]);
   ## my $rIP_new_IP = "$octets[0]\.$octets[1]\.$octets[2]\.$octets[3]";

   print "dig \@$dns_server $rHostname\n";
   my @dns_array = `dig \@$dns_server $rHostname`;

   ######
   ## Die if it's not in DNS
   ######

   my $dns_answer;
   undef($dns_answer);

   foreach (@dns_array) {
      if (m/;; ANSWER SECTION:/) {
         $dns_answer = 'yes';
      }
   }

   if (! defined($dns_answer)) {
      die "This server does not yet have a DNS entry. Try again.\n";
   }

   ######
   ## Ok, it's in DNS.  Clean out the garbage from the dig to generate
   ## $new_IP, which goes into /etc/hosts.
   ######

   my $new_IP_with_garbage;

   foreach (@dns_array) {
      if (m/$rHostname/) {
         if (m/PUB\.IP) {
            $new_IP_with_garbage = $_;
         }
      }
   }

   my @IP_with_garbage_array = split /A/, $new_IP_with_garbage, 2;
   foreach (@IP_with_garbage_array) {
      s/\s//g;
   }
   my $rIP_new_IP = $IP_with_garbage_array[1];
   chomp($rIP_new_IP);

   ######
   ## Die if it's not in DNS
   ## Otherwise, return the IP.
   ######

   if (! defined($rIP_new_IP)) {
      die "This server ($rHostname) does not yet have a DNS entry.\n";
   } else {
      return $rIP_new_IP;
   }
}

