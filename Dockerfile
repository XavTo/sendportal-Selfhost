FROM dunglas/frankenphp:php8.2-bookworm

# PHP extensions (PostgreSQL + Redis + utilitaires)
RUN install-php-extensions pcntl bcmath pdo_pgsql pgsql zip redis

# Utilitaires (unzip) + Supervisor (PAS de cron)
RUN apt-get update && apt-get install -y \
      libzip-dev unzip supervisor \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

# Caddy/FrankenPHP lira ce fichier
COPY Caddyfile /etc/frankenphp/Caddyfile

# Composer (CLI)
RUN curl -sS https://getcomposer.org/installer \
  | php -- --install-dir=/usr/local/bin --filename=composer

# (facultatif si déjà dans composer.json) Postmark + Horizon
RUN composer require symfony/postmark-mailer symfony/http-client \
      --no-interaction --no-scripts --prefer-dist || true
RUN composer require laravel/horizon --no-interaction --no-scripts --prefer-dist || true

# Dépendances applicatives (prod)
RUN composer install --no-interaction --no-dev --prefer-dist --optimize-autoloader

# Publier Horizon (assets pour /horizon)
RUN php /app/artisan horizon:publish || true

# Permissions Laravel usuelles
RUN chown -R www-data:www-data storage bootstrap/cache \
 && chmod -R ug+rwx storage bootstrap/cache

# Supervisor : lance web + horizon + scheduler
COPY supervisord.conf /etc/supervisor/supervisord.conf

# Entrypoint : prépare l’app puis démarre Supervisor
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
