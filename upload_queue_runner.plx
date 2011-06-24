#!/usr/bin/perl -T

BEGIN { push @INC, "."; }

use strict;
use warnings;

#####################################################
#
# upload_queue_runner.plx - Run the queue, and 
# upload to GB shop webserver. 
#
#####################################################

use DBI;

require "./environ.pm";
our $dbh;
our $conf;
my $sth;

$ENV{PATH} = "/bin:/usr/bin";

# Create a lockfile

`touch /var/run/gb_upload$$`;

# Ask the config file how many of me there should be

my $max_uploads = $1 if $conf->{'max_uploads'} =~ /([0-9]+)/;

# Check for lockfiles to see if we're running enough already.

my $current_uploads = $1 if `ls /var/run/gb_upload* | wc -l` =~ /([0-9]+)/;

if ( $current_uploads <= $max_uploads )
{
	# Get the next talk to transcode - highest priority first, oldest first
	$sth = $dbh->prepare("SELECT talk_id FROM upload_queue ORDER BY priority DESC, sequence DESC LIMIT 1;");
	$sth->execute;
	my @queue;
	while (my @data = $sth->fetchrow_array)
	{
		push @queue, $data[0]; 
	}
	my $talk_id = pop @queue;
	
	# Run the upload job

	# Remove the item from the queue
	$sth = $dbh->prepare('DELETE FROM upload_queue where talk_id=?');
	$sth->execute($talk_id);
}
else
{
	die ("Too many upload jobs already running");
}

# Remove lockfile
`rm /var/run/gb_upload$$`;
