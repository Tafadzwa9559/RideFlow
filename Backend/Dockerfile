FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends build-essential pkg-config default-libmysqlclient-dev && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN useradd --uid 10001 --create-home trivia && mkdir -p /app/private_media /app/staticfiles && chown -R trivia:trivia /app
USER trivia
EXPOSE 8000
CMD ["daphne", "-b", "0.0.0.0", "-p", "8000", "rideflow.asgi:application"]
