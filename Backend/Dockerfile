FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN useradd --uid 10001 --create-home trivia && mkdir -p /app/private_media /app/staticfiles && chown -R trivia:trivia /app
USER trivia
EXPOSE 10000
CMD ["sh", "-c", "exec daphne -b 0.0.0.0 -p ${PORT:-10000} rideflow.asgi:application"]
