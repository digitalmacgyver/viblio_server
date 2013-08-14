#!/bin/sh
#
# start/stop/restart the node servers
#
# usage: start-stop-node [server] start|stop|restart
#
# If no server arg, then do them all
#
servers='mq'
if [ "$1" -a "$2" ]; then
    cmd="./node/$1/$1-dev.init.d $2"
    echo $cmd
    $cmd
else
    for server in $servers; do
	cmd="./node/$server/$server-dev.init.d $1"
	echo $cmd
	$cmd
    done
fi
