#!/usr/bin/perl

use strict;
use warnings;

# If there is no lockfile
# while(sleep 10)
# pull queue from db
# rsync top item to remote server. Make sure to specify --partial to ensure that uploaded data isn't deleted when the connection dies. Or, --partial-dir for a cleaner solution
# API call (or rsh) to check md5sum of uploaded file
# log successful if everything worked, otherwise leave in queue, and log error

# SIGUSR1
# Print 
