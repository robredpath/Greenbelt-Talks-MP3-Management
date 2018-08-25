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

use GB;

my $gb = GB->new("gb_talks.conf");
my $conf = $gb->{conf};

my $dbh = $gb->{db};
my $unavailable_talks = $dbh->selectcol_arrayref("SELECT COUNT(`id`) FROM talks WHERE available=0");
if ($unavailable_talks->[0] == 0) {

	print "****NOT ALL TALKS AVAILABLE - STARTING PARTIAL COPY****\n";

} else {

	print "***ALL TALKS AVAILABLE - STARTING FULL COPY****\n";

}


my $upload_dir = $conf->{'upload_dir'};
my $short_year = $conf->{'gb_short_year'};

my $pm = new Parallel::ForkManager(5);

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
                warn "No dir in /media for $attached_drive \n" and $error = 1 unless -d "/media/$attached_drive";
                print "[USB #$id] Detected drive: $attached_drive\n";
                qx#/usr/bin/mount /dev/${attached_drive}1 /media/$attached_drive -o flush#;

		# Die if there's a problem here
		if ($error) {
			print "[USB #$id] ERROR - Aborting. Remove drive\n";
			next OUTER;
		}
			
	}

	$pm->start and next;
	print "[USB #$id] Starting copy\n";
        qx#MTOOLS_SKIP_CHECK=1 /usr/bin/mlabel -i /dev/${attached_drive}1 ::GREENBELT#;
	qx#rsync -a /dev/shm/GBTALKS/* /media/$attached_drive#;
        qx#/usr/bin/umount /media/$attached_drive#;
        print "[USB #$id] Done - Remove drive\n";

        $pm->finish;	
}


