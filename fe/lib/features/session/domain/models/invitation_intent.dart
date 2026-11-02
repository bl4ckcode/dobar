String? parseInvitationCode(String input, {bool allowManual = true}) {
  var candidate = input.trim();
  final uri = Uri.tryParse(candidate);
  if (uri != null && uri.hasScheme) {
    if (uri.scheme != 'https' ||
        uri.host != 'dobar.app' ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    if (uri.path == '/staff/invitations/accept') {
      candidate = uri.queryParameters['code'] ?? '';
    } else if ((uri.pathSegments.length == 2 ||
            (uri.pathSegments.length == 3 && uri.pathSegments.last.isEmpty)) &&
        uri.pathSegments.first == 'convite') {
      candidate = uri.pathSegments[1];
    } else {
      return null;
    }
  } else if (!allowManual) {
    return null;
  }
  final manual = RegExp(
    r'^DBR-?([A-Z0-9]{4})-?([A-Z0-9]{4})$',
    caseSensitive: false,
  ).firstMatch(candidate);
  if (manual != null) {
    return 'DBR-${manual[1]!.toUpperCase()}-${manual[2]!.toUpperCase()}';
  }
  return RegExp(r'^[A-Za-z0-9_-]{16,128}$').hasMatch(candidate)
      ? candidate
      : null;
}
