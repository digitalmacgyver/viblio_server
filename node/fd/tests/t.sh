#!/bin/sh
curl -s "http://localhost:3000/download?id=$1&filename=$2&url=$3" >/dev/null 2&>1 &
sleep 1
r=`curl -s "http://localhost:3000/progress?id=$1"|grep received`
while [ "$r" != "" ]; do
    echo $r
    sleep 1
    r=`curl -s "http://localhost:3000/progress?id=$1"|grep received`
done
