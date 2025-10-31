# Use a lightweight Python base image
FROM python:3.12-slim

# Set working directory
WORKDIR /app

# Copy requirements first to leverage Docker cache
COPY requirements.txt .

# Install Python dependencies
# Using --trusted-host to handle SSL issues in some environments
RUN pip install --no-cache-dir --trusted-host pypi.org --trusted-host files.pythonhosted.org -r requirements.txt

# Copy application files
COPY bot.py .
COPY default.config.yaml .
COPY default.secrets.yaml .

# Create directory for media files
RUN mkdir -p /app/media

# Set the entry point to execute the bot script
ENTRYPOINT ["python", "bot.py"]
