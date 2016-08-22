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

my $talk_cd_dir = $cd_dir . "/gb$short_year-$talk_id";
chdir($talk_cd_dir);

qx|wodim dev=/dev/sg3 -pad -audio * &
	wodim dev=/dev/sg2 -pad -audio * & 
	wodim dev=/dev/sg1 -pad -audio * &
	wodim dev=/dev/sg0 -pad -audio * &|;
