#!/bin/sh

servers='mq'
for server in $servers; do
    ( cd node/$server; npm install )
done

