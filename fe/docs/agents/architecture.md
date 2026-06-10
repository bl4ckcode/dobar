# Architecture, Tech Stack & State Management

This document defines the architectural patterns, state management, and core tech stack used in the Dobar client application.

## Core Tech Stack
- **Framework**: Flutter 3.27+
- **State Management**: BLoC (Business Logic Component) + Cubit patterns
- **Code Generation**: Freezed & JSON Serializable
- **Routing**: GoRouter for declarative routing and deep linking
- **Networking**: Dio client for HTTP requests and API consumption
- **Dependency Injection**: GetIt for service location and dependency management
- **Localization**: Native Flutter l10n support
- **Icons**: Lucide Icons package

## Architecture Patterns
The project follows **Clean Architecture** principles to separate concerns and ensure maintainability:
- **Presentation Layer**: Widgets, Screens, and BLoCs/Cubits to manage state.
- **Domain Layer**: Pure Dart logic including Models, Repository interfaces, and Use Cases.
- **Data Layer**: Data sources, API clients (Dio), Local storage implementations, and concrete Repository implementations.
