# Shell Logger Functions

This document provides comprehensive examples for all available shell logger functions with their expected outputs.

## Table of Contents

1. [Basic Logging Functions](#basic-logging-functions)
2. [Level Management](#level-management)
3. [Documentation Functions](#documentation-functions)
4. [Step-by-Step Instructions](#step-by-step-instructions)
5. [Command Logging](#command-logging)
6. [Indentation and Formatting](#indentation-and-formatting)
7. [Complete Examples](#complete-examples)

---

## Basic Logging Functions

### Debug, Info, Warn, Error, Fatal, Success

```bash
#!/bin/bash

# Basic logging levels
shell::logger::debug "Database query executed in 0.5ms"
shell::logger::info "Application started successfully on port 3000"
shell::logger::warn "Configuration file not found, using defaults"
shell::logger::error "Failed to connect to database server"
shell::logger::success "User authentication completed"
shell::logger::fatal "Critical system failure - shutting down"
```

**Output:**

```
DEBUG: Database query executed in 0.5ms
INFO: Application started successfully on port 3000
WARN: Configuration file not found, using defaults
ERROR: Failed to connect to database server
INFO: User authentication completed
FATAL: Critical system failure - shutting down
```

---

## Level Management

### Setting and Checking Log Levels

```bash
#!/bin/bash

# Check current level
shell::logger::info "Current level: ${SHELL_LOGGER_LEVEL:-DEBUG}"

# Test level checking
if shell::logger::can "DEBUG"; then
    shell::logger::success "DEBUG level is enabled"
else
    shell::logger::warn "DEBUG level is disabled"
fi

# Reset to DEBUG level
shell::logger::reset
shell::logger::info "Level reset to DEBUG"

# Set level interactively (shows menu)
# shell::logger::level
```

**Output:**

```
INFO: Current level: DEBUG
INFO: DEBUG level is enabled
INFO: Level reset to DEBUG
```

---

## Documentation Functions

### Usage Documentation

```bash
#!/bin/bash

# Usage header
shell::logger::usage "my-app [OPTIONS] COMMAND [ARGS...]"

# Commands/items
shell::logger::item "install" "Install the application"
shell::logger::item "update" "Update to latest version"
shell::logger::item "start" "Start the service"
shell::logger::item "stop" "Stop the service"
shell::logger::item "status" "Show service status"

# Options (automatically shows OPTIONS: label)
shell::logger::option "-h, --help" "Show this help message"
shell::logger::option "-v, --version" "Show version information"
shell::logger::option "-c, --config" "Specify configuration file"
shell::logger::option "--verbose" "Enable verbose output"
shell::logger::option "--dry-run" "Show what would be done"

# Examples
shell::logger::example "my-app install --verbose"
shell::logger::example "my-app start -c /etc/my-app.conf"
shell::logger::example "my-app status"
```

**Output:**

```
USAGE: my-app [OPTIONS] COMMAND [ARGS...]
  install
    Install the application
  update
    Update to latest version
  start
    Start the service
  stop
    Stop the service
  status
    Show service status
OPTIONS:
    -h, --help           Show this help message
    -v, --version        Show version information
    -c, --config         Specify configuration file
    --verbose            Enable verbose output
    --dry-run            Show what would be done
EXAMPLE: my-app install --verbose
EXAMPLE: my-app start -c /etc/my-app.conf
EXAMPLE: my-app status
```

---

## Step-by-Step Instructions

### Installation Guide

```bash
#!/bin/bash

shell::logger::section "NODE.JS INSTALLATION"

shell::logger::step 1 "Install Node Version Manager (NVM)"
shell::logger::cmd "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"
shell::logger::step_note "Restart your terminal or run 'source ~/.bashrc'"

shell::logger::step 2 "Install latest Node.js LTS"
shell::logger::cmd "nvm install --lts"
shell::logger::cmd "nvm use --lts"
shell::logger::step_note "This installs and activates the latest LTS version"

shell::logger::step 3 "Verify installation"
shell::logger::cmd "node --version"
shell::logger::cmd "npm --version"

shell::logger::step 4 "Install global packages"
shell::logger::cmd "npm install -g yarn pm2 nodemon"
shell::logger::step_note "These are commonly used development tools"
```

**Output:**

```
============================================================
  NODE.JS INSTALLATION
============================================================
STEP 1: Install Node Version Manager (NVM)
  $ curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
  NOTE: Restart your terminal or run 'source ~/.bashrc'
STEP 2: Install latest Node.js LTS
  $ nvm install --lts
  $ nvm use --lts
  NOTE: This installs and activates the latest LTS version
STEP 3: Verify installation
  $ node --version
  $ npm --version
STEP 4: Install global packages
  $ npm install -g yarn pm2 nodemon
  NOTE: These are commonly used development tools
```

---

## Command Logging

### Command Instructions

```bash
#!/bin/bash

shell::logger::section "SYSTEM MAINTENANCE"

# Simple command
shell::logger::command "docker --version"

# Command with description
shell::logger::command "Check disk usage" "df -h"
shell::logger::command "Monitor system processes" "htop"
shell::logger::command "View system logs" "journalctl -f"

# Reset options for new section
shell::logger::reset_options
```

**Output:**

```
============================================================
  SYSTEM MAINTENANCE
============================================================
COMMAND: docker --version
COMMAND: Check disk usage
         df -h
COMMAND: Monitor system processes
         htop
COMMAND: View system logs
         journalctl -f
```

---

## Indentation and Formatting

### Hierarchical Information

```bash
#!/bin/bash

shell::logger::section "PROJECT STRUCTURE"

shell::logger::indent 0 "my-project/"
shell::logger::indent 1 "src/"
shell::logger::indent 2 "components/"
shell::logger::indent 3 "Header.js"
shell::logger::indent 3 "Footer.js"
shell::logger::indent 2 "pages/"
shell::logger::indent 3 "Home.js"
shell::logger::indent 3 "About.js"
shell::logger::indent 1 "public/"
shell::logger::indent 2 "index.html"
shell::logger::indent 2 "favicon.ico"
shell::logger::indent 1 "package.json"

# Custom colors
shell::logger::section "STATUS INDICATORS"
shell::logger::indent 0 46 "✅ Services Running"
shell::logger::indent 1 196 "❌ Database Connection Failed"
shell::logger::indent 1 39 "ℹ️  Cache Warming Up"
```

**Output:**

```
============================================================
  PROJECT STRUCTURE
============================================================
my-project/
  src/
    components/
      Header.js
      Footer.js
    pages/
      Home.js
      About.js
  public/
    index.html
    favicon.ico
  package.json
============================================================
  STATUS INDICATORS
============================================================
✅ Services Running
  ❌ Database Connection Failed
  ℹ️  Cache Warming Up
```

---

## Complete Examples

### Docker Setup Guide

```bash
#!/bin/bash

shell::logger::section "DOCKER INSTALLATION & SETUP"

# Installation steps
shell::logger::step 1 "Install Docker Engine"
shell::logger::cmd "curl -fsSL https://get.docker.com -o get-docker.sh"
shell::logger::cmd "sudo sh get-docker.sh"
shell::logger::step_note "This works on Ubuntu, Debian, CentOS, and other Linux distributions"

shell::logger::step 2 "Configure user permissions"
shell::logger::cmd "sudo usermod -aG docker \$USER"
shell::logger::step_note "Log out and back in for this to take effect"

shell::logger::step 3 "Start and enable Docker service"
shell::logger::cmd "sudo systemctl start docker"
shell::logger::cmd "sudo systemctl enable docker"

shell::logger::step 4 "Verify installation"
shell::logger::cmd "docker --version"
shell::logger::cmd "docker run hello-world"

# Usage documentation
shell::logger::usage "docker [OPTIONS] COMMAND"

shell::logger::item "build" "Build an image from a Dockerfile"
shell::logger::item "run" "Create and run a new container"
shell::logger::item "ps" "List containers"
shell::logger::item "images" "List images"
shell::logger::item "pull" "Pull an image from registry"
shell::logger::item "push" "Push an image to registry"
shell::logger::item "stop" "Stop running containers"
shell::logger::item "rm" "Remove containers"

shell::logger::option "-d, --detach" "Run container in background"
shell::logger::option "-p, --publish" "Publish container port"
shell::logger::option "-v, --volume" "Mount volume"
shell::logger::option "-e, --env" "Set environment variable"
shell::logger::option "--name" "Container name"
shell::logger::option "--rm" "Remove container after exit"

shell::logger::example "docker run -d -p 80:80 --name web nginx"
shell::logger::example "docker build -t my-app:v1.0 ."
shell::logger::example "docker run --rm -it ubuntu bash"
```

### AWS CLI Setup

```bash
#!/bin/bash

shell::logger::section "AWS CLI CONFIGURATION"

shell::logger::step 1 "Install AWS CLI v2"
shell::logger::cmd "curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'"
shell::logger::cmd "unzip awscliv2.zip"
shell::logger::cmd "sudo ./aws/install"

shell::logger::step 2 "Configure credentials"
shell::logger::cmd "aws configure"
shell::logger::step_note "You'll need Access Key ID, Secret Access Key, Default region, and Output format"

shell::logger::step 3 "Verify configuration"
shell::logger::cmd "aws sts get-caller-identity"
shell::logger::cmd "aws s3 ls"

shell::logger::usage "aws [OPTIONS] <service> <operation> [parameters]"

shell::logger::item "s3" "Simple Storage Service operations"
shell::logger::item "ec2" "Elastic Compute Cloud operations"
shell::logger::item "iam" "Identity and Access Management"
shell::logger::item "lambda" "AWS Lambda functions"
shell::logger::item "rds" "Relational Database Service"

shell::logger::option "--region" "AWS region to use"
shell::logger::option "--profile" "Named profile to use"
shell::logger::option "--output" "Output format (json|table|text|yaml)"
shell::logger::option "--debug" "Enable debug logging"

shell::logger::example "aws s3 cp file.txt s3://bucket-name/"
shell::logger::example "aws ec2 describe-instances --region us-west-2"
shell::logger::example "aws lambda list-functions --profile production"

# Reset options for potential next section
shell::logger::reset_options
```

---

## Advanced Usage Patterns

### Complex Application Setup

```bash
#!/bin/bash

shell::logger::section "KUBERNETES APPLICATION DEPLOYMENT"

# Prerequisites
shell::logger::indent 0 "Prerequisites:"
shell::logger::indent 1 "• Kubernetes cluster running"
shell::logger::indent 1 "• kubectl configured"
shell::logger::indent 1 "• Docker images built"

shell::logger::step 1 "Prepare namespace"
shell::logger::cmd "kubectl create namespace my-app"
shell::logger::cmd "kubectl config set-context --current --namespace=my-app"

shell::logger::step 2 "Deploy application"
shell::logger::cmd "kubectl apply -f k8s/deployment.yaml"
shell::logger::cmd "kubectl apply -f k8s/service.yaml"
shell::logger::cmd "kubectl apply -f k8s/ingress.yaml"

shell::logger::step 3 "Verify deployment"
shell::logger::cmd "kubectl get pods -w"
shell::logger::step_note "Wait for all pods to be in Running state"

shell::logger::step 4 "Check services"
shell::logger::cmd "kubectl get services"
shell::logger::cmd "kubectl get ingress"

# Troubleshooting section
shell::logger::section "TROUBLESHOOTING"

shell::logger::indent 0 "Common issues and solutions:"
shell::logger::indent 1 196 "Pod stuck in Pending:"
shell::logger::indent 2 "Check resource requests vs available capacity"
shell::logger::cmd "kubectl describe node"

shell::logger::indent 1 196 "Pod in CrashLoopBackOff:"
shell::logger::indent 2 "Check application logs"
shell::logger::cmd "kubectl logs <pod-name> --previous"

shell::logger::indent 1 196 "Service not accessible:"
shell::logger::indent 2 "Verify service selector matches pod labels"
shell::logger::cmd "kubectl get pods --show-labels"
```

---

## Tips and Best Practices

### Using Logger Functions Effectively

1. **Start with sections** for major topics
2. **Use steps** for sequential instructions
3. **Add notes** for important information
4. **Reset options** between different usage sections
5. **Use indentation** for hierarchical information
6. **Custom colors** for status indicators

```bash
#!/bin/bash

# Good practice: Section organization
shell::logger::section "DATABASE SETUP"

# Use steps for procedures
shell::logger::step 1 "Install PostgreSQL"
shell::logger::step 2 "Configure database"
shell::logger::step 3 "Create users and permissions"

# Reset options between different sections
shell::logger::reset_options

shell::logger::section "APPLICATION CONFIGURATION"

# Usage documentation
shell::logger::usage "app [OPTIONS] COMMAND"
shell::logger::option "--config" "Configuration file path"
shell::logger::option "--verbose" "Enable verbose logging"

# Always provide examples
shell::logger::example "app start --config /etc/app.conf --verbose"
```

This completes the comprehensive guide for all shell logger functions! 🚀
