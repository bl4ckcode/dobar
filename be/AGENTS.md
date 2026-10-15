# Dobar back-end Agent Guidelines

A production back-end Python FastAPI application for connecting dobar owners and users with venues and services.

## 🚀 The Essentials
- **Package Manager**: Pip (using `requirements.txt` and `requirements-test.txt`)
- **Safeguard**: This app is hosted in FlyIO; all deploys must run via the GitHub Actions CI/CD pipeline. Always ensure backward compatibility for existing users and data.

## 📖 Specialized Documentation
- [**Architecture & Tech Stack**](docs/agents/architecture.md)
- [**Development Workflow**](docs/agents/development_workflow.md)
