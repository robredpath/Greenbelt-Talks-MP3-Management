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

$SIG{ALRM} = sub {

die "Process took too long to complete - maybe rsync died?\n";

};


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
	
	alarm(3600); # Let the script run for an hour. If it takes longer than that, we want to quit, log any results, and let another process start up to resume the transfer. 
	
	# Run the upload job
	system("rsync --partial gb_talks_upload/gb11-$talk_id.mp3 $rsync_user\@$rsync_host:$rsync_path/gb11-$talk_id.mp3");

	# Check what return code rsync gave to determine how it did at the upload
	
	if ($? == -1) {
		print "failed to run rsync: $!\n";
	}	
	elsif ($? & 127) {
		printf "child died with signal %d, %s coredump\n", ($? & 127), ($? & 128) ? "with" : "without";
	}
	else { # If we succeeded
	
		printf "child exited with value %d\n", $? >> 8;
		# Remove the item from the queue
		$sth = $dbh->prepare('DELETE FROM upload_queue where talk_id=?');
		$sth->execute($talk_id);
	}
	
	alarm(0);
}
else
{
	die ("Too many upload jobs already running");
}

# Remove lockfile
`rm /var/run/gb_upload$$`;

