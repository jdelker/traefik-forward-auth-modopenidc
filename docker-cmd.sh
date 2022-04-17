#!/bin/sh

envsubst \
    < /conf/httpd-openidc.conf \
    > /tmp/httpd-openidc.conf

httpd-foreground
