#!/usr/bin/perl

BEGIN {
        push @INC, '.', '/var/www/html';
}

use strict;
use warnings;

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
my $talk_id = pop @ARGV;

my $mp3_filename = "gb$short_year-$talk_id" . "mp3.mp3";
my $snip_filename = "gb$short_year-$talk_id" . "snip.mp3";

my $sth;

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
	
my $api_url = $conf->{'api_url'} . "GB$short_year-$talk_id";
my $browser = LWP::UserAgent->new;
my $response = $browser->post("$api_url", [action => 'make-available', checksum => $file_md5, snippet_checksum => $snip_md5, sig => $ctx->hexdigest ]);
if ($response->{_rc} == 200) { # If the API call returns 200 (OK) 
	$sth = $dbh->prepare('DELETE FROM upload_queue where talk_id=?');
        $sth->execute($talk_id);
       	warn "Upload of talk $talk_id successful";
} else {	
	my $response_dump = Dumper($response);
       	warn "API call for $mp3_filename failed. Here's the response: \n\n$response_dump";
} 
