#!/usr/local/bin/perl

use strict;
use warnings;

open (FQDN, "/bin/hostname|");
my @fqdn = <FQDN>;
close (FQDN);

my @split_fqdn = split /\./, $fqdn[0], 2;
my $subdomain = $split_fqdn[1];
chomp($subdomain);

open (CFENGINE_INITIAL, "/root/cfengine/cfengine.conf.initial");
my @cfengine_initial = <CFENGINE_INITIAL>;

open (CFENGINE_INITIAL_FIXED, ">/root/cfengine/cfengine.conf.initial");
foreach (@cfengine_initial) {
	s/\( \? \)/\( $subdomain \)/;
	print CFENGINE_INITIAL_FIXED $_;
}
close (CFENGINE_INITIAL);
close (CFENGINE_INITIAL_FIXED);
