#!/bin/sh
#
# Run to populate the database with various test data
#
echo "Adding Viblios ..."
./script/add-viblios.pl data/viblios.txt

echo "Populating with data ..."
./script/test-populate.pl data/randomdata.csv

echo "Adding a profile picture for aqpeeb ..."
./script/wsclient.pl --quiet --port 3000 \
    --user aqpeeb@gmail.com --pass password \
    --service user/add_or_replace_profile_photo \
    --upload data/aqpeeb-pic.jpg -- uid=aqpeeb
