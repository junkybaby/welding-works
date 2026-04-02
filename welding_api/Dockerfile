FROM php:8.2-cli

# Install MySQL PDO driver for the API database connection.
RUN docker-php-ext-install pdo_mysql

WORKDIR /app
COPY . /app

EXPOSE 8080

CMD ["sh", "-c", "php -S 0.0.0.0:${PORT:-8080} -t ."]
