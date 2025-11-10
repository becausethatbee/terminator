# Terminator Documentation

Technical knowledge base and documentation built with MkDocs Material theme.

## Overview

Terminator (*notes) is a comprehensive technical documentation site covering various DevOps and infrastructure topics including Linux, Docker, Kubernetes, Ansible, Terraform, Monitoring, and Databases.

## Features

- **Material Theme**: Modern and responsive design with dark/light mode toggle
- **Search**: Built-in search functionality with highlighting
- **Code Blocks**: Syntax highlighting with copy button
- **Navigation**: Organized with tabs and sections
- **Responsive**: Mobile-friendly layout

## Documentation Topics

- **Linux**: System administration, bash scripting, networking, firewall
- **Docker**: Container management, networking, security, Docker Compose
- **Kubernetes**: Workloads, QoS resources, networking, storage configuration
- **Ansible**: Setup, configuration, playbooks, vault, galaxy
- **Terraform**: Syntax, labs, CI/CD integration
- **Monitoring**: Prometheus, Loki, Grafana, alerting
- **Databases**: PostgreSQL HA with Patroni and etcd

## Prerequisites

- Python 3.x
- pip
- git

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd terminator
```

2. Install dependencies:
```bash
pip install mkdocs mkdocs-material
```

## Usage

### Local Development

Build and serve the documentation locally:

```bash
./deploy.sh serve
```

Access at: http://127.0.0.1:8000

### Build Only

Build the static site:

```bash
./deploy.sh build
```

### Deploy to GitHub Pages

Deploy the documentation:

```bash
./deploy.sh deploy
```

## Scripts

### deploy.sh

Main deployment script with multiple commands:

- `build` - Build the site only
- `serve` - Build and serve locally
- `deploy` - Build and deploy to GitHub Pages
- `init` - Initialize git repository
- `full` - Initialize, build and deploy

### add.py

Helper script for adding new documentation pages.

### new.sh

Script for creating new documentation sections.

### push.sh

Quick commit and push script.

## Project Structure

```
terminator/
├── docs/               # Documentation source files
│   ├── ansible/       # Ansible documentation
│   ├── Docker/        # Docker documentation
│   ├── kubernetes/    # Kubernetes documentation
│   ├── linux/         # Linux documentation
│   ├── terraform/     # Terraform documentation
│   ├── monitoring/    # Monitoring stack documentation
│   ├── databases/     # Database documentation
│   ├── assets/        # Static assets (CSS, JS, images)
│   └── index.md       # Homepage
├── mkdocs.yml         # MkDocs configuration
├── deploy.sh          # Deployment script
├── add.py             # Add new page helper
├── new.sh             # New section helper
└── push.sh            # Quick push script
```

## Configuration

The site is configured via `mkdocs.yml`:

- **Theme**: Material with custom color scheme (slate/default with amber primary)
- **Plugins**: Search
- **Extensions**: Admonition, code highlighting, superfences
- **Navigation**: Tab-based with sticky navigation

## Contributing

1. Create a new branch for your changes
2. Add or update documentation in the `docs/` directory
3. Update `mkdocs.yml` if adding new sections
4. Test locally with `./deploy.sh serve`
5. Commit and push your changes
6. Create a pull request

## Adding New Documentation

### Add a new page to existing section:

```bash
./add.py
```

### Create a new section:

```bash
./new.sh
```

Then update `mkdocs.yml` navigation accordingly.

## License

This documentation is maintained for personal/team use.

## Author

becausethatbee
