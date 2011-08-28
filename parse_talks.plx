#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use Text::CSV;

require "./environ.pm";
our $dbh;
our $conf;
my $gb_short_year = $1 if $conf->{'gb_short_year'} =~ /(^[0-9]{2}$)/;
my $sth;

my $file = 'gb_talks_list_2.csv';
my $csv = Text::CSV->new();

open (CSV, "<", $file) or die $!;

while (<CSV>) {
	if ($csv->parse($_)) {
		my @columns = $csv->fields();
		my (undef, $talk_id) = split(/-/, $columns[0]);
		my $year = 2011;
		my $speaker = $columns[3];
		my $title = $columns[1];
		$sth = $dbh->prepare("INSERT INTO `talks`(`id`,`year`,`speaker`,`title`,`available`,`uploaded`,`additional_talks`) VALUES (?,?,?,?,0,0,NULL)");
		$sth->execute($talk_id, $year, $speaker, $title);
	} else {
		my $err = $csv->error_input;
		print "Failed to parse line: $err";
	}
}
close CSV;
