#!/bin/sh
export MOJO_MODE=development
export MOJO_LOG_LEVEL=debug
exec `dirname $0`/log-trawly.pl prefork --listen 'http://*:4557'
