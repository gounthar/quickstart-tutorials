#!/bin/bash

# This script is used to start a specific service in a Docker Compose setup.
# The service to start is determined by the argument provided when running the script.
# The argument also sets the value of the PROFILE environment variable for the service.

# Check if an argument was provided
# If no argument is provided, the script will print a usage message and exit.
if [ $# -eq 0 ]; then
    echo "No profile provided. Usage: ./start-jenkins.sh <profile>"
    exit 1
fi

# Set the PROFILE environment variable to the value of the first argument.
PROFILE=$1

# Run the Docker Compose command to start the service.
# The service to start is determined by the value of the PROFILE environment variable.
# The PROFILE environment variable is also passed to the service as an environment variable.
PROFILE=$PROFILE docker-compose up -d $PROFILE
