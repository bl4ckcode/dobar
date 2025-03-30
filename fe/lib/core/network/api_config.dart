const String baseUrl = "http://10.0.2.2:8000/";
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
