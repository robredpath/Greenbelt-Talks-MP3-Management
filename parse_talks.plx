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
my $thursday_of_gb_date = $friday_of_gb_date-1;
my $start_of_gb = parsedate("$thursday_of_gb_date August $gb_long_year");
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
		my $speaker = $columns[4];
		my $title = $columns[3];
		my $day = $columns[1];
		my $time = $columns[2];
		my $description = $columns[5];

		# Convert the day + time columns to a DateTime
		my ($sec, $min, $hour, $mday, $mon, undef, undef, undef, undef) = localtime(parsedate("next $day $time", NOW => $start_of_gb));
		$mon++; # Month starts at 0
		my $start_time = "$year-$mon-$mday ${hour}:${min}";
		print "Talk ID: $talk_id Speaker: $speaker Title: $title Day: $day Time: $time Timestamp: $start_time\n";
		$sth = $dbh->prepare("INSERT INTO `talks`(`id`,`year`,`speaker`,`title`,`description`, `available`,`uploaded`, `start_time`) VALUES (?,?,?,?,?,0,0,?)");
		$sth->execute($talk_id, $year, $speaker, $title, $description, $start_time);
		#
		$sth = $dbh->prepare("UPDATE `talks` SET start_time=? WHERE id=?");
		$sth->execute($start_time, $talk_id);
	} else {
		my $err = $csv->error_input;
		print "Failed to parse line: $err";
	}
}
close CSV;

