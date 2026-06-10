# Development Workflow

This document outlines the workflow and verification guidelines when developing for the Dobar client application.

## Core Workflow Steps
1. **Dependency Injection & Code Generation**:
   Whenever you modify classes that use code generation (e.g., `@freezed`, `@JsonSerializable`), you must regenerate files using:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
2. **Backward Compatibility**:
   - Ensure that all changes to API contracts, local storage schemas, and model structures maintain backward compatibility for existing users and production data.
3. **Verification**:
   - Run tests to verify the integrity of the application:
     ```bash
     flutter test
     ```
