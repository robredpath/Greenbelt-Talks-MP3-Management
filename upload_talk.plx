#!/usr/bin/perl

# If there is POST data
# Sanitise (erm....how do you sanitise an MP3?)
# Get target filename from db based on selecion from calling page
# Open file for writing with appropriate name
# Write file
# Close file
# md5sum the file
# Write data to database - md5sum and acknowledge upload
# email contact to confirm availability (get contact from conf file)
