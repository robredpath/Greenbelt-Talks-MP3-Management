

import mysql.connector
#read in the command line argument

import sys
from subprocess import check_output # creates a new command in this program which is loaded from an external subprocess
#this is in there so we can use Dmesg to check for the USB

import re
import time

orderid = sys.argv[1] #this takes the order number from the user input and assignes it to the orderid variable

#get the list of talks for that order from the database

cnx = mysql.connector.connect(user='gbtalks', password='WVmrQjkHlcTWCG5R',
                              host='localhost',
                              database='gb_talks')

#connects to the msql database to access the talks
cursor = cnx.cursor()

query = """SELECT orders_all_talks.order_id, orders_all_talks.order_year,
                                        orders_all_talks.talks AS all_talks,
                                        orders_available_talks.talks AS available_talks,
                                        (orders_all_talks.talks <=> orders_available_talks.talks) AS fulfillable,
                                        orders_all_talks.complete
                                        FROM
                                                (SELECT order_items.order_id, order_items.order_year,
                                                        group_concat('gb', RIGHT(order_items.talk_year, 2), '-',
                                                                LPAD(order_items.talk_id, 3, '000') ORDER BY order_items.talk_id) as talks,
                                                        complete
                                                FROM orders
                                                INNER JOIN order_items
                                                        ON (orders.id, orders.year) = (order_items.order_id, order_items.order_year)
                                                GROUP BY order_year, order_id
                                                ORDER BY order_id ASC, talk_id ASC) orders_all_talks LEFT JOIN
                                        (SELECT order_items.order_id, order_items.order_year,
                                                        group_concat('gb', RIGHT(order_items.talk_year, 2), '-',
                                                                LPAD(order_items.talk_id, 3, '000') ORDER BY order_items.talk_id) as talks,
                                                        complete
                                                FROM orders
                                                INNER JOIN order_items
                                                        ON (orders.id, orders.year) = (order_items.order_id, order_items.order_year)
                                                INNER JOIN talks ON (order_items.talk_id, order_items.talk_year) = (talks.id, talks.year)
                                                WHERE talks.available=1
                                                GROUP BY order_year, order_id
                                                ORDER BY order_id ASC, talk_id ASC) orders_available_talks
                                        ON (orders_all_talks.order_id, orders_all_talks.order_year) = (orders_available_talks.order_id, orders_available_talks.order_year)
					WHERE orders_all_talks.order_id = {0}"""

cursor.execute(query.format(orderid))
#this gets the list of talks for that order  from the database

#now check that the order is fulfillable

for (order_id, order_year, all_talks, available_talks, fulfillable, complete) in cursor:
	print ("Trying to fulfill order number {}".format(order_id))#prints out order number followed by 1 if order is fulfillable, 0 if not
	if (fulfillable == 0):#check if order is fulfillable
		print ("Order not fulfillable")#if not give error message to user
		sys.exit()#if order not fulfillable exit program
	else:
		#watch Dmesg for a usb device insertion
			#run Dmesg, grab timestamp from end of file
		initial_dmesg = check_output("dmesg")# puts the entire contents of the dmesg into the string initial_dmesg
		initial_dmesg_timestamp = re.search('([0-9]+)', initial_dmesg.split("\n")[-2]).group(0) #giving the timestamp of the dmesg
		current_dmesg_timestamp = initial_dmesg_timestamp
			#prompt user to insert the USB drive into any port
		print ("Please insert a blank USB stick")
	
			#run Dmesg again (once a second) until it sees a line that says
			#Attached SCSI removable disk with timestamp newer than previous timestamp
		while current_dmesg_timestamp == initial_dmesg_timestamp:
			current_dmesg = check_output("dmesg")#runs dmesg, checks to see if timestamp has updated
			current_dmesg_timestamp = re.search('([0-9]+)', current_dmesg.split("\n")[-2]).group(0)
			time.sleep(1)#waits for a second		  
			sys.stdout.write('.')#prints a dot to show that it's waiting
			sys.stdout.flush()
			
			#check the last line of the current dmesg to see if it's an attached disk or not
			#if so get the id
			#if not, set current_dmesg_timestamp back to initial_dmesg_timestamp to keep on waiting
		
			if re.search('(Attached SCSI)', current_dmesg.split("\n")[-2]): #checks the last line of Dmesg to see if it contains string Attached SCSI (shows USB has bene plugged in)
				attached_drive = re.search('(sd[a-z]+)', current_dmesg.split("\n")[-2]).group(0) #detecting letter of attached drive
			else:
				current_dmesg_timestamp = initial_dmesg_timestamp #if a USB hasn't actually been inserted we go back to the checking loop	
		

		print ("detected USB: " + attached_drive)#shows that a USB has been detected, gives it's letter


		#create a file system on the USB deviste that's just been inserted
		#copy the files from the hard drive to the USB
		#update the database to say that the order is complete

cursor.close()
cnx.close()


#simples
#that was easy

	
