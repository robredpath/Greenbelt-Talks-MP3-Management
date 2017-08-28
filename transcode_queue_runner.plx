#!/usr/bin/perl

BEGIN {
        push @INC, '.', '/var/www/';
}

use strict;
use warnings;
use POSIX;

#####################################################
#
# transcode_queue_runner.plx - Run the queue, and 
# transcode it from HQ to LQ mp3. 
#
#####################################################

use DBI;
chdir "/var/www/" or log_it("chdir failed");

use GB;

my $gb = GB->new("gb_talks.conf");
my $dbh = $gb->{db};
my $conf = $gb->{conf};

my $upload_dir = $conf->{'upload_dir'};
my $transcode_dir = $conf->{'transcode_dir'};
my $cd_dir = $conf->{'cd_dir'};

my $sth;
my @lame_params = ("--abr",  192, "-q2", "--mp3input", "-S", "-m", "j", "-c");
my $short_year = $conf->{'gb_short_year'};
my $gb_long_year = "20$short_year";

$ENV{PATH} = "/bin:/usr/bin:/usr/local/bin";

sub log_it {
        my $message = $_[0];
        open LOG, ">>transcode_log" or die $!;
        my $date = `date`;
        chomp $date;
        print LOG "[$date] [$$] [$message]\n";
        close LOG;
}

sub log_it_and_check {
	log_it("$_[0] return code: $_[1]");
	if($_[1] != 0) {
	        `rm /var/run/gb_transcode$$`;
		exit $_[1];
	} 
}

# Create a lockfile

`touch /var/run/gb_transcode$$`;

# Ask the config file how many of me there should be

my $max_transcodes = $1 if $conf->{'max_transcodes'} =~ /([0-9]+)/;

# Check for lockfiles to see if we're running enough already.

my $current_transcodes = $1 if `ls /var/run/gb_transcode* | wc -l` =~ /([0-9]+)/;

if (! -e $transcode_dir)
{
	mkdir($transcode_dir) or log_it_and_check("Could not create transcode dir",1);
}

if ( $current_transcodes <= $max_transcodes )
{
	# Get the next talk to transcode - highest priority first, oldest first. We can assume that we're only transcoding talks from this year.
	$sth = $dbh->prepare("SELECT talk_id FROM transcode_queue ORDER BY priority DESC, sequence ASC LIMIT ?");
	$sth->execute($current_transcodes);
	my @queue;
	while (my @data = $sth->fetchrow_array)
	{
		push @queue, $data[0]; 
	}
	if(scalar @queue  == $current_transcodes) {
		my $talk_pos = $current_transcodes-1;
		my $talk_id = $queue[$talk_pos];
		warn $talk_pos;
	
		my $pad_len=3;
	        my $padded_talk_id = sprintf("%0${pad_len}d", $talk_id);
	
		if ($talk_id)
		{	
			my $mp3_filename = "gb$short_year-$padded_talk_id" . "mp3.mp3";
			$0 = "transcode_queue_runner.plx - $mp3_filename";	
	
			# Get the metadata
			$sth = $dbh->prepare("SELECT speaker, title, description FROM talks WHERE id=?");
			$sth->execute($talk_id);
			my @talk_data;
			while (my @data = $sth->fetchrow_array)
	        	{
        	        	push @talk_data, $data[0];
				push @talk_data, $data[1];
				push @talk_data, $data[2];
	        	}
		
			my $talk_description = pop @talk_data;
			my $talk_title = pop @talk_data;
			my $talk_speaker = pop @talk_data;

			# Run the transcode job
			my $transcode_filename = "$transcode_dir/$mp3_filename" ;
			my $upload_filename = "$upload_dir/$mp3_filename";

			log_it("Transcode started for $mp3_filename");
			my $return = system("lame", @lame_params, $transcode_filename, $upload_filename);
			log_it("Transcode return code: $return");
			exit if $return != 0; 

			log_it("Adding metadata for $mp3_filename");
			my @id3v2_tags = ("--TALB", "Greenbelt Festival Talks 2017", 
					  "--TCOP", "$gb_long_year Greenbelt Festivals", 
					  "--TIT2", "$talk_title", 
					  "--TPE1", "$talk_speaker", 
                                          "--TPE2", "$talk_speaker", 
					  "--TRCK", "$talk_id", 
					  "--TDRC", "$gb_long_year", 
					  "--COMM", "$talk_description",
					  "--TCMP", "1", 
					  "--picture", "/var/www/gtalks_logo.png");
			
			log_it("mid3v2 command: @id3v2_tags");
			$return = system("mid3v2", @id3v2_tags, $upload_filename);
			log_it("Metadata return code: $return");
                        exit if $return != 0;

			# Now, set up the files for the CD burn
		
			# Use FFMPEG to extract those tracks as separate files and save out to cd dir
			my $full_talk_wav_filename = "$cd_dir/gb$short_year-$padded_talk_id.wav";
			$return = system("lame", "--decode", $transcode_filename, $full_talk_wav_filename);
	                log_it("MP3 decode return code: $return");

			my $talk_cd_dir = "$cd_dir/gb$short_year-$padded_talk_id";
			if (! -e $talk_cd_dir)
			{
        			mkdir($talk_cd_dir) or die "Could not create CD per-talk dir";
			}

			# If the track is longer than 79 mins, split it but warn the user
			
			my $talk_length = int(qx#/usr/bin/soxi -D $full_talk_wav_filename#);
			my $number_of_discs = ceil($talk_length/(79*60));
                        my $cd_length = $talk_length/$number_of_discs;

			# Split up the full WAV, if necessary, into multiple files
			$return = system("ffmpeg", "-i", $full_talk_wav_filename, "-f", "segment", "-segment_time", $cd_length, "-segment_start_number", "1", "-c", "copy", "$talk_cd_dir/gb$short_year-$padded_talk_id-fullcd%01d.wav");

			warn "Talk is $talk_length minutes long, preparing for $number_of_discs CDs";

			foreach my $disc (1..$number_of_discs) {
				mkdir("$talk_cd_dir/cd$disc");
				$return = system("ffmpeg", "-i", "$talk_cd_dir/gb$short_year-$padded_talk_id-fullcd$disc.wav" , "-f", "segment", "-segment_time", 300, "-c", "copy", "$talk_cd_dir/cd$disc/gb$short_year-$padded_talk_id-%02d-cd$disc.wav");
                        	log_it_and_check("CD split", $return);
				# gb16-057-fullcd2.wav
				log_it("$talk_cd_dir/gb$short_year-$padded_talk_id-fullcd$disc.wav");
				qx#/usr/bin/rm -f $talk_cd_dir/gb$short_year-$padded_talk_id-fullcd$disc.wav#;
			}

			# clean up a bit	
			qx#/usr/bin/rm $full_talk_wav_filename#;

			# Remove the item from the queue
			$sth = $dbh->prepare('DELETE FROM transcode_queue where talk_id=?');
			$sth->execute($talk_id);
			#$sth = $dbh->prepare('INSERT INTO upload_queue(priority, talk_id, talk_year) VALUES (?,?,?)');
			#$sth->execute(2,$talk_id,$gb_long_year);
			$sth = $dbh->prepare('UPDATE talks SET available=1 WHERE id=? AND year=?');
			$sth->execute($talk_id, $gb_long_year);
		} else {
			log_it("Nothing in queue - terminating");
		}
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
