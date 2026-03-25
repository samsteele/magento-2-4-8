FROM php:8.4-fpm-alpine

# Install system dependencies
RUN apk add --no-cache \
    nginx bash git curl unzip \
    libzip-dev icu-dev icu-libs \
    freetype-dev libjpeg-turbo-dev libpng-dev \
    libxml2-dev oniguruma-dev \
    libxslt-dev \
    linux-headers \
    mysql-client \
    openssh-client shadow \
    autoconf g++ make

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install \
    pdo_mysql bcmath gd intl mbstring soap xsl zip opcache sockets ftp

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copy composer files first (better layer caching)
COPY composer.json composer.lock ./

# auth.json will be injected as a build secret
RUN --mount=type=secret,id=composer_auth,dst=/var/www/html/auth.json \
    export COMPOSER_AUTH="$(cat /var/www/html/auth.json)" \
    && composer install --no-dev --optimize-autoloader --no-interaction

## Copy app code and other relevant files
COPY app/ app/

# Enable modules, compile DI and dump autoload
RUN php -d memory_limit=-1 bin/magento setup:di:compile \
 && composer dump-autoload --optimize --no-dev

# Copy remaining files
COPY . .

# Deploy static content
RUN php -d memory_limit=-1 bin/magento setup:static-content:deploy -f en_GB en_US \
    --area frontend \
    --area adminhtml

RUN chown -R www-data:www-data /var/www/html

EXPOSE 9000
CMD ["php-fpm"]
