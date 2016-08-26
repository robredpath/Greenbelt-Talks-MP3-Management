#!/bin/bash

# Create dirs in /media for mounting on
echo sd{a..z} | xargs -I{} -d" " -n1 mkdir /media/{}
echo sd{a..z}{a..z} | xargs -I{} -d" " -n1 mkdir /media/{}
echo sd{a..z}{a..z}{a..z} | xargs -I{} -d" " -n1 mkdir /media/{}


