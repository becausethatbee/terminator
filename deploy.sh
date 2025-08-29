#!/bin/bash
# Terminator Deploy Script

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    local deps=("git" "mkdocs" "python3")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "$dep is not installed"
            exit 1
        fi
    done
    log_success "All dependencies are installed"
}

# Build the site
build_site() {
    log_info "Building the site..."
    if mkdocs build --clean; then
        log_success "Site built successfully"
    else
        log_error "Failed to build site"
        exit 1
    fi
}

# Serve locally
serve_site() {
    log_info "Starting local server..."
    mkdocs serve &
    local PID=$!
    log_success "Server started with PID $PID"
    log_info "Access the site at: http://127.0.0.1:8000"
    log_info "Press Ctrl+C to stop the server"
    wait $PID
}

# Deploy to GitHub Pages
deploy_site() {
    log_info "Deploying to GitHub Pages..."
    if mkdocs gh-deploy --force; then
        log_success "Site deployed successfully"
    else
        log_error "Failed to deploy site"
        exit 1
    fi
}

# Initialize git repository
init_git() {
    log_info "Initializing git repository..."
    if [ ! -d ".git" ]; then
        git init
        git add .
        git commit -m "Initial commit: Terminator documentation site"
        log_success "Git repository initialized"
    else
        log_warning "Git repository already exists"
    fi
}

# Main function
main() {
    case "$1" in
        "build")
            check_dependencies
            build_site
            ;;
        "serve")
            check_dependencies
            build_site
            serve_site
            ;;
        "deploy")
            check_dependencies
            build_site
            deploy_site
            ;;
        "init")
            check_dependencies
            init_git
            ;;
        "full")
            check_dependencies
            init_git
            build_site
            deploy_site
            ;;
        *)
            echo "Usage: $0 {build|serve|deploy|init|full}"
            echo "  build   - Build the site only"
            echo "  serve   - Build and serve locally"
            echo "  deploy  - Build and deploy to GitHub Pages"
            echo "  init    - Initialize git repository"
            echo "  full    - Initialize, build and deploy"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
