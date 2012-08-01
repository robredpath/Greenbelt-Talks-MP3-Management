#!/usr/bin/perl

use strict;
use warnings;

BEGIN {
	push @INC, '.';
}

#************************************************************************
# orders.plx
#
# A script to handle order management for mp3s. 
#
# Inputs:
# 
# New Order - Order ID, Talk IDs of talks ordered
#
# Outputs:
#
# HTML page containing all current orders, all currently available talks
# and a list of orders that can currently be fulfilled, with buttons to
# mark them as such
#************************************************************************

use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use DBI;
use Data::Dumper;
use Template;

use GB;

my $gb = GB->new("../gb_talks.conf");
my $dbh = $gb->{db}; 
my $conf = $gb->{conf};

my $gb_short_year = $1 if $conf->{'gb_short_year'} =~ /([0-9]{2})/;
my $gb_long_year = "20$gb_short_year";
my $sth;
my $rv;
my $sql;
my $debug_messages;
my $error_messages;

my $orders = $dbh->selectall_hashref("SELECT orders_all_talks.order_id, orders_all_talks.order_year, orders_all_talks.talks, orders_available_talks.talks,
                                        (orders_all_talks.talks <=> orders_available_talks.talks) AS fulfillable,
					orders_all_talks.completed
                                        FROM
                                        	(SELECT order_items.order_id, order_items.order_year, 
							group_concat('gb', RIGHT(order_items.talk_year, 2), '-', 
								IF(LENGTH(order_items.talk_id)=1, LPAD(order_items.talk_id, 2, '00'), order_items.talk_id)) as talks, 
							completed 
						FROM orders 
						INNER JOIN order_items 
							ON (orders.id, orders.year) = (order_items.order_id, order_items.order_year) 
						GROUP BY order_year, order_id) orders_all_talks,
                                        (SELECT order_items.order_id, order_items.order_year, 
							group_concat('gb', RIGHT(order_items.talk_year, 2), '-', 
								IF(LENGTH(order_items.talk_id)=1, LPAD(order_items.talk_id, 2, '00'), order_items.talk_id)) as talks, 
							completed 
						FROM orders 
						INNER JOIN order_items 
							ON (orders.id, orders.year) = (order_items.order_id, order_items.order_year) 
						INNER JOIN talks ON (order_items.talk_id, order_items.talk_year) = (talks.id, talks.year) 
						WHERE talks.available=1 GROUP BY order_year, order_id) orders_available_talks
					WHERE (orders_all_talks.order_id, orders_all_talks.order_year) = (orders_available_talks.order_id, orders_available_talks.order_year)
					", ['completed','fulfillable','order_id']);


warn Dumper($orders);

# Get all talks
my $talks = $dbh->selectall_hashref('SELECT `id`, `available` FROM `talks`','id');

# Get available talks
my $available_talks = $dbh->selectcol_arrayref("SELECT id from talks where available=1");

# Get all existing order IDs so that we can't double-enter.
$sth = $dbh->prepare("SELECT `id` from `orders` WHERE year=$gb_long_year");
$sth->execute();
my @existing_orders;
while(my @order = $sth->fetchrow_array)
{
	push @existing_orders, $order[0];
}


# Get POST data
my $post_data = CGI->new;
my $new_order = { };
my $order_is_viable;
if($post_data->param('order_id'))
{
	# TODO: sanitise data first!
	$new_order->{'id'}=$post_data->param('order_id');
	my @order_items = split(" ",$post_data->param('order_items'));
	$new_order->{'order_items'} = \@order_items;
	# parse order items
	my @this_years_talks;
	my @additional_talks;
	foreach(@{$new_order->{'order_items'}})
	{
		push @this_years_talks, $_ if /^[0-9]{1,3}$/;
		push @additional_talks, $_ if /^gb[0-9]{2}-[0-9]{1,3}$/;
	}
	# Create a new order if there isn't one already
	unless(grep /^$new_order->{id}$/, @existing_orders ) {
		# add order ID into orders table
		$sth = $dbh->prepare("INSERT INTO `orders`(`id`, `additional_talks`) VALUES (?,?)");
		$sth->execute($new_order->{id}, @additional_talks ? @additional_talks : undef );
	}
	# add items into order_items table
	foreach my $talk (@this_years_talks)
	{
		$sth = $dbh->prepare("INSERT INTO `order_items`(`order_id`,`talk_id`) VALUES (?,?)"); 
		$rv = $sth->execute($new_order->{'id'}, $talk);
	}
}

if($post_data->param('order_complete'))
{
        # TODO: sanitise data first!
	# Mark order complete in database
	my @completed_orders = $post_data->param('order_complete');
	foreach(@completed_orders)
	{
		$sth = $dbh->prepare("UPDATE `orders` SET `complete`=1 WHERE id=?");
		$rv = $sth->execute($_);
	}	
}

# TODO: Add box set support

my $is_response = 0;

if($post_data->param('order_id')) {
	$is_response = 1;
}


# And the footer, just in case there's anything that needs to go here

#Output page

print $post_data->header;

my $output_vars = {
	error_messages => $error_messages,
	is_response => $is_response,
	gb_short_year => $gb_short_year,
	available_talks => $available_talks,
	fulfillable_orders => $orders->{0}->{1}, # completed -> fulfillable
	unfulfillable_orders => $orders->{0}->{0}, # ditto
	completed_orders => $orders->{1}->{1}, # There should be no completed but unfulfillable orders. TODO: some hash merging
};


warn Dumper($output_vars);

my $tt = Template->new({
	INCLUDE_PATH => '/var/www/html/templates'
});


$tt->process('orders.tmpl', $output_vars);





