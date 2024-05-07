#!/bin/sh

php \
  ${WINTER_HOME}/artisan serve \
    --host ${HOSTNAME} \
    --port ${WINTER_PORT} \
  || exit 1

exit 0
