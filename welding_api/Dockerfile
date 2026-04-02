FROM php:8.2-cli

# Install MySQL PDO plus Python runtime for local YOLO inference.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        python3-venv \
        libgl1 \
        libglib2.0-0 \
    && docker-php-ext-install pdo_mysql \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app

RUN python3 -m venv /opt/yolo-venv \
    && /opt/yolo-venv/bin/python -m pip install --no-cache-dir --upgrade pip \
    && /opt/yolo-venv/bin/python -m pip install --no-cache-dir -r /app/requirements.txt

ENV YOLO_PYTHON_PATH=/opt/yolo-venv/bin/python

EXPOSE 8080

CMD ["sh", "-c", "php -S 0.0.0.0:${PORT:-8080} -t ."]
