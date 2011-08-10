#!/usr/bin/perl -T

use strict;
use warnings;

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
use CGI::Carp qw ( fatalsToBrowser );
use Data::Dumper;

require "./environ.pm";
our $dbh;
our $conf;
my $sth;

my @error_messages;
my @debug_messages;

my $post_data = CGI->new;

# Grab current upload queue
my @upload_queue;



$sth = $dbh->prepare("SELECT talk_id, priority, sequence FROM upload_queue ORDER BY priority DESC, sequence ASC");
$sth->execute;
while(my $row = $sth->fetchrow_hashref)
{	
	push @upload_queue, $row;
}

# Grab current transcode queue
my @transcode_queue;

$sth = $dbh->prepare("SELECT talk_id, priority, sequence FROM transcode_queue ORDER BY priority DESC, sequence ASC");
$sth->execute;
while(my $row = $sth->fetchrow_hashref)
{
        push @transcode_queue, $row;
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

	$output_html .= <<END;
<div id="confirmation" class="green_box">
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

}

# Form for transcode queue

$output_html .= <<END;
<div id="transcode_queue" class="blue_box">
<h3>Transcode Queue</h3>
<table>
<form>
<tr><td>Talk ID</td><td>Priority (Low - Med - High)</td></tr>
END

foreach my $talk (@transcode_queue)
{
	$output_html .= "<tr><td>$talk->{talk_id}</td><td>";
	for (1..3) {
		$output_html .= "<input type='radio' name='talk_$talk->{talk_id}_priority'";
		$output_html .= $talk->{priority} == $_ ? "checked" : "";
		$output_html .= ">";
	}
	$output_html .= "</td></tr>";
}

$output_html .= <<END;
</table>
</form>
</div>
END

# Form for upload queue

$output_html .= <<END;
<div id="upload_queue" class="blue_box">
<h3>Upload Queue</h3>
<table>
<form>
<tr><td>Talk ID</td><td>Priority (Low - Med - High)</td></tr>
END

foreach my $talk (@upload_queue)
{
        $output_html .= "<tr><td>$talk->{talk_id}</td><td>";
        for (1..3) {
                $output_html .= "<input type='radio' name='talk_$talk->{talk_id}_priority'";
                $output_html .= $talk->{priority} == $_ ? "checked" : "";
                $output_html .= ">";
        }
        $output_html .= "</td></tr>";
}



$output_html .= <<END;
</table>
</form>
</div>
END

push @debug_messages, "test!";
if(@debug_messages){

	$output_html .= <<END;
<div id="debug_messages" class="red_box">
END

foreach(@debug_messages) {
	$output_html .= "<p>$_</p>";
}


	$output_html .= <<END;
</div>
END



}

$output_html .= <<END;
</div>
</html>
END
print $post_data->header, $output_html;
