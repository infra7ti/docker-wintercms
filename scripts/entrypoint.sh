#!/bin/bash

set -eu -o pipefail
exec 3>&1

case ${1} in
  bash|sh) exec "${*}" ;;
esac

export WINTER_HOME=/srv/www/winter

: ${WINTER_UID:=1000}
: ${WINTER_GID:=1000}
: ${WINTER_ADMIN_PASSWD:=admin}
: ${WINTER_ADMIN_PASSWD_FILE:=null}
: ${WINTER_AUTOUPDATE:=false}
: ${WINTER_CLEAR_SESSIONS:=false}
: ${WINTER_PROJECT:=winter}
: ${WINTER_AUTOINSTALL_PLUGINS:='Winter.Pages Winter.Translate'}
: ${WINTER_AUTOINSTALL_THEME:='Castus.Ui3kit ui3kit'}

if test -f "${WINTER_ADMIN_PASSWD_FILE}"; then
  WINTER_ADMIN_PASSWD=$(< ${WINTER_ADMIN_PASSWD_FILE})
fi

WINTER_CLEAR_SESSIONS=$(
  echo ${WINTER_CLEAR_SESSIONS} | awk '{print tolower($0)}'
)

echo "Configuring WinterCMS..."

cd ${WINTER_HOME} || exit -1
rm -f ${PWD}/.env

# create winter user and group
groupadd -r \
  -g ${WINTER_GID} \
    winter || :

useradd -r \
  -u ${WINTER_UID} \
  -g ${WINTER_GID} \
  -M -d ${PWD} \
    winter || :

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
  for p in ${WINTER_AUTOINSTALL_PLUGINS}; do
    php ${PWD}/artisan -n plugin:install ${p}
  done
  php ${PWD}/artisan -n theme:install ${WINTER_AUTOINSTALL_THEME}
  php ${PWD}/artisan -n theme:use ${WINTER_AUTOINSTALL_THEME/*\ }
else # Upgrade
  test -f ${PWD}/storage/winter.env \
    && cp -f ${PWD}/storage/winter.env ${PWD}/.env \
    || php ${PWD}/artisan -n winter:env
  test "${WINTER_AUTOUPDATE}" == "true" \
    && composer upgrade \
    && php ${PWD}/artisan -n winter:update
fi

# set permissions
find . -not -user winter -or -not -group winter | while read p; do 
  echo "Fixing ownership on: ${p}"
  chown winter:winter "${p}";
done
find ${PWD} -type d -exec chmod -R 0770 {} \+
find ${PWD} -type f -exec chmod -R 0660 {} \+

# Brings winter up
php ${PWD}/artisan -n winter:up

# Clear cache and sessions
php ${PWD}/artisan -n cache:clear
test "${WINTER_CLEAR_SESSIONS}" == "true" \
  && find ${PWD}/storage/framework/sessions -type f -delete

# Reset admin password
php ${PWD}/artisan -n winter:passwd admin ${WINTER_ADMIN_PASSWD}
# Set theme
php ${PWD}/artisan -n theme:use ${WINTER_THEME:-ui3kit}
# Backup configuration
cp -f ${PWD}/.env ${PWD}/storage/winter.env

echo "WinterCMS configured successfully."

if [ $(id -u) -eq 0 ]; then
  exec runuser -u winter -g winter -- "${*}"
else
  echo "Error: Invalid user UID: $(id -u)."
fi
