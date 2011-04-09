#!/usr/bin/perl
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
use environ;

my $status_message = "Select a file to upload below";

# If there is POST data
my $post_data = new CGI;
my $uploaded_talk = { };
my $talk_is_complete;

if($post_data->param('talk_id')
{

}

# Sanitise (erm....how do you sanitise an MP3?)

# Open file for writing with appropriate name

open TALK, ">gb11-$talk_id.mp3";

# Write file

print TALK $uploaded_talk->{'talk_data'};

# Close file

close TALK;

# md5sum the file

my $md5sum = `md5sum gb11-$talk_id.mp3`;

# Write data to database - md5sum and acknowledge upload
# email contact to confirm availability (get contact from conf file)



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
<form action="POST" target="upload_talk.plx">
<input type="file" id="talk_data" />
<input type="submit" />
</form>
</div>

END




#Set up footer

my $output_html .= <<END;

</body>
</html>
END
