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
4. **Back-end support, services/endpoints request and fixes**
   - We always write to @FE_BE_COMMUNICATION.md when we need to request or fix back-end services/endpoints.
   - We clean up the file with outdated/irrelevant information so it always stays relevant, up-to-date, concise and easy to understand.
5. **Our UI/UX design is always loyal to @dobar_colors and Lovable generated projects**
   - We very often ask Lovable to generate our UI's and Workflows designs, we store the prompts in @lovable_stitch_prompts.md and follow the patterns there.
   - Lovable generates a React Native project, often with light mode which we ask too, which we clone, replicate, copy and translate to our Flutter needs.
