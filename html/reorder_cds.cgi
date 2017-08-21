#!/usr/bin/perl

BEGIN {
        push @INC, '.' , '..';
}

use strict;
use warnings;

#************************************************************************
# reorder_cds.cgi
#
# A script to handle ordering CDs for duplication
#
# Inputs:
# 
# POST submission of CDs required
#
# Outputs:
#
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
my $gb_short_year = $conf->{'gb_short_year'};
my $gb_long_year = "20$gb_short_year";
my $sth;
my $rv;

my $status_messages = [];
my $error_messages = [];

# If there is POST data
my $post_data = new CGI;

if ($post_data->param('talks_ids'))
{
	my @order_items = split(" ",$post_data->param('order_items'));
        $new_order->{'order_items'} = \@order_items;
	
	$sth = $dbh->prepare("INSERT INTO cd_orders
	
	foreach my $order (@order_items) {
		$sth = $dbh->prepare("INSERT INTO cd_orders(`talk_id`,`priority`,`talk_id`, `talk_year`) VALUES (NULL,2,?,?)");
	}
	$sth = $dbh->prepare("INSERT INTO cd_orders(`sequence`,`priority`,`talk_id`, `talk_year`) VALUES (NULL,2,?,?)");
	$rv = $sth->execute($talk_id, $gb_long_year);
	# Mark as uploaded
	$sth = $dbh->prepare("UPDATE `talks` SET `uploaded`=1 where `id`=? AND `year`=?");
	$rv = $sth->execute($talk_id, $gb_long_year);

	push $status_messages, "Talk $talk_id uploaded";
} elsif ($post_data->param('talk_id')) {
	push $error_messages, "Both mp3 and snip file are required";
}


my $non_uploaded_talks = $dbh->selectcol_arrayref("SELECT `id` FROM talks WHERE uploaded = 0 AND start_time < NOW()");

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
