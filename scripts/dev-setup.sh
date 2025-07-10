#!/bin/bash

# Imagasaur Development Setup Script
# This script sets up the development environment

set -e

echo "🔧 Setting up Imagasaur development environment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_requirements() {
    print_status "Checking requirements..."

    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed. Please install it first."
        exit 1
    fi

    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install it first."
        exit 1
    fi

    if ! command -v npm &> /dev/null; then
        print_error "npm is not installed. Please install it first."
        exit 1
    fi

    print_status "All requirements are satisfied."
}

# Setup backend
setup_backend() {
    print_status "Setting up backend..."
    cd backend

    # Create virtual environment
    if [ ! -d "venv" ]; then
        print_status "Creating Python virtual environment..."
        python3 -m venv venv
    fi

    # Activate virtual environment
    source venv/bin/activate

    # Install dependencies
    print_status "Installing Python dependencies..."
    pip install -r requirements.txt

    cd ..
    print_status "Backend setup complete."
}

# Setup frontend
setup_frontend() {
    print_status "Setting up frontend..."
    cd frontend

    # Install dependencies
    print_status "Installing Node.js dependencies..."
    npm install

    cd ..
    print_status "Frontend setup complete."
}

# Create environment files
create_env_files() {
    print_status "Creating environment files..."

    # Backend environment
    if [ ! -f "backend/.env" ]; then
        cat > backend/.env << EOF
FLASK_ENV=development
FLASK_DEBUG=1
UPLOAD_BUCKET=imagasaur-uploads-local
PROCESSED_BUCKET=imagasaur-processed-local
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_DEFAULT_REGION=us-east-1
EOF
        print_warning "Created backend/.env - Please update with your AWS credentials"
    fi

    # Frontend environment
    if [ ! -f "frontend/.env" ]; then
        cat > frontend/.env << EOF
REACT_APP_API_URL=http://localhost:5000
EOF
        print_status "Created frontend/.env"
    fi
}

# Main setup
main() {
    check_requirements
    setup_backend
    setup_frontend
    create_env_files

    print_status "🎉 Development environment setup complete!"
    print_status "Next steps:"
    echo "1. Update backend/.env with your AWS credentials"
    echo "2. Start the backend: cd backend && source venv/bin/activate && python app.py"
    echo "3. Start the frontend: cd frontend && npm start"
    echo "4. Or use Docker: docker-compose up"
}

main
