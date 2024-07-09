#!/bin/bash
#set -euxo pipefail

# Variables
JENKINS_HOST="localhost"
JENKINS_URL="http://admin:admin@$JENKINS_HOST:8080"
JOB_NAME="Simple maven job"
CONFIG_XML_PATH="./Simple maven job/config.xml"

# URL encode the job name to handle spaces and remove trailing newline
ENCODED_JOB_NAME=$(echo "$JOB_NAME" | jq -sRr @uri | tr -d '\n')

# Ensure the CONFIG_XML_PATH is correctly referenced
ABSOLUTE_CONFIG_XML_PATH=$(realpath "$CONFIG_XML_PATH")

 # The following steps are used to test the Jenkins stack.
          # It includes steps to install dependencies, create a token for the admin user, launch a job, wait for the job to start running,
          # wait for the job to complete, and check the job status.
          # If the job fails, it gives the console output of why it failed and exits with a non-zero status to fail the step and stop the workflow.
          # If the job succeeds, it prints "Job succeeded".
          # The detailed steps are documented in the comments within the code block.

          # set -x
          # Installing dependencies
          # To check the version of Jenkins, load the top page or any .../api/* page and check for the X-Jenkins response header. This contains the version number of Jenkins, like "1.404" This is also a good way to check if an URL is a Jenkins URL.
          JENKINS_VERSION=$(curl -s -I -k http://admin:admin@$JENKINS_HOST:8080 | grep -i '^X-Jenkins:' | awk '{print $2}')
          echo "Jenkins version is: $JENKINS_VERSION"

          # Before launching a job, we need to create a token for the admin user
          CRUMB=$(curl -s -k http://admin:admin@$JENKINS_HOST:8080/crumbIssuer/api/xml?xpath=concat\(//crumbRequestField,%22:%22,//crumb\) -c cookies.txt)
          echo "CRUMB was found."

# Attempt to generate a new token and print the raw response for debugging
RAW_TOKEN_RESPONSE=$(curl -s -k "http://admin:admin@$JENKINS_HOST:8080/user/admin/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken" --data "newTokenName=kb-token" -b cookies.txt -H "$CRUMB")
echo "Raw token response: $RAW_TOKEN_RESPONSE"

          TOKEN=$(echo $RAW_TOKEN_RESPONSE | jq -r '.data.tokenValue')
          echo "TOKEN was found."

          # Creating the Job from the config.xml file
          curl -X POST -H "Content-Type: text/xml" --user admin:$TOKEN --data-binary @"$CONFIG_XML_PATH" http://$JENKINS_HOST:8080/createItem?name=maven #${{ matrix.dir }}
# Echo the result of the previous curl command to the log
echo "Result of the previous curl command: $?"
          # Let's set the JOB_NAME it's same as the running tutorial (i.e. maven, python, node)
          JOB_NAME="maven"
          echo "Launching a job whose unencoded name is $JOB_NAME."

          # Encode the JOB_NAME to replace spaces, open parentheses, and closing parentheses with their corresponding URL-encoded values.
          # This is necessary when using the JOB_NAME in a URL or any other context where special characters need to be encoded.
          # Spaces are replaced with "%20", open parentheses with "%28", and closing parentheses with "%29".
          # The encoded result is stored in the JOB_NAME_ENCODED variable. This step was useful with using (simple demo job)
          JOB_NAME_ENCODED=$(echo "$JOB_NAME" | awk '{ gsub(/ /, "%20"); gsub(/\(/, "%28"); gsub(/\)/, "%29"); print }')
          echo "JOB_NAME_ENCODED is $JOB_NAME_ENCODED"

          # Checking the present job, debug step, checks if the test job is present.
          JOB_PRESENT=$(curl -u admin:$TOKEN http://$JENKINS_HOST:8080/api/json?tree=jobs%5Bname%5D)
          echo "JOB_PRESENT is $JOB_PRESENT"

          # Starting the job, TOKEN has been set in the previous step
          curl -X POST -u admin:$TOKEN $JENKINS_HOST:8080/job/$JOB_NAME_ENCODED/build

          # Wait for the job to start running
          sleep 10
          echo "Waiting for the job to start running..."
          BUILD_NUMBER="null"

          # While loop checks if BUILD__NUMBER is empty or null, breaks otherwise
          while [[ -z $BUILD_NUMBER || $BUILD_NUMBER == "null" ]]; do

            # Retrieve build info from Jenkins API using cURL
            BUILD_INFO=$(curl -s -k http://admin:$TOKEN@$JENKINS_HOST:8080/job/$JOB_NAME_ENCODED/api/json)
            echo "Retrieved build info: $BUILD_INFO"

            # Extract the build number from the JSON response using jq
            BUILD_NUMBER=$(echo $BUILD_INFO | jq -r '.lastBuild.number')

            # Check if the build is in progress
            BUILD_IN_PROGRESS=$(echo $BUILD_INFO | jq -r '.lastBuild.building')
            echo "Build number: $BUILD_NUMBER"
            echo "Build in progress: $BUILD_IN_PROGRESS"

            # If the build number is not empty and the build is in progress, break out of the loop
            if [[ -n $BUILD_NUMBER && $BUILD_IN_PROGRESS == "true" ]]; then
              break
            fi

            # Sleep for 5 seconds before checking the build status again
            sleep 15  # Adjust the sleep duration as needed
          done
          echo "This is BUILD__NUMBER $BUILD_NUMBER"

          # Delay before retrieving build information
          sleep 15
          if [[ -z $BUILD_NUMBER ]]; then


          # If the build number is empty or "null", it means the job has never run
            echo "Job has never run"
          else

          # If the build number is not empty, the job has started and the build number is displayed
            echo "Job started. Build number: $BUILD_NUMBER"
          fi

            # Wait for the job to complete
            echo "Waiting for the job to complete..."

            while true; do
            # Retrieve the build status and whether the build is in progress
              BUILD_STATUS=$(curl -s -k http://admin:$TOKEN@$JENKINS_HOST:8080/job/$JOB_NAME_ENCODED/$BUILD_NUMBER/api/json | jq -r '.result')
              BUILD_IN_PROGRESS=$(curl -s -k http://admin:$TOKEN@$JENKINS_HOST:8080/job/$JOB_NAME_ENCODED/$BUILD_NUMBER/api/json | jq -r '.building')
              echo "Build status: $BUILD_STATUS"
              echo "Build in progress: $BUILD_IN_PROGRESS"
              # If the build status is not "null", it means the build has been completed
              if [[ $BUILD_STATUS != "null" ]]; then
                break
              fi

              # Below step is for the node tutorial only, in which we need to give input (click PROCEED) in order to complete the pipeline
              curl -s -k -X POST -u admin:$TOKEN http://$JENKINS_HOST:8080/job/$JOB_NAME_ENCODED/$BUILD_NUMBER/input/PROCEED/proceedEmpty

              sleep 5  # Adjust the sleep duration as needed
            done

            # Checks BUILD_STATUS to see if job succeeded or failed and if failed gives console output of why it failed and exit
            if [[ $BUILD_STATUS == "SUCCESS" ]]; then
              echo "Job succeeded"
            else
              echo "Job failed"
              echo "below is the console output"
              echo "====================="
              curl -s -k -u admin:$TOKEN http://$JENKINS_HOST:8080/job/$JOB_NAME/$BUILD_NUMBER/console
              exit 1 # Exit with a non-zero status to fail the step and stop the workflow
            fi
