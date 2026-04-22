#!/bin/sh
set -e

cd /var/www/html

mkdir -p storage/framework/cache
mkdir -p storage/framework/sessions
mkdir -p storage/framework/views
mkdir -p storage/logs
mkdir -p bootstrap/cache

chown -R www-data:www-data storage bootstrap/cache || true
chmod -R 775 storage bootstrap/cache || true

if [ -f artisan ]; then
  php artisan config:clear || true
  php artisan route:clear || true
  php artisan view:clear || true

  php artisan config:cache || true
  php artisan route:cache || true
  php artisan view:cache || true
  php artisan event:cache || true
fi

exec /usr/bin/supervisord -c /etc/supervisord.conf
