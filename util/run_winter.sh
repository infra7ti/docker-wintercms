#!/bin/sh

php \
  ${WINTER_HOME}/artisan serve \
    --host 0.0.0.0 \
    --port 8008 \
  || exit 1

exit 0
