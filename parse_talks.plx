#!/usr/bin/perl

use strict;
use warnings;

BEGIN {
        push @INC, '.', '..';
}

use DBI;
use Text::CSV;
use Data::Dumper;
use DateTime;
use Time::ParseDate;

use GB;

my $gb = GB->new("gb_talks.conf");
my $dbh = $gb->{db};
my $conf = $gb->{conf};

my $gb_short_year = $1 if $conf->{'gb_short_year'} =~ /(^[0-9]{2}$)/;
my $gb_long_year = $1 if $conf->{'gb_long_year'} =~ /(^[0-9]{4}$)/;
my $friday_of_gb_date = $1 if $conf->{'friday_of_gb_date'} =~ /(^[0-9]{2}$)/;
my $start_of_gb = parsedate($friday_of_gb_date);

my $file = $ARGV[0];
my $csv = Text::CSV->new({
	sep_char => ',',
	binary => 1
});

open (CSV, "<", $file) or die $!;
my $sth;
foreach (<CSV>) {
	if ($csv->parse($_)) {
		# Number,Venue Name,Date,Start time,Name,Lineup,Record,Public Description,Show Types,,
		my @columns = $csv->fields();
		my (undef, $talk_id) = split(/-/, $columns[0]);
		my $year = $gb_long_year;
		my $speaker = $columns[5];
		my $title = $columns[4];
		my $day = $columns[2];
		my $time = $columns[3];

		# Convert the day + time columns to a DateTime
		my $datetime_of_talk = parsedate("next $day $time", NOW => $start_of_gb);
		print "Talk ID: $talk_id Speaker: $speaker Title: $title Day: $day Time: $time Timestamp: $datetime_of_talk\n";

		$sth = $dbh->prepare("INSERT INTO `talks`(`id`,`year`,`speaker`,`title`,`available`,`uploaded`) VALUES (?,?,?,?,0,0)");
		$sth->execute($talk_id, $year, $speaker, $title);
	} else {
		my $err = $csv->error_input;
		print "Failed to parse line: $err";
	}
}
close CSV;

