#!/bin/sh
env CATALYST_DEBUG=1 \
  ./script/va_fastcgi.pl --keeperr -n 1 -l localhost:30001
