#!/usr/bin/perl -T
use strict;
use warnings;

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

require "./environ.pm";
our $dbh;
our $conf;
my $gb_short_year = $1 if $conf->{'gb_short_year'} =~ /([0-9]{2})/;
my $sth;
my $rv;
my $sql;
my @debug_messages;
my @error_messages;

# Get all talks
my $talks = $dbh->selectall_hashref('SELECT `id`, `available` FROM `talks`','id');

# Get all existing order IDs to handle errors cleanly
$sth = $dbh->prepare("SELECT `id` from `orders`");
$sth->execute();
my $existing_orders = $sth->fetchall_arrayref;

# Get POST data
my $post_data = CGI->new;
my $new_order = { };
my $order_is_viable;
if($post_data->param('order_id'))
{
	# TODO: sanitise data first!
	$new_order->{'id'}=$post_data->param('order_id');
	unless(grep /^$new_order->{id}$/, @{$existing_orders} )
	{
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
		# add order ID into orders table
		$sth = $dbh->prepare("INSERT INTO `orders`(`id`, `additional_talks`) VALUES (?,?)");
		$sth->execute($new_order->{id}, @additional_talks ? @additional_talks : undef );
		# add items into order_items table
		foreach(@this_years_talks)
		{
			$sth = $dbh->prepare("INSERT INTO `order_items`(`order_id`,`talk_id`) VALUES (?,?)"); 
			$rv = $sth->execute($new_order->{'id'}, $_);
		}
	} else {
		push @error_messages, "Error: Order $new_order->{id} already exists";
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

# Get all incomplete orders
my $saved_orders = { }; 
$sth = $dbh->prepare("SELECT `id` FROM `orders` WHERE `complete`=0");
$sth->execute();
my @orders;
while (my @data = $sth->fetchrow_array)
{
        push @orders, $data[0];
}

# Get the contents of each order
foreach(@orders)
{
	my @order;
	$sth = $dbh->prepare("SELECT `talk_id` FROM `order_items` WHERE `order_id`= ?");
	$sth->execute($_);
	while (my @data = $sth->fetchrow_array)
	{ 
		push @order, $data[0];
	}
	$sth = $dbh->prepare("SELECT `additional_talks` FROM `orders` WHERE `id` = ?");
	$sth->execute($_);
	push @order, $sth->fetchrow_array;
	$saved_orders->{$_} = \@order;
}

# Calculate fulfillable orders by iterating over the available talks list for each item on the order. If any returns false, stop trying and return an error. If none return false, assume success. 

my %f_orders; # f_orders = fulfillable orders. Just hard to spell consistently!

foreach(keys %$saved_orders)
{
	my $order_can_be_fulfilled = 1; # Assume that the order can be fulfilled
	foreach(@{$saved_orders->{$_}}) # should be an arrayref
	{
		# We can't fulfill an order if the talk isn't available
		$order_can_be_fulfilled = 0 unless $talks->{$_}->{available};
		# Talks other than those in the current year are undef as they're not in the talks db table.
		$order_can_be_fulfilled = 1 unless defined $talks->{$_}->{id};
		last unless $order_can_be_fulfilled; 
	}
	if($order_can_be_fulfilled)
	{
		%f_orders->{$_}++;
	}
	
}


# Get all completed orders

my $completed_orders = { };
$sth = $dbh->prepare("SELECT `id` FROM `orders` WHERE `complete`=1");
$sth->execute();
my @orders;
while (my @data = $sth->fetchrow_array)
{
        push @orders, $data[0];
}

foreach(@orders)
{
        my @order;
        $sth = $dbh->prepare("SELECT `talk_id` FROM `order_items` WHERE `order_id`= ?");
        $sth->execute($_);
        while (my @data = $sth->fetchrow_array)
        {
                push @order, $data[0];
        }
        $sth = $dbh->prepare("SELECT `additional_talks` FROM `orders` WHERE `id` = ?");
        $sth->execute($_);
        push @order, $sth->fetchrow_array;
        $completed_orders->{$_} = \@order;
}


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
<h2>Greenbelt Talks Team - mp3 orders</h2>
</div>
END

# Was there any POST data? If so, output confirmation that the request has been processed

if($post_data->param('order_id'))
{

$output_html .= <<END;

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
	}
	else
	{
		$output_html .= "Your request has been successfully processed";
	}

$output_html .= <<END;

</div>

END


}

# Form for adding a new order - order ID, order items as a space-separated list. 
$output_html .= <<END;

<div id="new_order_form">
<form method="post">
<h3>New Order</h3>
<p>Order ID<input type="text" name="order_id"></p>
<p>Talks. Separate values with spaces. Talks without a prefix are implicitly prefixed gb$gb_short_year- <textarea id="order_items" name="order_items"></textarea></p>
<p><input type="submit" /></p>
</form>
</div>

END


# Output list of all talks currently available

$output_html .= <<END;

<div id="available_talks">
<h3>Available Talks</h3>
<p>
END

foreach(sort values %$talks)
{
	$output_html .= "$_->{id} " if $_->{available};
}

$output_html .= <<END;
</p>
</div>

END


# Output details of all unfulfilled orders

$output_html .= <<END;

<div id="saved_orders">
<h3>Pending Orders</h3>
<form method="POST">
<table>
<tr><td>Order ID</td><td>Talks in Order</td><td>F?</td><td>Complete?</td></tr>
END

foreach(sort keys %$saved_orders)
{
	next unless %f_orders->{$_};
        $output_html .= "<tr><td>$_</td><td>";
	foreach(@{$saved_orders->{$_}})
	{
		$output_html .= "$_ ";
	}
	$output_html .= "</td><td>F</td><td><input type='checkbox' name='order_complete' value='$_'></td></tr>";
}

foreach(sort keys %$saved_orders)
{
        next if %f_orders->{$_};
        $output_html .= "<tr><td>$_</td><td>";
        foreach(@{$saved_orders->{$_}})
        {
                $output_html .= "$_ ";
        }
        $output_html .= "</td><td> </td><td><input type='checkbox' name='order_complete' value='$_'></td></tr>";
}

$output_html .= <<END;
</table>
<input type="submit" value="Mark orders as complete" />
</form>
</div>

END

# Output list of orders that have been completed
$output_html .= <<END;
<div id="completed_orders" class="blue_box">
<h3>Completed Orders</h3>
<table>
<tr><td>Order ID</td><td>Talks in Order</td></tr>
END

foreach(sort keys %$completed_orders)
{
        $output_html .= "<tr><td>$_</td><td>";
        foreach(@{$completed_orders->{$_}})
        {
                $output_html .= "$_ ";
        }
        $output_html .= "</td></tr>";
}

$output_html .= <<END;
</table>
</div>

END

# Output debug messages
if (@debug_messages) {
$output_html .= <<END;

<div id ="debug">

<h3>Debug messages</h3>
END

foreach(@debug_messages)
{

        $output_html .= "<p>" . $_ . "</p>";

}
$output_html .= <<END;

</div>

END
}
# And the footer, just in case there's anything that needs to go here

$output_html .= <<END;

</div>
</body>
</html>
END

#Output page

print $post_data->header, $output_html;
