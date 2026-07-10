# Development Workflow

This document details the development workflow, package management, and testing guidelines for the Dobar back-end application.

## Clean Code
- **No comments or docstrings**: Code should be self-explanatory. Use clear variable and function names.

## 📦 Package Management
- **Tool**: Standard `pip` utilizing `requirements.txt` for production/application dependencies and `requirements-test.txt` for development/testing dependencies.
- **Virtual Environment**: Use a Python virtual environment (`venv`) for local development.

## 🧪 Testing Guidelines
- **Framework**: `pytest` for running unit and integration tests.
- **Asynchronous Testing**: `pytest-asyncio` for handling asynchronous test cases.
- **Mocking**: `pytest-mock` for dependency mocking.
- **Running Tests**: Run tests locally with:
  ```bash
  pytest
  ```

## 🚀 Deployment Safeguards
- **CI/CD**: Deployment to FlyIO is completely automated via Github Actions. Direct manual deploys should be avoided.
- **Compatibility**: Always ensure backward compatibility for existing users, API endpoints, and database schemas when introducing new features.
