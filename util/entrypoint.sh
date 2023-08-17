#!/bin/sh

set -eu
exec 3>&1

case ${1} in
  bash|sh) exec "${*}" ;;
esac

: ${WINTER_ADMIN_PASSWD:=admin}
: ${WINTER_ADMIN_PASSWD_FILE:=null}
: ${WINTER_CLEAR_SESSIONS:=false}
: ${WINTER_HOME:=/srv/www/winter}

if test -f "${WINTER_ADMIN_PASSWD_FILE}"; then
  WINTER_ADMIN_PASSWD=$(< ${WINTER_ADMIN_PASSWD_FILE})
fi

WINTER_CLEAR_SESSIONS=$(
  echo ${WINTER_CLEAR_SESSIONS} | awk '{print tolower($0)}'
)

echo "Configuring WinterCMS..."

cd ${WINTER_HOME} || exit -1
rm -f ${PWD}/.env

if ! test -f "${PWD}/storage/database.sqlite"; then # Fresh install
  mkdir -p \
    ${PWD}/storage/app \
    ${PWD}/storage/cms/combiner \
    ${PWD}/storage/framework/sessions \
    ${PWD}/storage/logs \
    ${PWD}/storage/temp
  touch ${PWD}/storage/database.sqlite
  php ${PWD}/artisan -n winter:install
  php ${PWD}/artisan -n winter:env
  php ${PWD}/artisan -n theme:install Castus.Ui3kit ui3kit
  php ${PWD}/artisan -n theme:use ui3kit
else # Upgrade
  test -f ${PWD}/storage/winter.env \
    && cp -f ${PWD}/storage/winter.env ${PWD}/.env \
    || php ${PWD}/artisan -n winter:env
    php ${PWD}/artisan -n winter:update
fi

# set permissions
chown -R 1000:33 ${PWD}/storage
chmod -R 0770 ${PWD}/storage

# Brings winter up
php ${PWD}/artisan -n winter:up

# Clear cache and sessions
php ${PWD}/artisan -n cache:clear
test [[ "${WINTER_CLEAR_SESSIONS}" == "true" ]] \
  && find ${PWD}/storage/framework/sessions -type f -delete

# Reset admin password
php ${PWD}/artisan -n winter:passwd admin ${WINTER_ADMIN_PASSWD}
# Set theme
php ${PWD}/artisan -n theme:use ${WINTER_THEME:-ui3kit}
# Backup configuration
cp -f ${PWD}/.env ${PWD}/storage/winter.env

echo "WinterCMS configured successfully."

exec "${*}"
