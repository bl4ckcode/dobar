const String baseUrl = "https://barz-backend-bold-sun-5691.fly.dev/";
const defaultHeaders = {
  'Content-Type': 'application/json',
  'Authorization': 'Bearer ',
};

void setAuthToken(String token) {
  defaultHeaders['Authorization'] = 'Bearer $token';
}

Map<String, String> getHeaders() {
  return defaultHeaders;
}
