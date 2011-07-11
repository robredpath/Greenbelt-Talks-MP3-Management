# Get conf

use DBI;

open CONF, "../gb_talks.conf" or die $!;
our $conf = {};
while(<CONF>)
{
        my @conf_line = split(/=/,$_);
        chomp $conf_line[1];
        $conf->{$conf_line[0]} = $conf_line[1];
}



# Set up variables, do initial processing

my $db_name = $conf->{'mysql_db'};
my $db_host = $conf->{'mysql_host'};
my $db_port = $conf->{'mysql_port'};

my $dsn = "dbi:mysql:$db_name:$db_host:$db_port";
my $db_user = $conf->{'mysql_user'};
my $db_password =  $conf->{'mysql_pass'};

our $dbh = DBI->connect($dsn, $db_user, $db_password, { RaiseError => 1, AutoCommit => 1 });

our $gb_short_year = $conf->{'gb_short_year'};
our $gb_long_year = $conf->{'gb_long_year'};

