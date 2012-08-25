#!/usr/bin/perl

BEGIN {
        push @INC, '.', '/var/www/html';
}

use strict;
use warnings;

#####################################################
#
# transcode_queue_runner.plx - Run the queue, and 
# transcode it from HQ to LQ mp3. 
#
#####################################################

use DBI;
chdir "/var/www/html/" or log_it("chdir failed");

use GB;

my $gb = GB->new("../gb_talks.conf");
my $dbh = $gb->{db};
my $conf = $gb->{conf};

my $upload_dir = $conf->{'upload_dir'};
my $transcode_dir = $conf->{'transcode_dir'};

my $sth;
my $lame_params = "--abr 96 -q2 --mp3input -S -m j -c";
my $short_year = $conf->{'gb_short_year'};
my $gb_long_year = "20$short_year";

$ENV{PATH} = "/bin:/usr/bin";

sub log_it {
        my $message = $_[0];
        open LOG, ">>transcode_log" or die $!;
        my $date = `date`;
        chomp $date;
        print LOG "[$date] [$$] [$message]\n";
        close LOG;
}

# Create a lockfile

`touch /var/run/gb_transcode$$`;

# Ask the config file how many of me there should be

my $max_transcodes = $1 if $conf->{'max_transcodes'} =~ /([0-9]+)/;

# Check for lockfiles to see if we're running enough already.

my $current_transcodes = $1 if `ls /var/run/gb_transcode* | wc -l` =~ /([0-9]+)/;

if (! -e $transcode_dir)
{
	mkdir($transcode_dir) or die "Could not create transcode dir";
}

if ( $current_transcodes <= $max_transcodes )
{
	# Get the next talk to transcode - highest priority first, oldest first. We can assume that we're only transcoding talks from this year.
	$sth = $dbh->prepare("SELECT talk_id FROM transcode_queue ORDER BY priority DESC, sequence DESC LIMIT ?");
	$sth->execute($current_transcodes);
	my @queue;
	while (my @data = $sth->fetchrow_array)
	{
		push @queue, $data[0]; 
	}
	my $talk_pos = $current_transcodes-1;
	my $talk_id = $queue[$talk_pos];
	
	my $pad_len=3;
        my $padded_talk_id = sprintf("%0${pad_len}d", $talk_id);
	
	if ($talk_id)
	{	
		$0 = "transcode_queue_runner.plx - gb$short_year-$padded_talk_id" . "mp3.mp3";	
	
		# Get the metadata
		$sth = $dbh->prepare("SELECT speaker, title FROM talks WHERE id=?");
		$sth->execute($talk_id);
		my @talk_data;
		while (my @data = $sth->fetchrow_array)
        	{
                	push @talk_data, $data[0];
			push @talk_data, $data[1];
        	}
		
		my $talk_title = pop @talk_data;
		my $talk_speaker = pop @talk_data;

	
		# Set up metadata to pass to LAME
		my $lame_data = " --id3v2-only --tt \"$talk_title\" --ta \"$talk_speaker\" --tl \"Greenbelt Festival Talks 20$short_year\" --ty 20$short_year --tn $talk_id";

		# Run the transcode job
		my $lame_command = "lame $lame_params $lame_data $transcode_dir/gb$short_year-$padded_talk_id" .  "mp3.mp3 $upload_dir/gb$short_year-$padded_talk_id" . "mp3.mp3";	
		my $return = system($lame_command);

		log_it("Transcode result: $? \nReturned data: $return");
	
		# TODO: Add return code checking

		# Remove the item from the queue
		$sth = $dbh->prepare('DELETE FROM transcode_queue where talk_id=?');
		$sth->execute($talk_id);
		$sth = $dbh->prepare('INSERT INTO upload_queue(priority, talk_id, talk_year) VALUES (?,?,?)');
		$sth->execute(2,$talk_id,$gb_long_year);
		$sth = $dbh->prepare('UPDATE talks SET available=1 WHERE id=? AND year=?');
		$sth->execute($talk_id, $gb_long_year);
	} else {
		log_it("Nothing in queue - terminating");
	}
}
else
{
	log_it("Too many transcode jobs already running");
	`rm /var/run/gb_transcode$$`;
	die;
}

# Remove lockfile
`rm /var/run/gb_transcode$$`;
