const String baseUrl = "http://127.0.0.1:8000/";
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
