#!/usr/bin/perl

BEGIN {
        push @INC, '.', '/var/www/html';
}

use strict;
use warnings;

#####################################################
#
# upload_queue_runner.plx - Run the queue, and 
# upload to GB shop webserver. 
#
#####################################################

chdir "/var/www/html/";

use DBI;
use LWP;
use Digest::MD5;
use Data::Dumper;

use GB;

my $gb = GB->new("../gb_talks.conf");
my $dbh = $gb->{db};
my $conf = $gb->{conf};

my $upload_dir = $conf->{'upload_dir'};

my $short_year = $conf->{'gb_short_year'};
my $upload_host = $conf->{'upload_host'};
my $upload_user = $conf->{'upload_user'};
my $upload_pass = $conf->{'upload_pass'};
my $upload_path = $conf->{'upload_path'};
my $upload_method = $conf->{'upload_method'};

my $sth;

sub log_it {
        my $message = $_[0];
        open LOG, ">>upload_log" or die $!;
        my $date = `date`;
	chomp $date;
        print LOG "[$date] [$$] [$message]\n";
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
	# Get the next talk to upload - highest priority first, oldest first. Let's assume that we're only uploading talks for the current year
	$sth = $dbh->prepare("SELECT talk_id FROM upload_queue ORDER BY priority DESC, sequence ASC LIMIT 1;");
	$sth->execute;
	my @queue;
	while (my @data = $sth->fetchrow_array)
	{
		push @queue, $data[0]; 
	}
	
        my $talk_pos = $current_uploads-1;
        my $talk_id = $queue[$talk_pos];
	
	my $pad_len=3;
	my $padded_talk_id = sprintf("%0${pad_len}d", $talk_id);
	
	log_it("No talk - aborting") unless $talk_id;

	alarm(3600); # Let the script run for an hour. If it takes longer than that, we want to quit, log any results, and let another process start up to resume the transfer. 

	my $mp3_filename;
	my $snip_filename;	
	my $snip_upload_succeeded = 0;
        my $snip_md5;
        my $mp3_upload_succeeded;
        my $mp3_md5;

	
	if($talk_id && $upload_method eq "rsync")
	{	
		$mp3_filename = "gb$short_year-$padded_talk_id" . "mp3.mp3";
		$snip_filename = "gb$short_year-$padded_talk_id" . "snip.mp3";
		$0 = "upload_queue_runner.plx - $mp3_filename";	
		
		log_it("Uploading $snip_filename");	

		# Upload the snip file
		system("rsync --partial $upload_dir/$snip_filename $upload_user\@$upload_host:$upload_path/$snip_filename");

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
		}


		# Upload the actual mp3
		log_it("Uploading $mp3_filename");
		system("rsync --partial $upload_dir/$mp3_filename $upload_user\@$upload_host:$upload_path/$mp3_filename");

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
	} elsif ($talk_id and $upload_method eq "object_storage") {
		
		$mp3_filename = "gb$short_year-$padded_talk_id" . "mp3.mp3";
                $snip_filename = "gb$short_year-$padded_talk_id" . "snip.mp3";
                $0 = "upload_queue_runner.plx - $mp3_filename";

                log_it("Uploading $snip_filename");

		my $ua = LWP::UserAgent->new;
		$ua->agent("GB Talks Team - test server");

		my $req = HTTP::Request->new(GET => 'https://auth.storage.memset.com/v1.0');
		$req->header('X-Auth-Key' => $upload_pass);
		$req->header('X-Auth-User' => $upload_user);

		my $res = $ua->request($req);

		my $auth_key = $res->header('X-Auth-Token');
		my $storage_url = $res->header('X-Storage-Url');

		my $snip_location = "$upload_dir/$snip_filename";	
		$req = HTTP::Request->new(PUT => "$storage_url/$upload_path/$snip_filename");

		$req->header('X-Auth-Token' => $auth_key);
		
		my $snip_data;
		open(SNIP, "<$snip_location");
		foreach(<SNIP>) {
			$snip_data .= $_;
		}
		$req->content($snip_data);
		close(SNIP);
		
		log_it("Starting snip upload for talk_id $talk_id");	
		$res = $ua->request($req);
		my $snip_response = $res->code();
		
		log_it("Snip upload returned $snip_response");
			
		if (int($snip_response/100) == 2) {
			$snip_upload_succeeded = 1;
		}
		
		$req = HTTP::Request->new(PUT => "$storage_url/$upload_path/$mp3_filename");
		$req->header('X-Auth-Token' => $auth_key);
		my $mp3_location = "$upload_dir/$mp3_filename";
		my $mp3_data;
                open(MP3, "<$mp3_location");
                foreach(<MP3>) {
                        $mp3_data .= $_;
                }
                $req->content($mp3_data);
                close(MP3);		
		
		log_it("Starting MP3 upload for talk_id $talk_id");
                $res = $ua->request($req);

		my $mp3_response = $res->code();
		log_it("MP3 upload returned $mp3_response");

                if (int($mp3_response/100) == 2) {
                        $mp3_upload_succeeded = 1;
                }

	}	
	
	if($snip_upload_succeeded && $mp3_upload_succeeded)
	{	
		my $ctx = Digest::MD5->new; 
		open FILE, "<$upload_dir/$mp3_filename";
		binmode(FILE);
		while(<FILE>) {
			$ctx->add($_);
		}
		my $file_md5 = $ctx->hexdigest;
			
                open FILE, "<$upload_dir/$snip_filename";
                binmode(FILE);
                while(<FILE>) {
                        $ctx->add($_);
                }
                my $snip_md5 = $ctx->hexdigest;

		$ctx->add("action=make-available&checksum=$file_md5&snippet_checksum=$snip_md5");
		$ctx->add($conf->{'api_secret'});

		# Try to send the talk live. Log any errors. 

		my $api_url = $conf->{'api_url'} . "GB$short_year-$padded_talk_id";
		my $browser = LWP::UserAgent->new;
		my $response = $browser->post("$api_url", [action => 'make-available', checksum => $file_md5, snippet_checksum => $snip_md5, sig => $ctx->hexdigest ]);		
		if ($response->{_rc} == 200) { # If the API call returns 200 (OK) 
			# Remove the item from the queue
			$sth = $dbh->prepare('DELETE FROM upload_queue where talk_id=?');
			$sth->execute($talk_id);
			log_it("Upload of talk $talk_id successful");
		}
		else {
			my $response_dump = Dumper($response);
			log_it("API call for $mp3_filename failed. Here's the response: \n\n$response_dump");
		}		
	} else {
			log_it("Aborting due to upload failures");
	}
	alarm(0);
}
else
{
	log_it("Aborting - too many upload jobs already running. Maybe the lockfile needs to be cleared?");
	`rm /var/run/gb_upload$$`;
	die ("Too many upload jobs already running");
}

# Remove lockfile
`rm /var/run/gb_upload$$`;
