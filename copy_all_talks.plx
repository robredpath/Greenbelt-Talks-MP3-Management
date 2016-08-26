#!/usr/bin/perl

use strict;
use warnings;

# copy all the talks to the RAMdisk
qx|cp -a /var/www/upload /dev/shm/GBTALKS16|;
# ask the user to start loading USB drives
print("Please insert a USB drive, or type 'go' to start copying: ");

my @attached_drives = (");

while(my $var = <>){
	print "var: $var";
	chomp($var);

	my $initial_dmesg_timestamp = "";

	my $dmesg_output = qx#dmesg | tail#;
	$dmesg_output =~ /([0-9]+)/ and $initial_dmesg_timestamp = $1;

	my $current_dmesg_timestamp = $initial_dmesg_timestamp;
	print("Please insert a USB drive, or type 'go' to start copying");	
	
	while ($initial_dmesg_timestamp == $current_dmesg_timestamp) {

		# watch dmesg, identify drive letters, check that inserted drive has a partition and nothing on it
		$dmesg_output = qx#dmesg | tail#;
		if ($dmesg_output =~ /([0-9]+)/) {
        		my $current_dmesg_timestamp = $1;
		}
	
		if ($current_dmesg_timestamp > $initial_dmesg_timestamp) {
			# reset the clock so that next loop doesn't just assess the same thing
			$initial_dmesg_timestamp = $current_dmesg_timestamp;

			# Check that it's a 'new drive' line
			next unless $dmesg_output =~ /Attached SCSI/;
		
			# Grab the drive letter
			my $attached_drive = ""; 
			$dmesg_output =~ /(\[sd[a-z]+\])/ and $attached_drive = $1;
			warn "No dir in /media for $attached_drive" unless -d "/media/$attached_drive";
		
			# Mount the disk
			qx# mount /dev/${attached_drive}1 /media/$attached_drive # or warn "Could not mount disk";

			@attached_drives.push($attached_drive);
		}

		# repeat until user says to start copying
		last if $var eq "go";
	}

	last if $var eq "go";
}

print "done!";

# Start copying!
#

foreach @attached_drives {
	print $_;
}
