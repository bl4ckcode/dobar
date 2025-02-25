# BarZ Backend

Welcome to the **BarZ Backend** repository! This is the backend service for the BarZ app, which allows users to browse restaurant/bar menus, place orders, and have their orders delivered to their table or location.

## Table of Contents
- [Features](#features)
- [Technologies](#technologies)
- [Setup](#setup)
- [Environment Variables](#environment-variables)
- [API Endpoints](#api-endpoints)
- [Authentication](#authentication)
- [Contributing](#contributing)
- [License](#license)

## Features
- **User Authentication:** Supports Firebase phone authentication, Google Sign-In, Apple Sign-In, and Facebook Sign-In.
- **JWT Tokens:** Secure authentication using JSON Web Tokens (JWT).
- **Scalable Architecture:** Built with FastAPI for high performance and scalability.
- **Database:** Uses SQLite for development (can be easily switched to PostgreSQL or MySQL for production).

## Technologies
- **Backend Framework:** [FastAPI](https://fastapi.tiangolo.com/)
- **Database:** SQLite (with SQLAlchemy ORM)
- **Authentication:** Firebase, JWT
- **Package Manager:** Poetry or Pip (your choice)
- **Other Tools:** GitHub, Docker (optional)

## Setup

### Prerequisites
- Python 3.8+
- Firebase project (for authentication)
- GitHub account (for repository management)

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/bl4ckcode/barz-backend.git
   cd barz-backend
   ```

2. Set up a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Set up environment variables:
   - Create a `.env` file in the root directory.
   - Add the following variables:
     ```bash
     SECRET_KEY=your-secure-secret-key
     DATABASE_URL=sqlite:///./test.db
     FIREBASE_CREDENTIALS_PATH=/path/to/firebase-credentials.json
     ```

5. Run the application:
   ```bash
   uvicorn main:app --reload
   ```

6. Access the API:
   - Open your browser and go to `http://127.0.0.1:8000`.
   - Interactive API docs are available at `http://127.0.0.1:8000/docs`.

## Environment Variables
The following environment variables are required:

| Variable                | Description                                   | Example Value                          |
|-------------------------|-----------------------------------------------|----------------------------------------|
| `SECRET_KEY`            | Secret key for JWT token signing             | `your-secure-secret-key`               |
| `DATABASE_URL`          | Database connection URL                      | `sqlite:///./test.db`                  |
| `FIREBASE_CREDENTIALS_PATH` | Path to Firebase Admin SDK credentials file | `/path/to/firebase-credentials.json`   |

## API Endpoints
### Authentication
- **POST `/auth/phone`**: Login or register with Firebase phone authentication.
- **POST `/auth/google`**: Login or register with Google Sign-In.
- **POST `/auth/apple`**: Login or register with Apple Sign-In.
- **POST `/auth/facebook`**: Login or register with Facebook Sign-In.

### Example Request (Phone Login)
```json
{
  "firebase_uid": "your-firebase-uid",
  "phone_number": "+1234567890"
}
```

### Example Response
```json
{
  "access_token": "your-jwt-token",
  "token_type": "bearer"
}
```

## Authentication
- **JWT Tokens:** All authenticated endpoints require a valid JWT token in the `Authorization` header.
  ```bash
  Authorization: Bearer <your-jwt-token>
  ```

## Contributing
Contributions are welcome! Please follow these steps:
1. Fork the repository.
2. Create a new branch (`git checkout -b feature/YourFeatureName`).
3. Commit your changes (`git commit -m 'Add some feature'`).
4. Push to the branch (`git push origin feature/YourFeatureName`).
5. Open a pull request.

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

Made with ❤️ by [bl4ckcode](https://github.com/bl4ckcode)
```

---

### **How to Use This README**
1. Copy the content above into a new file named `README.md` in the root of your repository.
2. Customize the sections (e.g., replace `bl4ckcode` with your GitHub username).
3. Commit and push the file to GitHub:
   ```bash
   git add README.md
   git commit -m "Add README.md"
   git push origin main
   ```

---

### **What’s Included in the README**
1. **Project Overview:** A brief description of the project.
2. **Features:** Highlights the key features of the backend.
3. **Technologies:** Lists the technologies used.
4. **Setup Instructions:** Step-by-step guide to set up the project locally.
5. **Environment Variables:** Explains the required environment variables.
6. **API Endpoints:** Documents the available API endpoints.
7. **Authentication:** Explains how authentication works.
8. **Contributing:** Guidelines for contributing to the project.
9. **License:** Specifies the license for the project.
