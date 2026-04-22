# =========================================================
# Stage 1: PHP base with required extensions
# =========================================================
FROM php:8.4-fpm-alpine AS php_base

WORKDIR /app

RUN apk add --no-cache \
    bash \
    curl \
    git \
    unzip \
    zip \
    icu-dev \
    oniguruma-dev \
    libzip-dev \
    postgresql-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libwebp-dev \
    imagemagick \
    imagemagick-dev \
    linux-headers \
    fcgi \
    shadow \
    $PHPIZE_DEPS \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) \
        bcmath \
        exif \
        gd \
        intl \
        opcache \
        pcntl \
        pdo \
        pdo_mysql \
        pdo_pgsql \
        pgsql \
        zip \
    && pecl install redis imagick \
    && docker-php-ext-enable redis imagick \
    && rm -rf /tmp/pear /var/cache/apk/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer


# =========================================================
# Stage 2: Install PHP vendors in correct PHP environment
# =========================================================
FROM php_base AS vendor

WORKDIR /app

COPY composer.json composer.lock ./
RUN composer install \
    --no-dev \
    --no-interaction \
    --no-progress \
    --prefer-dist \
    --no-scripts

COPY . .

RUN composer dump-autoload --optimize --no-dev
RUN php artisan package:discover --ansi || true


# =========================================================
# Stage 3: Build frontend with Bun, after vendor is ready
# =========================================================
FROM oven/bun:1-alpine AS frontend

WORKDIR /app

COPY package.json bun.lock* ./
RUN if [ -f bun.lock ]; then bun install --frozen-lockfile; else bun install; fi

COPY . .
COPY --from=vendor /app/vendor /app/vendor

RUN bun run build


# =========================================================
# Stage 4: Production runtime
# =========================================================
FROM php:8.4-fpm-alpine

WORKDIR /var/www/html

RUN apk add --no-cache \
    nginx \
    supervisor \
    bash \
    curl \
    git \
    unzip \
    zip \
    icu-dev \
    oniguruma-dev \
    libzip-dev \
    postgresql-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libwebp-dev \
    imagemagick \
    imagemagick-dev \
    linux-headers \
    fcgi \
    shadow \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) \
        bcmath \
        exif \
        gd \
        intl \
        opcache \
        pcntl \
        pdo \
        pdo_mysql \
        pdo_pgsql \
        pgsql \
        zip \
    && pecl install redis imagick \
    && docker-php-ext-enable redis imagick \
    && rm -rf /tmp/pear /var/cache/apk/*

RUN { \
    echo "memory_limit=512M"; \
    echo "upload_max_filesize=64M"; \
    echo "post_max_size=64M"; \
    echo "max_execution_time=120"; \
    echo "max_input_vars=3000"; \
    echo "expose_php=0"; \
    echo "opcache.enable=1"; \
    echo "opcache.enable_cli=1"; \
    echo "opcache.memory_consumption=256"; \
    echo "opcache.interned_strings_buffer=16"; \
    echo "opcache.max_accelerated_files=20000"; \
    echo "opcache.validate_timestamps=0"; \
    echo "realpath_cache_size=4096K"; \
    echo "realpath_cache_ttl=600"; \
} > /usr/local/etc/php/conf.d/99-app.ini

COPY . /var/www/html
COPY --from=vendor /app/vendor /var/www/html/vendor
COPY --from=frontend /app/public/build /var/www/html/public/build

COPY .docker/nginx.conf /etc/nginx/http.d/default.conf
COPY .docker/supervisord.conf /etc/supervisord.conf
COPY .docker/php-fpm-www.conf /usr/local/etc/php-fpm.d/www.conf
COPY .docker/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh \
    && mkdir -p \
        /run/nginx \
        /var/log/supervisor \
        /var/lib/nginx/tmp/client_body \
        /var/www/html/storage/logs \
        /var/www/html/storage/framework/cache \
        /var/www/html/storage/framework/sessions \
        /var/www/html/storage/framework/views \
        /var/www/html/bootstrap/cache \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
