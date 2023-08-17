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
  && apt-get clean \
  && rm -f /var/lib/apt/list/*

# -- Install PHP required extensions and composer -----------------------------
COPY --chmod=0755 util/install-compose /tmp/
RUN echo \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-configure zip \
  && docker-php-ext-install -j$(nproc) gd \
  && docker-php-ext-install -j$(nproc) zip \
  && docker-php-source delete \
  && /tmp/install-compose \
  && mv composer.phar /usr/local/bin/composer \
  && apt -y purge --autoremove \
      build-essential gcc git *-dev

# -- Install scripts and create WinterCMS project -----------------------------
COPY --chmod=0755 util/entrypoint.sh /usr/local/bin/
COPY --chmod=0755 util/run_winter.sh /usr/local/bin/
COPY winter/patches/ /tmp/patches/
ARG WINTER_PREFIX
WORKDIR ${WINTER_PREFIX}
ARG WINTER_PROJECT
RUN echo \
  && composer \
    create-project wintercms/winter ${WINTER_PROJECT} \
  && for p in /tmp/patches/*.patch; do \
    echo patch -p1 < ${p}; \
  done \
  && useradd \
    -u 1000 -g 33 \
    -M -d ${PWD}/${WINTER_PROJECT} \
    winter \
  && chown -R 1000:33 ${PWD}/${WINTER_PROJECT} \
  && chmod -R 0770 ${PWD}/${WINTER_PROJECT} \
  && find ${PWD}/${WINTER_PROJECT}/storage/ -type f -delete \
  && rm -rf \
    /var/tmp/* /tmp/*

# -- System cleanup -----------------------------------------------------------
FROM scratch
COPY --from=build / /

USER 1000:33

ARG WINTER_PREFIX
ARG WINTER_PROJECT
ENV WINTER_HOME=${WINTER_PREFIX}/${WINTER_PROJECT}
WORKDIR ${WINTER_HOME}

ENTRYPOINT ["entrypoint.sh"]
CMD ["run_winter.sh"]
