FROM python:3.12

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Installiere Supervisor
RUN apt-get update && apt-get install -y \
    build-essential \
    libsystemd-dev \
    curl \
    ffmpeg

# Set working directory
WORKDIR /app

# Copy only requirements first (for caching purposes)
COPY requirements.txt ./

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY . ./

# Create directories
RUN mkdir -p /app/logs && mkdir -p /app/records

EXPOSE 9001

RUN source /app/.env

CMD ["/bin/bash", "-c", "echo 'hello world!'"]
