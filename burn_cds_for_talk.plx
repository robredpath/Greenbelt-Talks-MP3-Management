#!/usr/bin/perl

use strict;
use warnings;

chdir "/var/www/" or log_it("chdir failed");
use GB;

my $gb = GB->new("gb_talks.conf");
my $conf = $gb->{conf};

my $cd_dir = $conf->{'cd_dir'};
my $short_year = $conf->{'gb_short_year'};

my $talk_id = $ARGV[0];

die "Supply 3 digit talk ID" unless length($talk_id) == 3;

my $talk_cd_dir = $cd_dir . "/gb$short_year-$talk_id";
chdir($talk_cd_dir) or die "This talk is not ready yet!\n";

foreach my $cd (glob("*")) {
	next unless -d $cd;
	print "Insert CDs for next disk, then press Enter when ready:";
        <STDIN>;
	print "$cd";
	chdir($cd);
	print qx#pwd && ls#;
	my $return = qx|wodim dev=/dev/sg3 -dao -pad -audio -eject * & wodim dev=/dev/sg2 -dao -pad -audio -eject * & wodim dev=/dev/sg1 -dao -pad -audio -eject * & wodim dev=/dev/sg0 -dao -pad -audio -eject * &|;
	chdir("..");
}
