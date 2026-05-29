# Architecture & Tech Stack

This document details the architectural patterns, state management, and technical stack used in the Dobar back-end application.

## 🏗️ Architectural Pattern
- **Pattern**: MVC (Model-View-Controller) / Modular Monolith.
- **State Management**: Managed using FastAPI dependency injection and Pydantic models.

## 💻 Tech Stack
- **Database**: PostgreSQL (relational database).
- **ORM**: SQLAlchemy 2.0 with Alembic for database migrations.
- **Authentication**: JWT tokens (access_token, refresh_token) stored in encrypted cookies.
- **Authorization**: Role-based access control (RBAC) with roles: `superadmin`, `admin`, `venue_admin`, and `user`.
- **Background Tasks**: FastAPI native `BackgroundTasks`.
- **Cache**: Redis for caching frequently accessed data.
- **File Storage**: Local filesystem with AWS S3 integration for image uploads.
