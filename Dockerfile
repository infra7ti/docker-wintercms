FROM php:8.1-fpm-bookworm AS build

# -- Install security updates and build dependencies --------------------------
RUN grep security /etc/apt/sources.list \
    | egrep -v '#' \
    | tee /tmp/security.sources.list \
  && apt-get update \
  && apt-get -y upgrade -o Dir::Etc::SourceList=/tmp/security.sources.list \
  && apt-get update \
  && apt-get -y install \
    --no-install-recommends \
    --no-install-suggests \
      git-core \
      libfreetype6 \
      libfreetype6-dev \
      libjpeg62-turbo \
      libjpeg62-turbo-dev \
      libpng16-16 \
      libpng-dev \
      libzip4 \
      libzip-dev \
      unzip \
  && apt-get clean \
  && rm -f /var/lib/apt/list/*

# -- Install PHP required extensions and composer -----------------------------
COPY --chmod=0755 scripts/install-compose.sh /tmp/
RUN echo \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-configure zip \
  && docker-php-ext-install -j$(nproc) gd \
  && docker-php-ext-install -j$(nproc) zip \
  && docker-php-source delete \
  && /tmp/install-compose.sh \
  && mv composer.phar /usr/local/bin/composer \
  && apt -y purge --autoremove \
      build-essential gcc git *-dev

# -- Install scripts and create WinterCMS project -----------------------------
COPY --chmod=0755 scripts/entrypoint.sh /usr/local/bin/
COPY --chmod=0755 scripts/run_winter.sh /usr/local/bin/
COPY winter/patches/ /tmp/patches/
WORKDIR /srv/www
RUN echo \
  && composer \
    create-project wintercms/winter winter \
  && for p in /tmp/patches/*.patch; do \
    echo patch -p1 < ${p}; \
  done \
  && chown -R 1000:1000 ${PWD}/winter \
  && chmod -R 0770 ${PWD}/winter \
  && find ${PWD}/winter/storage/ -type f -delete \
  && rm -rf \
    /var/tmp/* /tmp/*

# -- System cleanup -----------------------------------------------------------
FROM scratch
COPY --from=build / /

WORKDIR /srv/www/winter

ENTRYPOINT ["entrypoint.sh"]
CMD ["run_winter.sh"]
