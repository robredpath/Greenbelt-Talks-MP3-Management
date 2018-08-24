#!/usr/bin/perl

use strict;
use warnings;
use Parallel::ForkManager;

use GB;

my $gb = GB->new("gb_talks.conf");
my $dbh = $gb->{db};
my $conf = $gb->{conf};

my $upload_dir = $conf->{'upload_dir'};
my $short_year = $conf->{'gb_short_year'};

my $sth;


# TODO: Capture a 'partial' flag which will trigger a partial run
# TODO: 


my $unavailable_talks = $dbh->selectcol_arrayref("SELECT COUNT(`id`) FROM talks WHERE available=0");
die "Not all talks are available! Quitting!" unless $unavailable_talks->[0] == 0;

print "Copying all talks to RAM";
# copy all the talks that are available to the RAMdisk
qx|mkdir /dev/shm/GBTALKS; cp -a /var/www/upload/gb${short_year}-*mp3.mp3 /dev/shm/GBTALKS; cp -a /var/www/upload/*${short_year}*.pdf /dev/shm/GBTALKS|;

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

		my $there_is_an_error;

		# Do some checks 
		$dmesg_output =~ /\[(sd[a-z]+)\]/ and $attached_drive = $1;
		warn "No dir in /media for $attached_drive \n" and $there_is_an_error = 1 unless -d "/media/$attached_drive";

		print "Detected drive: $attached_drive \n";
		
		# Mount the disk
		qx#/usr/bin/mount /dev/${attached_drive}1 /media/$attached_drive -o flush#;
		
		# Check that the disk is empty
		my $df_output = qx#/usr/bin/df | grep ${attached_drive}1#;
		my $free_space_on_usb;
		$df_output =~ /([0-9]+).*([0-9]+)/ and $free_space_on_usb = $2;
		warn "Disk isn't empty - remove and try again!\n" and $there_is_an_error = 1 unless $free_space_on_usb < 100;

		unless ($there_is_an_error) {
			push @attached_drives, $attached_drive;
			$number_of_disks--;
		} 
	}

	last if $number_of_disks == 0;
	sleep 0.5;
}

my $pm = new Parallel::ForkManager($ARGV[0]); 

foreach my $drive (@attached_drives) {
	$pm->start and next;
	print "starting copy to $drive\n";
	qx#MTOOLS_SKIP_CHECK=1 /usr/bin/mlabel -i /dev/${drive}1 ::GREENBELT#;

	# TODO: If we're on a partial run, 

	qx#cp -a /dev/shm/GBTALKS/* /media/$drive#;
	qx#/usr/bin/umount /media/$drive#;
	print "done copying to $drive\n";
	$pm->finish;
}

$pm->wait_all_children;
print "Done! Remove all USB drives\n"


