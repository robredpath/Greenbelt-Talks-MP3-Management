#!/usr/bin/perl -T

BEGIN { push @INC, "."; }

use strict;
use warnings;

#####################################################
#
# transcode_queue_runner.plx - Run the queue, and 
# transcode it from HQ to LQ mp3. 
#
#####################################################

use DBI;

require "./environ.pm";
our $dbh;
our $conf;
my $sth;
my $lame_params = "--abr 96 -q2 --mp3input -S -m j -c";
my $short_year = $1 if $conf->{'gb_short_year'} =~ /([0-9]{2})/;

$ENV{PATH} = "/bin:/usr/bin";

# Create a lockfile

`touch /var/run/gb_transcode$$`;

# Ask the config file how many of me there should be

my $max_transcodes = $1 if $conf->{'max_transcodes'} =~ /([0-9]+)/;

# Check for lockfiles to see if we're running enough already.

my $current_transcodes = $1 if `ls /var/run/gb_transcode* | wc -l` =~ /([0-9]+)/;

if (! -e './transcode_queue')
{
	mkdir('./transcode_queue');
}

if ( $current_transcodes <= $max_transcodes )
{
	# Get the next talk to transcode - highest priority first, oldest first
	$sth = $dbh->prepare("SELECT talk_id FROM transcode_queue ORDER BY priority DESC, sequence DESC LIMIT 1");
	$sth->execute;
	my @queue;
	while (my @data = $sth->fetchrow_array)
	{
		push @queue, $data[0]; 
	}
	my $talk_id = pop @queue;
	
	if ($talk_id)
	{	
		$0 = "transcode_queue_runner.plx - gb$short_year-$talk_id.mp3";	
	
		# Get the metadata
		$sth = $dbh->prepare("SELECT speaker, title FROM talks WHERE id=?");
		$sth->execute($talk_id);
		my @talk_data;
		while (my @data = $sth->fetchrow_array)
        	{
                	push @talk_data, $data[0];
			push @talk_data, $data[1];
        	}
        	my $talk_speaker = pop @talk_data;
		my $talk_title = pop @talk_data;
	
		# Set up metadata to pass to LAME
		my $lame_data = " --id3v2-only --tt '$talk_title' --ta '$talk_speaker' --tl 'Greenbelt Festival Talks 20$short_year' --ty 20$short_year --tn $talk_id";

		# Run the transcode job
		system("lame $lame_params $lame_data ./transcode_queue/gb$short_year-$talk_id.mp3 ./upload_queue/gb$short_year-$talk_id.mp3");	

		# Remove the item from the queue
		$sth = $dbh->prepare('DELETE FROM transcode_queue where talk_id=?');
		$sth->execute($talk_id);
	} else {
		warn ("Nothing in queue");
	}
}
else
{
	die ("Too many transcode jobs already running");
}

# Remove lockfile
`rm /var/run/gb_transcode$$`;
