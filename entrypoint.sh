#!/bin/sh
set -e

# Publish Horizon assets once; safe to repeat
php artisan horizon:publish --force || true

# “Safe” caches
php artisan config:clear || true
php artisan view:clear   || true
php artisan config:cache || true
php artisan view:cache   || true

# Publish SendPortal assets (produces public/vendor/sendportal/* + mix-manifest)
php artisan vendor:publish --provider="Sendportal\\Base\\SendportalBaseServiceProvider" --force
echo "---- MIX MANIFEST ----"
php -r 'echo @file_get_contents("public/vendor/sendportal/mix-manifest.json") ?: "absent\n";'

# DB migrations
php artisan migrate --force

# Quick Redis ping (optional)
php -r '
$h=getenv("REDIS_HOST")?: "127.0.0.1";
$p=(int)(getenv("REDIS_PORT")?:6379);
$pw=getenv("REDIS_PASSWORD");
$r=new Redis();
$r->connect($h,$p,2.0);
if ($pw) { $r->auth($pw); }
echo "Redis PING: ".$r->ping().PHP_EOL;
' || true

# Hand over to Supervisor (starts FrankenPHP, Horizon, and the scheduler)
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf