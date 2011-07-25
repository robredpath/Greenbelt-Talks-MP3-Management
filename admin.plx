#!/usr/bin/perl -T

############################################################
#
# admin.plx
#
# Miscellaneous administration tools for the GB Talks 
# system.
#
# Functions:-
# - Show upload queue and transcode queue
# - Manipulate the queues - pause items, remove items, 
#   change priority of items
# - Suspend or remove talks from sale on the website
# - Show alerts for potential failure conditions
#
############################################################


use DBI;
use CGI;

require "./environ.pm";
our $dbh;
our $conf;
my $sth;



# Grab current upload queue
my @upload_queue;

$sth = $dbh->prepare("SELECT talk_id, priority, sequence FROM upload_queue ORDER BY priority DESC, sequence ASC");
while ($sth->fetchrow_hashref)
{
	push @upload_queue, $_;
}

# Grab current transcode queue
my @transcode_queue;

$sth = $dbh->prepare("SELECT talk_id, priority, sequence FROM transcode_queue ORDER BY priority DESC, sequence ASC");
while ($sth->fetchrow_hashref)
{
        push @transcode_queue, $_;
}


# Grab current list of talks online

# Produce output

# Set up the HTML header

my $output_html = <<END;

<html>
<head>
<link rel="stylesheet" type="text/css" href="gb_talks.css" />
</head>
<body>
<div id="page">
<div id="logo">
<img src="gb_logo.png" />
</div>
<div id="title">
<h2>Greenbelt Talks Team - Administration Tasks</h2>
</div>
END

# Was there any POST data? If so, output confirmation that the request has been processed

if($post_data->param('action'))
{

my $output_html .= <<END;
<div id="confirmation">
<h3>Results</h3>
END

if(@error_messages)
{
	$output_html .= "An error was encountered whilst processing the request:";
	foreach(@error_messages)
	{
		$output_html .= "<p>" . $_ . "</p>";
        }
} else {
	$output_html .= "Your request has been successfully processed";
}
$output_html .= <<END;
</div>
END

# Form for transcode queue

my $output_html .= <<END;
<div id="transcode_queue" class="input">
END

foreach (@transcode_queue)
{
	
}

my $output_html .= <<END;
</div>
END
