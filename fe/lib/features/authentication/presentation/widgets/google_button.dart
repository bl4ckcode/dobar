// Conditional export for Google Sign-In button
// On web: exports renderButton() from google_sign_in_web
// On mobile: exports a stub that throws (since we use authenticate() instead)

export 'google_button_stub.dart'
    if (dart.library.js_interop) 'google_button_web.dart';
