#!/usr/bin/perl
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
use DBI;

# Set up variables, do initial processing

my $sth;

my $dsn;
my $db_user;
my $db_password;

my $dbh = DBI−>connect($dsn, $db_user, $db_password,
                             { RaiseError => 1, AutoCommit => 1 });

# Get all talks
my @talks;
$sth = $dbh->prepare("SELECT `id` FROM `talks`");
$sth->execute();
while (my @data = $sth->fetchrow_array)
{
 push @talks, @data[0];
}

# Get available talks
my @available_talks;
$sql = "SELECT `id` from `talks` where `available`=1";
# execute SQL, assign values


# Get POST data

my $post_data = new CGI;
my %new_order;
my $order_is_viable;
if(exists $post_data->param('order_id'))
{
	# TODO: sanitise data first!
	$new_order->{'id'}=$post_data->param('order_id');
	@new_order->{'order_items'}=split(" ",$post_data->param('order_items'));
	# check that order is viable - no invalid data
	foreach(@new_order->{'order_items'})
	{
		
	}
	# add order ID into orders table
	$sql = "INSERT INTO `orders`(`id`) VALUES ('$new_order->{'id'}')";
	# execute SQL
	# add items into order_items table
	foreach(@new_order->{'order_items'})
	{
		$sql = "INSERT INTO `order_items`(`order_id`,`talk_id`) VALUES ('$new_order->{'id'}','$_'); 
		#execute SQL
	}
}


# Get current unfulfilled orders
my %saved_orders; 
$sql = "SELECT `id` FROM `orders`";
my @orders; # intialise with returned resultset
my @order;
foreach(@orders)
{
	$sql = "SELECT `talk_id` FROM `order_items` WHERE `order_id`='$_'"
	%saved_orders->{$_} = @order;
}

# Calculate fulfillable orders

my @f_orders; # f_orders = fulfillable orders. Just hard to spell consistently!

foreach(keys %saved_orders)
{
	my $order_can_be_fulfilled = TRUE; #Assume that an order can be fulfilled until proved otherwise
	foreach(@saved_orders->{$_}) # $_ is an array
	{
		$order_can_be_fulfilled = FALSE unless grep($_, @available_talks);
		last unless $order_can_be_fulfilled; 
	}
	if($order_can_be_fulfilled)
	{
		push @f_orders, %saved_orders->{$_};
	}
	
}

# Set up the HTML header

$output_html = <<END;

<html>
<body>

<div id="logo">
<img src="gb_logo.png" />
</div>
<div id="title">
<p>Greenbelt Talks Team - mp3 orders</p>
</div>
END

# Was there any POST data? If so, output confirmation that the order has been saved

# Form for adding a new order - order ID, order items as a comma-separated list. 
$output_html .= <<END;

<div id="new_order_form">
<form method="post">
<h2>New Order</h2>
<p>Order ID<input type="text" id="order_id"></p>
<p>Talks(comma separate list, with gb11 (or other year prefix))<textarea id="order_items"></p>
</form>
</div>

END

# List of orders that can currently be fulfilled, with button to mark each as fulfilled

# Header
$output_html .= <<END;

<div id="orders_ready">
<form method="post">
<table>
<th><td>Order ID</td><td>Talks in Order</td><td>Completed?</td></th>
END

foreach($f_orders)
{
	#check to see if we can complete the order, if we can then
	$output_html .= "<tr><td>$order_id</td><td>%order_items</td><td><input type='checkbox' name='order_$order_id_complete'></td></tr>"; 
}


$output_html .= <<END;
<tr><td>&nbsp;</td><td>&nbsp;</td><td><input type="submit" value="Mark Orders Completed" /></td></tr>
</table>
</form>
</div>

END

# Output list of all talks currently available

$output_html .= <<END

<div id="available_talks">

END

foreach($available_talks)
{
	
}

$output_html .= <<END

</div>

END


# Output details of all unfulfilled orders

$output_html .= <<END

<div id="saved_orders">
<h2>Pending Orders</h2>
<table>
<th><td>Order ID</td><td>Talks in Order</td></th>
END

foreach($saved_orders)
{

}

$output_html .= <<END
</table>
</div>

END


# And the footer, just in case there's anything that needs to go here

$output_html .= <<END;

</body>
</html>
END

#Output page

print $output_html;
