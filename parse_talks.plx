#!/usr/bin/perl

use strict;
use warnings;

BEGIN {
        push @INC, '.', '..';
}

use DBI;
use Text::CSV;

use Data::Dumper;

use GB;

my $gb = GB->new("../gb_talks.conf");
my $dbh = $gb->{db};
my $conf = $gb->{conf};

my $gb_short_year = $1 if $conf->{'gb_short_year'} =~ /(^[0-9]{2}$)/;
my $sth;

my $file = 'gb_talks_list.csv';
my $csv = Text::CSV->new({
	sep_char => ',',
	binary => 1
});

open (CSV, "<", $file) or die $!;

foreach (<CSV>) {
	if ($csv->parse($_)) {
		my @columns = $csv->fields();
		my (undef, $talk_id) = split(/-/, $columns[0]);
		my $year = 2013;
		my $speaker = $columns[3];
		my $title = $columns[1];
		print "$talk_id  $speaker  $title\n";
		$sth = $dbh->prepare("INSERT INTO `talks`(`id`,`year`,`speaker`,`title`,`available`,`uploaded`) VALUES (?,?,?,?,0,0)");
		$sth->execute($talk_id, $year, $speaker, $title);
	} else {
		my $err = $csv->error_input;
		print "Failed to parse line: $err";
	}
}
close CSV;
