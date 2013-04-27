#!/bin/sh

servers='fd fu mq fs'
for server in $servers; do
    ( cd node/$server; npm install )
done

