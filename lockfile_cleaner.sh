#!/bin/bash
# Clean up lockfiles. We assume that no operation takes >1h

find /var/run/ -name "gb_*" -mmin +60 -exec rm {} \;

