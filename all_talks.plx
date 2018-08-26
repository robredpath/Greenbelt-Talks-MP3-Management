#!/usr/bin/perl

$SIG{'INT'} = sub {
		print "SIGNAL RECIEVED: WAITING FOR PROCESSES TO FINISH BEFORE QUITTING\n";
		$pm->wait_all_children;
		print "Done!\n";
		exit 0;
	};

use strict;
use warnings;
use Parallel::ForkManager;
#use IPC::System::Simple qw(run);

use GB;

my $gb = GB->new("gb_talks.conf");
my $conf = $gb->{conf};

my $dbh = $gb->{db};
my $unavailable_talks = $dbh->selectcol_arrayref("SELECT COUNT(`id`) FROM talks WHERE available=0");
if (! $unavailable_talks->[0] == 0) {

	print "****NOT ALL TALKS AVAILABLE - STARTING PARTIAL COPY****\n";

} else {

	print "***ALL TALKS AVAILABLE - STARTING FULL COPY****\n";

}


my $upload_dir = $conf->{'upload_dir'};
my $short_year = $conf->{'gb_short_year'};

my $pm = new Parallel::ForkManager(50);

print "Copying all talks to RAM\n";
# copy all the talks that are available to the RAMdisk
qx|mkdir -p /dev/shm/GBTALKS; rsync -a /var/www/upload/gb${short_year}-*mp3.mp3 /dev/shm/GBTALKS; cp -a /var/www/upload/*${short_year}*.pdf /dev/shm/GBTALKS|;
print "Copied; ready to start\n";

my $dmesg_output = qx#dmesg | tail -1#;
$dmesg_output =~ /([0-9]+\.[0-9]+)/ and my $last_dmesg_timestamp = $1;

OUTER:
foreach my $id (1..100) {
	
	print "[USB #$id] Insert USB \n";
	
	my $attached_drive = "";

        while(length $attached_drive == 0) {
		# Capture dmesg output, until we see a new drive line
		$dmesg_output = qx#dmesg | tail -1#;
		$dmesg_output =~ /([0-9]+\.[0-9]+)/ and my $current_dmesg_timestamp = $1;
		sleep 1;
		next unless $current_dmesg_timestamp > $last_dmesg_timestamp;
		$last_dmesg_timestamp = $current_dmesg_timestamp;
		next unless $dmesg_output =~ /Attached SCSI/;

		# Work out the drive letter, then check that it's got a drive
                my $error;
		$dmesg_output =~ /\[(sd[a-z]+)\]/ and $attached_drive = $1;
		-d "/media/$attached_drive" or 
			print "[USB #id] FAILED - No dir in /media for $attached_drive." and
			next OUTER;
                print "[USB #$id] Detected drive: $attached_drive\n";
                qx#/usr/bin/mount /dev/${attached_drive}1 /media/$attached_drive -o flush#;  
		if ($? != 0 ) {
			print "[USB #$id] FAILED - Unable to mount USB. Remove USB - it may be bad\n";
			next OUTER;
		}

		# Die if there's a problem here
		if ($error) {
			print "[USB #$id] ERROR - Aborting. Remove drive\n";
			next OUTER;
		}
			
	}

	$pm->start and next;
	print "[USB #$id] Starting copy\n";
        qx#MTOOLS_SKIP_CHECK=1 /usr/bin/mlabel -i /dev/${attached_drive}1 ::GREENBELT#;
	if ($? != 0 ) { 
		print "[USB #$id] FAILED - unable to change drive name\n";
	} else {
		qx#rsync -a /dev/shm/GBTALKS/* /media/$attached_drive#;
		if ($? != 0 ) { 
			print "[USB #$id] FAILED - rsync failed\n";
		}
	}
       	qx#/usr/bin/umount /media/$attached_drive#;
		if ($? != 0 ) {
			print "[USB #$id] FAILED - unable to unmount drive\n";
		}
        print "[USB #$id] Remove drive\n";

        $pm->finish;	
}


