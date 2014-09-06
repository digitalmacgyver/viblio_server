#!/bin/bash

rm VA-0.01.tar.gz && \
perl Makefile.PL && \
make manifest && \
make dist && \
make package && \
make bump
