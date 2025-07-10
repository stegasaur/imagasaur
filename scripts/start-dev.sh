#!/bin/bash
set -e

# Start the backend API (local development server)
echo "Starting backend API..."
cd backend/upload_service
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Set required environment variables
export UPLOADS_BUCKET="local-uploads"
export PROCESSED_BUCKET="local-processed"
export ENVIRONMENT="development"

# Create local directories for file storage
mkdir -p ../../.local-storage/uploads
mkdir -p ../../.local-storage/processed

# Start the local server
uvicorn app:app --reload --host 0.0.0.0 --port 3000 &
BACKEND_PID=$!

# Start the frontend development server
echo "Starting frontend..."
cd ../../frontend
npm install
REACT_APP_API_URL=http://localhost:3000 npm start

# Cleanup function
cleanup() {
  echo "Shutting down..."
  kill $BACKEND_PID 2>/dev/null || true
  deactivate
  exit 0
}

# Set up trap to ensure cleanup on script exit
trap cleanup INT TERM EXIT

# Keep the script running
wait
