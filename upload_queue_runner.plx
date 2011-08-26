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
use Sys::Syslog qw/ :DEFAULT setlogsock /;
use LWP;
use Digest::MD5;
use Data::Dumper;

require "./environ.pm";
our $dbh;
our $conf;

my $short_year = $1 if $conf->{'gb_short_year'} =~ /([0-9]{2})/;
my $rsync_host = $1 if $conf->{'rsync_host'} =~ /([a-zA-Z0-9\.]+)/;
my $rsync_user = $1 if $conf->{'rsync_user'} =~ /([a-zA-Z0-9\.]+)/;
my $rsync_path = $1 if $conf->{'rsync_path'} =~ /([a-zA-Z0-9\.\/~]+)/;
my $sth;

sub log_it {
        my $message = @_[0];
        open LOG, ">>upload_log" or die $!;
        my $date = chomp(`date`);
        print LOG "[$date] [$$] [$message]";
        close LOG;
}


$ENV{PATH} = "/bin:/usr/bin";
$SIG{ALRM} = sub {

	log_it("Upload process killed by alarm - maybe rsync died?");
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
	# Get the next talk to upload - highest priority first, oldest first
	$sth = $dbh->prepare("SELECT talk_id FROM upload_queue ORDER BY priority DESC, sequence DESC LIMIT 1;");
	$sth->execute;
	my @queue;
	while (my @data = $sth->fetchrow_array)
	{
		push @queue, $data[0]; 
	}
	my $talk_id = pop @queue;
	
	log_it("No talk - aborting") unless $talk_id;

	alarm(3600); # Let the script run for an hour. If it takes longer than that, we want to quit, log any results, and let another process start up to resume the transfer. 
	if($talk_id)
	{	
		my $mp3_filename = "gb$short_year-$talk_id" . "mp3.mp3";
		my $snip_filename = "gb$short_year-$talk_id" . "snip.mp3";
		$0 = "upload_queue_runner.plx - $mp3_filename";	
		
		log_it("Uploading $snip_filename");	

		# Upload the snip file
		system("rsync --partial upload_queue/$snip_filename $rsync_user\@$rsync_host:$rsync_path/$snip_filename");

		my $snip_upload_succeeded = 0;
		my $snip_md5;

		# Check what return code rsync gave to determine how it did at the upload

		if ($? == -1) {
                        log_it("Failed to run rsync for snippet $snip_filename: $!\n");
                }
                elsif ($? & 127) {
                        log_it(sprintf "rsync for snippet $snip_filename: child died with signal %d, %s coredump\n", ($? & 127), ($? & 128) ? "with" : "without");
                }
                else { 
			$snip_upload_succeeded = 1;
			my $log_message = sprintf "rsync for snippet $snip_filename: child exited with value %d\n", $? >> 8;
                        log_it($log_message);
                        my $ctx = Digest::MD5->new;
                        open FILE, "<upload_queue/$snip_filename";
                        binmode(FILE);
                        while(<FILE>) {
                                $ctx->add($_);
                        }
                        $snip_md5 = $ctx->hexdigest;
		}


		# Upload the actual mp3
		log_it("Uploading $mp3_filename");
		system("rsync --partial upload_queue/$mp3_filename $rsync_user\@$rsync_host:$rsync_path/$mp3_filename");

		my $mp3_upload_succeeded;
		my $mp3_md5;


		# Check what return code rsync gave to determine how it did at the upload
		if ($? == -1) {
			log_it("Failed to run rsync for file $mp3_filename: $!");
		}	
		elsif ($? & 127) {
			log_it(sprintf "rsync for $mp3_filename: child died with signal %d, %s coredump", ($? & 127), ($? & 128) ? "with" : "without");
		}
		else { # If we succeeded
			my $log_message = sprintf "rsync for $mp3_filename: child exited with value %d", $? >> 8;
			log_it($log_message);
			$mp3_upload_succeeded = 1;
		}
		
		if($snip_upload_succeeded && $mp3_upload_succeeded)
		{	
			my $ctx = Digest::MD5->new; 
			open FILE, "<upload_queue/$mp3_filename";
			binmode(FILE);
			while(<FILE>) {
				$ctx->add($_);
			}
			my $file_md5 = $ctx->hexdigest;
			
			$ctx->add("action=make-available&checksum=$file_md5&snippet_checksum=$snip_md5");
			$ctx->add($conf->{'api_secret'});

			# Try to send the talk live. Log any errors. 

			my $api_url = $conf->{'api_url'} . "GB$short_year-$talk_id";
			my $browser = LWP::UserAgent->new;
			my $response = $browser->post("$api_url", [action => 'make-available', checksum => $file_md5, snippet_checksum => $snip_md5, sig => $ctx->hexdigest ]);		
			if ($response->{_rc} == 200) { # If the API call returns 200 (OK) 
				# Remove the item from the queue
				$sth = $dbh->prepare('DELETE FROM upload_queue where talk_id=?');
				$sth->execute($talk_id);
			}
			else {
				my $response_dump = Dumper($response);
				log_it("API call for $mp3_filename failed. Here's the response: \n\n$response_dump");
			}	
			
			
		}
	
		alarm(0);
	}
}
else
{
	log_it("Aborting - too many upload jobs already running. Maybe the lockfile needs to be cleared?");
	die ("Too many upload jobs already running");
}

# Remove lockfile
`rm /var/run/gb_upload$$`;
