#!/usr/bin/perl -T
use strict;
use warnings;

#************************************************************************
# upload_talk.plx
#
# A script to handle HQ mp3 uploads of talks 
#
# Inputs:
# 
# HQ mp3 file
# Talk ID to name
#
# Outputs:
#
# HQ mp3 file saved to disk
# md5sum, entry in transcode queue runner in db
# HTML page acknowledging upload
#************************************************************************

use CGI;
use CGI::Carp qw ( fatalsToBrowser ); 
use File::Basename;

$CGI::POST_MAX = 1024 * 512000; # 500MB should be enough for what we're doing!
my $upload_dir = "./gb_talks_upload";

#use environ;

my $status_message = "Select a file to upload below";

# If there is POST data
my $post_data = new CGI;
my $uploaded_talk = { };
my $talk_is_complete;

if ($post_data->param('talk_id') && $post_data->upload('talk_data'))
{
my $talk_id = $post_data->param('talk_id') unless $post_data->param('talk_id') =~ /[0-9]*/;
my $talk_data = $post_data->upload('talk_data');

# Open file for writing with appropriate name

open TALK, ">gb11-$talk_id.mp3";

# Write file

binmode TALK;
while ( <$talk_data> ) 
{ 
	print TALK; 
}

# Close file

close TALK;

# md5sum the file

#my $md5sum = `md5sum gb11-$talk_id.mp3`;

# Write data to database - md5sum and acknowledge upload
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
mp3: :<input type="file" id="talk_data" />
Talk ID:<input type="text" id="talk_id" />
<input type="submit" />
</form>
</div>

END




#Set up footer

$output_html .= <<END;

</body>
</html>
END

print $post_data->header, $output_html;
