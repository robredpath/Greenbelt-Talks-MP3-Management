#!/usr/bin/perl -T

BEGIN { push @INC, "."; }

use strict;
use warnings;

#************************************************************************
# upload_talk.plx
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

# Set up the environment
$CGI::POST_MAX = 1024 * 512000; # 512MB should be enough for what we're doing!
my $upload_dir = "./gb_talks_upload";
require "./environ.pm";
our $dbh;
our $gb_short_year = $1 if $gb_short_year =~ /([0-9]{2})/;
my $sth;
my $rv;

my $status_message = "Select a file to upload below";

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

if ($post_data->param('talk_id') && $post_data->upload('talk_data'))
{
	$talk_id = $1 if $post_data->param('talk_id')  =~ /([0-9]+)/;
	my $talk_data = $post_data->upload('talk_data');

	# Open file for writing with appropriate name
	warn "$upload_dir/gb$gb_short_year-$talk_id.mp3";
	open TALK, ">$upload_dir/gb$gb_short_year-$talk_id.mp3" or warn $!;

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
	$sth = $dbh->prepare("INSERT INTO transcode_queue(`sequence`,`priority`,`talk_id`) VALUES (NULL,5,?)");
	$rv = $sth->execute($talk_id);
	# Mark as uploaded
	$sth = $dbh->prepare("UPDATE `talks` SET `uploaded`=1 where `id`=?");
	$rv = $sth->execute($talk_id);

	# email contact to confirm availability (get contact from conf file)
}

#Set up header
my $output_html = <<END;

<html>
<body>
<div id="header">
<div id="logo"><img src="gb_logo.png" /></div>
Greenbelt Talks - Upload New Talk
</div>
<div id="status_message">$status_message </div>
<div id="upload_form">
<form action="upload_talk.plx" method="POST" enctype="multipart/form-data">
mp3:<input type="file" id="talk_data" name="talk_data"/>
Talk ID: <select name="talk_id" id="talk_id">
END

$sth  = $dbh->prepare("SELECT id FROM talks WHERE uploaded = 0");
$sth->execute;
foreach ($sth->fetchrow_array)
{
	$output_html .= "<option value='$_'>gb$gb_short_year-$_</option>"
}


$output_html .= <<END; 
</select>
<input type="submit" value="Upload Talk" name="submit"/>
</form>
</div>

END


#Set up footer

$output_html .= <<END;

</body>
</html>
END

print $post_data->header, $output_html;
