#!/bin/bash

# Exit on error
set -e

# Create a virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt -t ./package

# Copy the application code
cp app.py ./package/

# Create the deployment package
cd package
zip -r ../function.zip .

# Clean up
cd ..
rm -rf package venv

echo "Deployment package created: function.zip"
