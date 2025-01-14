# Project Scaffold Generator

A comprehensive project scaffolding tool that creates standardized project structures with best practices and common configurations.

## Features

- Multiple project templates (Python, Node.js, Go, Rust)
- Git initialization with .gitignore
- Package manager setup
- Docker configuration
- CI/CD setup
- Testing framework
- Documentation templates
- Interactive mode for guided setup

## Usage

```bash
./project-scaffold.sh [OPTIONS] PROJECT_NAME

Options:
  -t, --type TYPE      Project type (python|node|go|rust)
  -o, --output DIR     Output directory
  --template-dir DIR   Custom template directory
  --no-git            Don't initialize git repository
  --no-pkg-mgr        Don't initialize package manager
  -d, --docker        Add Docker configuration
  -c, --ci            Add CI/CD configuration
  --no-tests          Don't add testing setup
  --no-docs           Don't add documentation
  -i, --interactive   Interactive mode
```

## Examples

1. Create a Python project with all defaults:
```bash
./project-scaffold.sh -t python my-python-app
```

2. Create a Node.js project with Docker and CI/CD:
```bash
./project-scaffold.sh -t node -d -c my-node-app
```

3. Create a Go project interactively:
```bash
./project-scaffold.sh -t go -i my-go-app
```

## Project Structure

The generated project will have the following structure (example for Python):

```
my-python-app/
├── src/
│   └── __init__.py
├── tests/
│   └── __init__.py
├── docs/
├── scripts/
├── .github/
│   └── workflows/
├── config/
├── requirements.txt
├── setup.py
├── README.md
└── .gitignore
```

## Configuration

The script can be configured through:
- Command-line arguments
- Configuration files
- Environment variables

## Dependencies

- Git
- Language-specific tools (python, node, go, rust)
- Docker (optional)
