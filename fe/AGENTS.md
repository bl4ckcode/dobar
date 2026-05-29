# Dobar Agent Guidelines

A production Flutter application for dobar owners and clients connecting venues and users.

## 🚀 The Essentials
- **Package Manager**: Pub (Dart)
- **Critical Command**: `dart run build_runner build --delete-conflicting-outputs`
- **Safeguard**: This app is used in production. Always ensure backward compatibility for existing users and data.

## 📖 Specialized Documentation
- [**Architecture, Tech Stack & State Management**](docs/agents/architecture.md)
- [**Development Workflow**](docs/agents/development_workflow.md)
- [**Direct communication with back-end**](docs/agents/FE_BE_COMMUNICATION.md)
- [**Domain knowledge (External)**](../barz-backend/.docs/business)
- [**Dobar payment engine (External)**](../dobar-payment-engine/.docs)