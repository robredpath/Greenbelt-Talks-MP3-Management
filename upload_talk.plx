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
use DBI;
use Cwd qw/abs_path/;
use Digest::MD5::File;

$CGI::POST_MAX = 1024 * 512000; # 512MB should be enough for what we're doing!
#my $cwd = cwd();
my $upload_dir = "./gb_talks_upload";


require "./environ.pm";
our $dbh;

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
	warn "$upload_dir/gb11-$talk_id.mp3";
	open TALK, ">$upload_dir/gb11-$talk_id.mp3" or warn $!;

	# Write file

	binmode TALK;
	while ( <$talk_data> ) 
	{	 
		print TALK; 
	}

	# Close file

	close TALK;

	# md5sum the file

	my $md5sum = file_md5("$upload_dir/gb11-$talk_id.mp3");

	# Write add to transcode queue - md5sum and acknowledge upload
	warn($talk_id);
	my $sth = $dbh->prepare("INSERT INTO transcode_queue(`sequence`,`priority`,`talk_id`) VALUES (NULL,5,?)");
	my $rv = $sth->execute($talk_id);

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
mp3: :<input type="file" id="talk_data" name="talk_data"/>
Talk ID:<input type="text" id="talk_id" name="talk_id"/>
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
