#!/bin/sh

servers='mq'
for server in $servers; do
    ( cd node/$server; /usr/local/bin/npm install )
done

