#!/usr/bin/perl

BEGIN {
        push @INC, '.' , '..';
}

use strict;
use warnings;

#************************************************************************
# upload_talk.cgi
#
# A script to handle HQ mp3 uploads of talks 
#
# Inputs:
# 
# POST submission of an MP3 file and a talk ID
#
# Outputs:
#
# HQ mp3 file saved to disk
# HTML page acknowledging upload
# Database updates
#************************************************************************

use CGI;
use CGI::Carp qw ( fatalsToBrowser ); 
use DBI;
use Template;
use GB;

my $gb = GB->new("../gb_talks.conf");
my $dbh = $gb->{db};
my $conf = $gb->{conf};

# Set up the environment
$CGI::POST_MAX = 1024 * 512000; # 512MB should be enough for what we're doing!
my $upload_dir = $conf->{'upload_dir'};
my $transcode_dir = $conf->{'transcode_dir'};
my $gb_short_year = $conf->{'gb_short_year'};
my $gb_long_year = "20$gb_short_year";
my $sth;
my $rv;

my $status_messages = [];
my $error_messages = [];

# If there is POST data
my $post_data = new CGI;
my $uploaded_talk = { };
my $talk_is_complete;
my $talk_id;

if (! -e $upload_dir)
{
	warn ("Uploads directory does not exist - attempting to create");
	mkdir $upload_dir or warn $!;
}

if ($post_data->param('talk_id') && $post_data->upload('talk_data') && $post_data->upload('snip_data'))
{
	$talk_id = $1 if $post_data->param('talk_id')  =~ /([0-9]+)/;
	my $talk_data = $post_data->upload('talk_data');
	my $snip_data = $post_data->upload('snip_data');

	my $pad_len=3;
        my $padded_talk_id = sprintf("%0${pad_len}d", $talk_id);

	# Open snip file for writing
	
	my $snip_filename = "gb$gb_short_year-$padded_talk_id" . "snip.mp3";
        warn "$upload_dir/$snip_filename";
        open TALK, ">$upload_dir/$snip_filename" or warn $!;

        # Write file
        binmode TALK;
        while ( <$snip_data> )
        {
        	print TALK;
        }
        
        # Close file
        close TALK;
        
	# Open file for writing with appropriate name
	my $mp3_filename = "gb$gb_short_year-$padded_talk_id" . "mp3.mp3";
	warn "$transcode_dir/$mp3_filename";
	open TALK, ">$transcode_dir/$mp3_filename" or warn $!;

	# Write file
	binmode TALK;
	while ( <$talk_data> ) 
	{	 
		print TALK; 
	}

	# Close file
	close TALK;

	# Add to transcode queue
	warn($talk_id);
	$sth = $dbh->prepare("INSERT INTO transcode_queue(`sequence`,`priority`,`talk_id`, `talk_year`) VALUES (NULL,2,?,?)");
	$rv = $sth->execute($talk_id, $gb_long_year);
	# Mark as uploaded
	$sth = $dbh->prepare("UPDATE `talks` SET `uploaded`=1 where `id`=? AND `year`=?");
	$rv = $sth->execute($talk_id, $gb_long_year);

	push $status_messages, "Talk $talk_id uploaded";
} elsif ($post_data->param('talk_id')) {
	push $error_messages, "Both mp3 and snip file are required";
}


my $non_uploaded_talks = $dbh->selectcol_arrayref("SELECT `id` FROM talks WHERE uploaded = 0");

print $post_data->header;
my $output_vars = {
        error_messages => $error_messages,
	status_messages => $status_messages,
        gb_short_year => $gb_short_year,
        talks => $non_uploaded_talks,
};

my $tt = Template->new({
        INCLUDE_PATH => '/var/www/templates'
});


$tt->process('upload_talk.tmpl', $output_vars) || die $tt->error();
