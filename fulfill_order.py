#!/usr/bin/python

import mysql.connector
import sys
from subprocess import check_output, call # creates a new command in this program which is loaded from an external subprocess
#this is in there so we can use Dmesg to check for the USB

import re
import time
import os.path
import shutil

orderid = sys.argv[1] #this takes the order number from the user input and assignes it to the orderid variable

#get the list of talks for that order from the database

#open the configuration file
config_file = open('/var/www/gb_talks.conf')

#parse the config file 
config = dict([line.split("=") for line in config_file])#this creates a dictionary with the configuration stuff in it


cnx = mysql.connector.connect(user=config["mysql_user"].strip(), 
                              password=config["mysql_pass"].strip(),
                              host=config["mysql_host"].strip(),
                              database=config["mysql_db"].strip())


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



		#check that the USB has a partition
		#test that dev/attached_drive exists
		if not os.path.exists("/dev/" + attached_drive + "1"):
			#if the file path doesn't exist then exit
			print ("Partition doesn't exist")
			sys.exit()
		#print("mount /dev/{}1 /media/{}".format(attached_drive,attached_drive))
		#try and mount a file system
		mount_output = call("/usr/bin/mount /dev/{}1 /media/{}".format(attached_drive,attached_drive), shell=True)
		if mount_output != 0:
			print ("Can't mount the file system")
			sys.exit()		


		#check that USB is empty
		device_info = check_output("/usr/bin/df |/usr/bin/grep {}".format(attached_drive), shell=True).split()
		#test that value at position 1 is between 7.5m and 8m
		if int(device_info[1]) <  7500000 or int(device_info[1])> 8000000:
			print ("USB is wrong size")
			sys.exit()
		#and test that the value at position 2 is less than 100
		if int(device_info[2]) > 100:
			print("USB is not blank")
			sys.exit()
		#test that the value at position 5 is of the form /media/sd		
		if not re.search("media", check_output("/usr/bin/df | /usr/bin/grep {}".format(attached_drive), shell=True).split()[5]):
			print("USB is not a USB")
			sys.exit()

		#copy the files from the hard drive to the USB
		for talk in all_talks.split(","): #loops over the talks for the order
			print ("attempting to copy talk " + talk)
			shutil.copy2(config["upload_dir"].strip() + "/" + talk + "mp3.mp3", "/media/" + attached_drive + "/" + talk + "mp3.mp3" )
			 #copies across the talk from the host directory (upload dir) to the USB (media)
			print ("success")

		print ("all talks copied, please wait to remove USB")


cursor.close()

print("Cleaning up the database, please wait...")

#now repoen the cursor
cursor = cnx.cursor()

#then update the mysql database to say that the order is complete
query = "update orders set complete = 1 where id = " + orderid

cursor.execute(query)
cnx.commit()
cursor.close()
cnx.close()

print("Setting USB name. Nearly done, please wait...")

# Set USB drive name
mtools_output = call("MTOOLS_SKIP_CHECK=1 /usr/bin/mlabel -i /dev/{}1 ::GREENBELT".format(attached_drive), shell=True)

print("Unmounting, please wait...")

#unmount usb
mount_output = call("/usr/bin/umount  /media/{}".format(attached_drive), shell=True)

#prompt user to remove usb
print ("Please remove USB")
	
