#!/usr/bin/perl

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

# Is there any POST data? 
# If yes, sanitise and process. Possible end results are sanitise fail, new order added, or order marked as complete. 

# Regardless of whether there's POST data or now

# Output form for adding a new order - order ID, order items as a comma-separated list. 
$output_html .= <<END;

<div id="new_order_form">
<form method="post">
<input type="text" id="order_id">
<textarea id="order_items">
</form>  
</div>

END

# Output list of orders that can currently be fulfilled, with button to mark each as fulfilled

$output_html .= <<END;

<div id="orders_ready">
<form method="post">
<table>
END

#foreach order in saved orders
#check to see if we can complete the order, if we can then
#$output_html .= "<tr><td>$order_id</td><td>%order_items</td><td><input type='checkbox' name='orders_complete'></td></tr>"; 

$output_html .= <<END;
<tr><td>&nbsp;</td><td>&nbsp;</td><td><input type="submit" value="Mark Orders Completed" /></td></tr>
</table>
</form>
</div>

END

# Output list of all talks currently available
# Output details of all unfulfilled orders


# And the footer, just in case there's anything that needs to go here

$output_html .= <<END;

</body>
</html>
END

#Output page

print $output_html;
