# API Design Best Practices

## REST Fundamentals & Operations
APIs should be designed around resources (e.g., `/bars`, `/menus`, `/promotions`).
- **GET:** Read data from a resource.
- **POST:** Add a new item to a resource.
- **PUT/PATCH:** Replace/update an item.
- **DELETE:** Remove an item.
Consistency in these paths makes our APIs predictable and developer-friendly.

## Error Handling
A strong API returns clear, consistent error messages along with the adequate HTTP Status Code.
- A good error clearly articulates what went wrong without leaking internal system details or security risks.

## Correlation with Dobar Ecosystem
- **API_ERROR_CONTRACT.md:** We already maintain an API Error Contract. Best practices dictate we stick to using standard status codes (400 for client errors, 500 for server, 404 for not found, etc.) and enrich the payload to help the Flutter FE gracefully adapt.
- **FE_BE_COMMUNICATION.md:** Our FE expects uniform data formats. Following strict REST fundamentals (avoiding RPC-style calls unless absolutely necessary) keeps our frontend scalable.
- **Pagination & Throttling:** As usage scales per out BUSINESS_PLAN, rate-limiting API endpoints prevents abuse, and predictable versioning (e.g., `/v1/cart`) ensures backward compatibility across older installed mobile app versions.
