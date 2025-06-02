#!/bin/bash

# ------------------------------------------------------------------------------
# Script: Cognito Activity Log Downloader & Formatter
# Description: Downloads logs from an AWS S3 bucket, deduplicates, processes, 
#              and formats them for further analysis.
#
# Author: Raj Vira (https://in.linkedin.com/in/rajvira)
# Hosted by: Infopercept Consulting
# License: MIT License
#
# Copyright (c) 2025 Raj Vira / Infopercept
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
# ------------------------------------------------------------------------------

# Variables
BUCKET_NAME="<Cognito_S3_BUCKET_NAME>"
LOCAL_DIR="/var/ossec/logs/cognito"
DATA_FILE="/var/ossec/logs/cognito.data"
LOG_FILE="/var/ossec/logs/cognito/cognito.log"
FORMATTED_LOG_FILE="/var/ossec/logs/cognito.json"

# Ensure the data file and log file exist
touch "$DATA_FILE"
touch "$LOG_FILE"
touch "$FORMATTED_LOG_FILE"

# Load the list of already downloaded files into an array
declare -A DOWNLOADED_FILES
while IFS= read -r FILE; do
    DOWNLOADED_FILES["$FILE"]=1
done < "$DATA_FILE"

# Clear the cognito directory
echo "Clearing the $LOCAL_DIR directory..."
rm -rf "$LOCAL_DIR"/*
mkdir -p "$LOCAL_DIR"

# List all objects in the S3 bucket and process them
echo "Listing files in S3 bucket..."
aws s3 ls "s3://$BUCKET_NAME/" --recursive | awk '{print $4}' | while read -r FILE; do
    LOCAL_FILE_PATH="$LOCAL_DIR/$(basename "$FILE")"

    # Check if file already exists in the data file
    if [[ -n "${DOWNLOADED_FILES["$FILE"]}" ]]; then
        echo "File $FILE already downloaded, skipping."
    else
        echo "Downloading $FILE to $LOCAL_FILE_PATH..."
        aws s3 cp "s3://$BUCKET_NAME/$FILE" "$LOCAL_FILE_PATH"
        if [ $? -eq 0 ]; then
            echo "$FILE" >> "$DATA_FILE"
            # Add a newline before appending log file content
            echo "" >> "$LOG_FILE"
            cat "$LOCAL_FILE_PATH" >> "$LOG_FILE"

            # Extract and format JSON data with aws. prefixes
            jq -c '. | {"aws.cognito.request_id": .request_id, "aws.cognito.ip_address": .ip_address, "aws.cognito.message": .message}' "$LOCAL_FILE_PATH" >> "$FORMATTED_LOG_FILE"
        else
            echo "Failed to download $FILE."
        fi
    fi
done

# Change ownership of the log file
chown wazuh:root "$LOG_FILE"
chown wazuh:root "$FORMATTED_LOG_FILE"

echo "Download and processing complete."
