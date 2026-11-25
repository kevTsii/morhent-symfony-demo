FROM dunglas/frankenphp:1-php8.4

RUN install-php-extensions \
    pdo_pgsql \
    intl \
    zip \
    opcache \
    apcu \
    amqp

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

ENV SERVER_NAME=":80"

WORKDIR /app
