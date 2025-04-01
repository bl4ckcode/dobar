# BarZ Backend

Welcome to the **BarZ Backend** repository! This is the backend service for the BarZ app, which allows users to browse restaurant/bar menus, place orders, and have their orders delivered to their table or location. This project now includes a comprehensive Bars and Restaurants API with dual-database architecture, real-time updates, AWS S3 image storage with pre-signed URLs, and robust error handling.

## Table of Contents
- [Features](#features)
- [Technologies](#technologies)
- [Setup](#setup)
- [Environment Variables](#environment-variables)
- [API Endpoints](#api-endpoints)
- [Authentication](#authentication)
- [Contributing](#contributing)
- [Context & AI Assistance](#context--ai-assistance)
- [License](#license)

## Features
- **User Authentication:** Supports Firebase phone authentication, Google Sign-In, Apple Sign-In, and Facebook Sign-In.
- **JWT Tokens:** Secure authentication using JSON Web Tokens (JWT).
- **Bars & Restaurants API:**  
  - **Dual Database Architecture:**  
    - **PostgreSQL:** Stores static data (e.g., bar details, owner info) using SQLAlchemy models.  
    - **MongoDB:** Stores dynamic and geospatial data (e.g., bar locations, menus, and image URLs).  
  - **Real-Time Updates:** WebSocket endpoints using MongoDB change streams allow live updates on orders, menus, and bar status.
  - **Image Handling:** Restaurant images are stored in AWS S3. Pre-signed URLs are generated to securely serve images to the Flutter frontend.
  - **Robust Error Handling:** Consistent error responses using a unified error model and custom exception helpers.
- **Scalable Architecture:** Built with FastAPI for high performance and scalability.

## Technologies
- **Backend Framework:** [FastAPI](https://fastapi.tiangolo.com/)
- **Databases:**  
  - PostgreSQL (static data via SQLAlchemy ORM)  
  - MongoDB (dynamic data & geospatial queries via Motor)
- **Image Storage:** AWS S3 with pre-signed URL generation
- **Real-Time Communication:** WebSockets for live updates
- **Authentication:** Firebase, JWT
- **Package Manager:** Poetry or Pip
- **Other Tools:** GitHub, Docker (optional)

## Setup

### Prerequisites
- Python 3.8+
- Firebase project (for authentication)
- AWS account with S3 access
- PostgreSQL & MongoDB instances (local or hosted)
- GitHub account (for repository management)

### Installation
1. **Clone the repository:**
   ```bash
   git clone https://github.com/bl4ckcode/barz-backend.git
   cd barz-backend
   ```

2. **Set up a virtual environment:**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

4. **Set up environment variables:**
   - Create a `.env` file in the root directory.
   - Add the following variables:
     ```bash
     SECRET_KEY=your-secure-secret-key
     DATABASE_URL=your-postgresql-connection-url
     MONGO_HOST=your-mongo-host
     MONGO_PORT=your-mongo-port
     MONGO_DB=your-mongo-database
     FIREBASE_CREDENTIALS_PATH=/path/to/firebase-credentials.json
     AWS_ACCESS_KEY=your-aws-access-key
     AWS_SECRET_KEY=your-aws-secret-key
     AWS_REGION=your-aws-region
     AWS_S3_BUCKET=your-s3-bucket-name
     ```
5. **Run the application:**
   ```bash
   uvicorn main:app --reload
   ```

6. **Access the API:**
   - Open your browser and go to `http://127.0.0.1:8000`.
   - Interactive API docs are available at `http://127.0.0.1:8000/docs`.

## Environment Variables
The following environment variables are required:

| Variable                    | Description                                             | Example Value                                      |
|-----------------------------|---------------------------------------------------------|----------------------------------------------------|
| `SECRET_KEY`                | Secret key for JWT token signing                        | `your-secure-secret-key`                           |
| `DATABASE_URL`              | PostgreSQL database connection URL                      | `postgresql://user:pass@host:port/dbname`           |
| `MONGO_HOST`                | MongoDB host                                            | `localhost`                                        |
| `MONGO_PORT`                | MongoDB port                                            | `27017`                                            |
| `MONGO_DB`                  | MongoDB database name                                   | `barz_db`                                          |
| `FIREBASE_CREDENTIALS_PATH` | Path to Firebase Admin SDK credentials file             | `/path/to/firebase-credentials.json`               |
| `AWS_ACCESS_KEY`            | AWS access key for S3                                     | `your-aws-access-key`                              |
| `AWS_SECRET_KEY`            | AWS secret key for S3                                     | `your-aws-secret-key`                              |
| `AWS_REGION`                | AWS region for S3                                         | `sa-east-1`                                        |
| `AWS_S3_BUCKET`             | AWS S3 bucket name                                        | `barz-images`                                      |

## API Endpoints
### Authentication
- **POST `/auth/phone`**: Login or register with Firebase phone authentication.
- **POST `/auth/google`**: Login or register with Google Sign-In.
- **POST `/auth/apple`**: Login or register with Apple Sign-In.
- **POST `/auth/facebook`**: Login or register with Facebook Sign-In.

#### Example Request (Phone Login)
```json
{
  "firebase_uid": "your-firebase-uid",
  "phone_number": "+1234567890"
}
```

#### Example Response
```json
{
  "access_token": "your-jwt-token",
  "token_type": "bearer"
}
```

### Bars & Restaurants API
- **GET `/bars/`**: Retrieve bars near a given location using geospatial queries. Returns additional fields like `approximateLocation` and a pre-signed `image_url`.
- **POST `/bars/`**: Create a new bar with associated data (including image upload via multipart/form-data).  
- **PUT `/bars/{bar_id}/image`**: Update the image for a specific bar by uploading a new image to AWS S3, which returns a fresh pre-signed URL.
- **Other Endpoints:** Additional endpoints for menus, orders, and bar owner management.

### Real-Time Updates
- **WebSocket Endpoints:**  
  - `/ws`: General WebSocket connection.  
  - `/ws/orders`: Receive real-time order updates.  
  - `/ws/menus`: Receive real-time menu updates.

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

## Context & AI Assistance
This project is built with a collaborative spirit in mind.  
**If you need guidance or further context on the API, please feel free to consult ChatGPT.**  
Simply prompt ChatGPT with context about the BarZ API and you'll receive detailed assistance and suggestions to continue developing BarZ with innovative ideas and best practices:

```Prompt:
"I need assistance with the BarZ Backend API. This project is built using FastAPI and features a dual-database architecture where PostgreSQL stores static data (such as bar details and owner information) and MongoDB handles dynamic and geospatial data (including bar locations, menus, and image URLs). Images are uploaded to AWS S3 and accessed via pre-signed URLs. The API includes robust error handling with custom error responses and real-time updates using WebSockets. Authentication is managed with Firebase and JWT tokens. Additionally, the project is organized into modular routers and services, employs SQLAlchemy for ORM, and uses Motor for MongoDB interactions. Can you provide guidance on [insert specific question here]?"
```

Please ensure to replace "[insert specific question here]" with your actual question.

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

Made with ❤️ by [bl4ckcode](https://github.com/bl4ckcode)
