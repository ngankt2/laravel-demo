FROM php:8.4-fpm

# Cài đặt dependencies
RUN apt-get update && apt-get install -y \
    nginx \
    supervisor \
    libpng-dev \
    libjpeg-dev \
    zip \
    unzip \
    libfreetype6-dev \
    libpq-dev \
    libonig-dev \
    libssl-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    libicu-dev \
    libzip-dev \
    libmagickwand-dev \
    curl \
    jq \
    git \
    libwebp-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install gd pdo pdo_mysql pdo_pgsql pgsql opcache intl bcmath pcntl zip exif \
    && pecl install redis \
    && pecl install imagick \
    && docker-php-ext-enable redis imagick \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Cài Bun
RUN curl -fsSL https://bun.sh/install | bash \
    && mv /root/.bun/bin/bun /usr/local/bin/bun

# Copy Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Tạo thư mục ứng dụng
WORKDIR /var/www

# Copy mã nguồn Laravel
COPY . /var/www

# Cài đặt Composer dependencies (keep composer.lock for consistency)
RUN composer install --prefer-dist --no-dev --optimize-autoloader --no-interaction \
    && php artisan storage:link || true \
    && php artisan config:clear || true \
    && php artisan cache:clear || true

RUN chown -R www-data:www-data /var/www \
    && chmod -R 775 /var/www/storage /var/www/bootstrap/cache

# Cài đặt dependencies và build frontend với Bun
RUN bun install && bun run build

# Copy cấu hình Nginx
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/default.conf /etc/nginx/sites-enabled/default

# Cấu hình PHP-FPM
COPY docker/php-fpm.conf /usr/local/etc/php-fpm.d/zz-laravel.conf

# Copy php.ini cấu hình upload
COPY docker/php.ini /usr/local/etc/php/conf.d/uploads.ini

# Copy cấu hình supervisord để chạy cả nginx và php-fpm
COPY docker/supervisord.conf /etc/supervisord.conf

EXPOSE 8080

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
