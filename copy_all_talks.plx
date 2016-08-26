#!/usr/bin/perl

use strict;
use warnings;
use Parallel::ForkManager;


# copy all the talks to the RAMdisk
qx|mkdir /dev/shm/GBTALKS16; cp -a /var/www/upload/*mp3.mp3 /dev/shm/GBTALKS16|;

my $number_of_disks = $ARGV[0];
my @attached_drives = ();

my $initial_dmesg_timestamp = "";

my $dmesg_output = qx#dmesg | tail -1#;
$dmesg_output =~ /([0-9]+\.[0-9]+)/ and $initial_dmesg_timestamp = $1;

my $current_dmesg_timestamp = $initial_dmesg_timestamp;	
	
while ($initial_dmesg_timestamp == $current_dmesg_timestamp) {

	# ask the user to start loading USB drives
	print "Please insert a USB drive - " . ($number_of_disks) . " to go: \n";

	# watch dmesg, identify drive letters, check that inserted drive has a partition and nothing on it
	$dmesg_output = qx#dmesg | tail -1#;
	$dmesg_output =~ /([0-9]+\.[0-9]+)/ and $current_dmesg_timestamp = $1;
	
	if ($current_dmesg_timestamp > $initial_dmesg_timestamp) {
		# reset the clock so that next loop doesn't just assess the same thing
		$initial_dmesg_timestamp = $current_dmesg_timestamp;
		
		# Check that it's a 'new drive' line
		next unless $dmesg_output =~ /Attached SCSI/;
			
		# Grab the drive letter
		my $attached_drive = ""; 
		$dmesg_output =~ /\[(sd[a-z]+)\]/ and $attached_drive = $1;
		warn "No dir in /media for $attached_drive \n" unless -d "/media/$attached_drive";

		print "Detected drive: $attached_drive \n";
		
		# Mount the disk
		qx#/usr/bin/mount /dev/${attached_drive}1 /media/$attached_drive#;

		push @attached_drives, $attached_drive;
		$number_of_disks--;
	}

	last if $number_of_disks == 0;

	sleep 1;
}

my $pm = new Parallel::ForkManager($ARGV[0]); 

foreach my $drive (@attached_drives) {
	$pm->start and next;
	print "starting copy to $drive\n";
	qx#MTOOLS_SKIP_CHECK=1 /usr/bin/mlabel -i /dev/${drive}1 ::GREENBELT#;
	qx#cp -a /dev/shm/GBTALKS16/* /media/$drive#;
	qx#/usr/bin/umount /media/$drive#;
	print "done copying to $drive\n";
	$pm->finish;
}

$pm->wait_all_children;
print "Done! Remove all USB drives\n"


