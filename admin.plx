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

push @debug_messages, Dumper($post_data);

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
my @currently_online_talks;

# Are there any requested actions? If so, do them. 

if($post_data->{'param'}->{'form_name'})
{
	if (@{$post_data->{'param'}->{'form_name'}}[0] eq "transcode_queue") {
		foreach(@transcode_queue)
		{
			my $talk_id = $_->{'talk_id'};
			my $new_priority = $1 if @{$post_data->{'param'}->{$_->{'talk_id'}}}[0] =~ /([0-9]?)/;
			push @debug_messages, $talk_id;
			$sth = $dbh->prepare("UPDATE transcode_queue SET priority = ? WHERE talk_id = ?");
			$sth->execute ($new_priority, $talk_id);
		}
		# Reload the transcode queue
		undef @transcode_queue;
		$sth = $dbh->prepare("SELECT talk_id, priority, sequence FROM transcode_queue ORDER BY priority DESC, sequence ASC");
		$sth->execute;
		while(my $row = $sth->fetchrow_hashref)
		{
        		push @transcode_queue, $row;
		}

	} elsif ($post_data->{'form_name'} eq "upload_queue") {
                foreach(@upload_queue)
                {
                        my $talk_id = $_->{'talk_id'};
                        my $new_priority = $1 if @{$post_data->{'param'}->{$_->{'talk_id'}}}[0] =~ /([0-9]?)/;
                        push @debug_messages, $talk_id;
                        $sth = $dbh->prepare("UPDATE upload_queue SET priority = ? WHERE talk_id = ?");
                        $sth->execute ($new_priority, $talk_id);
                }
                # Reload the transcode queue
                undef @upload_queue;
                $sth = $dbh->prepare("SELECT talk_id, priority, sequence FROM upload_queue ORDER BY priority DESC, sequence ASC");
                $sth->execute;
                while(my $row = $sth->fetchrow_hashref)
                {
                	push @upload_queue, $row;                                                                                         }
        } elsif (@{$post_data->{'param'}->{'form_name'}}[0] eq "suspend") {
	
	}
}


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
END

if(@transcode_queue) {

	$output_html .= <<END;
<table>
<tr><td>Talk ID</td><td>Priority (Low - Med - High)</td></tr>
<form method="post" action="admin.plx">
END

	foreach my $talk (@transcode_queue)
	{
		$output_html .= "<tr><td>$talk->{talk_id}</td><td>";
		for (1..3) {
			$output_html .= "<input type='radio' name='$talk->{talk_id}' value = '$_' ";
			$output_html .= $talk->{priority} == $_ ? " checked " : "";
			$output_html .= ">";
		}
		$output_html .= "</td></tr>";
	}


	$output_html .= <<END;
</table>
<input type="hidden" name="form_name" value="transcode_queue" />
<input type="submit" value="Update queue" />
</form>
END

} else {

	$output_html .= "The transcode queue is currently empty";

}

$output_html .= <<END;
</div>
END

# Form for upload queue

$output_html .= <<END;
<div id="upload_queue" class="blue_box">
<h3>Upload Queue - Currently uploading: gb11-110</h3>
END

if(@upload_queue) {

        $output_html .= <<END;
<table>
<tr><td>Talk ID</td><td>Priority (Low - Med - High)</td></tr>
<form method="post" action="admin.plx">
END

        foreach my $talk (@upload_queue)
        {
                $output_html .= "<tr><td>$talk->{talk_id}</td><td>";
                for (1..3) {
                        $output_html .= "<input type='radio' name='talk_$talk->{talk_id}' value='$_'";
                        $output_html .= $talk->{priority} == $_ ? "checked" : "";
                        $output_html .= ">";
                }
                $output_html .= "</td></tr>";
        }


        $output_html .= <<END;
</table>
<input type="hidden" name="form_name" value="upload_queue" />
<input type="submit" value="Update queue" />
</form>
END

} else {
        $output_html .= "The upload queue is currently empty";
}

$output_html .= <<END;
</div>
END

$output_html .= <<END;

<div id="current_online_talks" class="blue_box">
<h3>Talks currently online</h3>
END

if(@currently_online_talks) {

        $output_html .= <<END;
<table>
<tr><td>Talk ID</td><td>Suspend from sale</td></tr>

<form method="post">
Talk ID (eg 100) <input type="text" />
<input type="hidden" name="form_name" value="suspend" />
<input type ="submit" value="Suspend from sale" />
</form>
</table>
END

} else {
        $output_html .= "There are no talks currently online";
}



$output_html .= <<END;

</div>
END

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
