#!/bin/sh
#
# Prepare vilblio-server
#
perl Makefile.PL
make manifest
make dist

# The node servers
#
tar --exclude node_modules -zcf node.tar.gz node

# On the other side ...
#
# perl Makefile.PL
# PERL_MM_USE_DEFAULT=1 make installdeps_notest
# -- database migration steps!!
#
# tar zxf node.tar.gz
# for server in `ls node`; do
#   (cd $server; npm install)
# done
#
