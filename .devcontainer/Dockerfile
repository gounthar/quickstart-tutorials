FROM python:3.8-slim

# Install necessary packages
RUN apt-get update && apt-get install -y \
    git \
    curl \
    vim

# Install your application's dependencies
RUN pip install --no-cache-dir yq

# Set the working directory
WORKDIR /workspace