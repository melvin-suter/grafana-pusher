FROM php:7.2-apache

COPY src/ /var/www/html/

RUN docker-php-ext-install pdo pdo_mysql

# Use the default production configuration
#RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"