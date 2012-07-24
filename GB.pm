package GB;
use strict;

use DBI;


sub new {

	my $gb_o; # This is what gets blessed at the end 

	# Get conf
	my ($class, $conf_location) = @_;
	open CONF, $conf_location or die $!;
	our $conf = {};
	while(<CONF>)
	{
        	my @conf_line = split(/=/,$_);
	        chomp $conf_line[1];
        	$conf->{$conf_line[0]} = $conf_line[1];
	}

	# Set up variables, do initial processing

	my $db_engine = $conf->{'db_engine'};

	my $dbh;

	if ( $db_engine eq "mysql" ) {
		my $db_name = $conf->{'mysql_db'};
		my $db_host = $conf->{'mysql_host'};
		my $db_port = $conf->{'mysql_port'};
		my $dsn = "dbi:mysql:$db_name:$db_host:$db_port";
		my $db_user = $conf->{'mysql_user'};
		my $db_password =  $conf->{'mysql_pass'};
		$dbh = DBI->connect($dsn, $db_user, $db_password, { RaiseError => 1, AutoCommit => 1 }) or die "Cannot connect: $DBI::errstr";
	} elsif ( $db_engine eq "sqlite" ) {
		my $db_location = $conf->{'db_location'};
		my $dsn = "dbi:SQLite:$db_location";
		$dbh = DBI->connect($dsn, "" , "") or die "Cannot connect: $DBI::errstr";
	use Data::Dumper;
	warn Dumper($dbh);
	warn $db_location;

	}

	$gb_o = { db => $dbh , conf => $conf};

bless $gb_o;
return $gb_o;

}

1;
