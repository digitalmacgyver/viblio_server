#!/bin/sh
last_resort="$1"
servers='mq'
for server in $servers; do
    ( cd node/$server; (/usr/local/bin/npm install||cp -rf $last_resort/node_modules .) )
done

