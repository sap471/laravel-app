FROM php:8.4-cli AS builder

ENV APP_PORT=9000

# install dependencies
RUN apt-get update && apt-get install -y \
    git unzip curl libpng-dev libonig-dev libxml2-dev \
    libzip-dev libpq-dev libcurl4-openssl-dev libssl-dev \
    zlib1g-dev libicu-dev g++ libevent-dev procps

# php-extensions
RUN docker-php-ext-install pdo pdo_mysql pdo_pgsql mbstring zip exif pcntl bcmath sockets intl

# php-redis
RUN set -ex \
    && pecl channel-update pecl.php.net \
    && yes no | pecl install redis-stable \
    && docker-php-ext-enable redis

# php-swoole
RUN pecl install swoole \
    && docker-php-ext-enable swoole

# composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/
RUN composer --version

# bun
COPY --from=oven/bun:1.3 /usr/local/bin/bun /usr/local/bin/bun
RUN bun --version

# cleanup
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /var/www

FROM builder AS production

COPY composer.json composer.lock artisan ./

RUN mkdir -p bootstrap/cache storage/app storage/framework/cache/data \
    storage/framework/sessions storage/framework/views storage/logs

RUN composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist --no-scripts

COPY package.json bun.lock ./
RUN bun install --frozen-lockfile --no-cache

COPY . .

RUN composer dump-autoload --optimize

# build & clear cache
RUN bun run build \
    && bun install --production

EXPOSE 9000

VOLUME /var/www/storage

ENTRYPOINT ['/bin/bash']

CMD ['/var/www/startup-script']