#!/usr/bin/perl 

use strict;
use warnings;

BEGIN {
        push @INC, '.';
	push @INC, '..';
}

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
use Digest::MD5;
use LWP::UserAgent;

use GB;

my $gb = GB->new("../../gb_talks.conf");
my $dbh = $gb->{db};


my $conf = $gb->{conf};
my $gb_short_year = $conf->{'gb_short_year'};
my $gb_long_year = "20$gb_short_year";

my $sth;

my @error_messages;
my @debug_messages;


sub log_it {
        my $message = $_[0];
        open LOG, ">>admin_log" or die $!;
        my $date = `date`;
        chomp $date;
        print LOG "[$date] [$$] [$message]\n";
        close LOG;
}



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
			$sth = $dbh->prepare("UPDATE transcode_queue SET priority = ? WHERE talk_id = ? AND talk_year = ?");
			$sth->execute ($new_priority, $talk_id, $gb_long_year);
		}
		# Reload the transcode queue
		undef @transcode_queue;
		$sth = $dbh->prepare("SELECT talk_id, talk_year, priority, sequence FROM transcode_queue ORDER BY priority DESC, sequence ASC");
		$sth->execute;
		while(my $row = $sth->fetchrow_hashref)
		{
        		push @transcode_queue, $row;
		}

	} elsif ($post_data->{'param'}->{'form_name'} eq "upload_queue") {
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

		my $ctx = Digest::MD5->new;

                        $ctx->add("action=suspend");
                        $ctx->add($conf->{'api_secret'});

                        # Try to suspend the talk. Log any errors. 
                        
			my $api_url = $conf->{'api_url'} . "GB$gb_short_year-@{$post_data->{'param'}->{'talk_suspend'}}[0]";
                        my $browser = LWP::UserAgent->new;
                        my $response = $browser->post("$api_url", [action => 'suspend', sig => $ctx->hexdigest ]);
                        if ($response->{_rc} == 200) {
			
			}
			                        else {
                                my $response_dump = Dumper($response);
                                log_it("API call for suspending GB$gb_short_year-@{$post_data->{'param'}->{'talk_suspend'}}[0] failed. Here's the response: \n\n$response_dump");
                        }

	
	} elsif (@{$post_data->{'param'}->{'form_name'}}[0] eq "replace") {

                my $ctx = Digest::MD5->new;

                        $ctx->add("action=replace");
                        $ctx->add($conf->{'api_secret'});

                        # Try to send the talk live. Log any errors. 
                        
                        my $api_url = $conf->{'api_url'} . "GB$gb_short_year-@{$post_data->{'param'}->{'talk_replace'}}[0]";
                        my $browser = LWP::UserAgent->new;
                        my $response = $browser->post("$api_url", [action => 'replace', sig => $ctx->hexdigest ]);
                        if ($response->{_rc} == 200) {
                        
			} else {
                        	my $response_dump = Dumper($response);
                                log_it("API call for replacing GB$gb_short_year-@{$post_data->{'param'}->{'talk_replace'}}[0] failed. Here's the response: \n\n$response_dump");
                        }
                    
                
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
<form method="post">
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
<h3>Upload Queue - Currently uploading: gb$gb_short_year-xxx</h3>
END

if(@upload_queue) {

        $output_html .= <<END;
<table>
<tr><td>Talk ID</td><td>Priority (Low - Med - High)</td></tr>
<form method="post">
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

<div id="suspend" class="blue_box">
<h3>Suspend Talk From Sale</h3>
<form method="post">
Talk ID (eg 100) <input type="text" name="talk_suspend"/>
<input type="hidden" name="form_name" value="suspend" />
<input type ="submit" value="Suspend from sale" />
</form>
</div>
END

$output_html .= <<END;

<div id="replace" class="blue_box">
<h3>Replace Talk</h3>
<form method="post">
Talk ID (eg 100) <input type="text" name="talk_replace"/>
<input type="hidden" name="form_name" value="replace" />
<input type ="submit" value="Replace" />
<p>Ensure that new talk and snip have been uploaded to server prior to replacing</p>
</form>
</div>
END



# Form to allow free entry of API fields, if needed

$output_html .= <<END;
<div id="custom_api" class="blue_box">
<h2>Custom API Call</h2>
<form method="post">
TODO: Implement me!
</form>
</div>
END

# Print out any debug messages, if there are any

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
