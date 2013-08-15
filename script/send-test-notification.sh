#!/bin/sh
./script/wsclient.pl --port 80 --expect application/json --dump-response --quiet --service services/na/mediafile_create -- site-token=maryhadalittlelamb uid=86FD9216-A8B9-11E2-9637-3B9C97344F04 mid=c1dda17d-81e9-4559-a97b-8c82e77ca922
