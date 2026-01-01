import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'firebase_options.dart';
import 'core/di/injection.dart';
import 'core/services/app_initializer.dart';
import 'core/theme/app_theme.dart';
import 'ui/screens/login_wireframe.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure URL strategy for web to use path-based URLs instead of hash-based
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  // Initialize Firebase SDK
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize dependencies (DI container)
  const bool useMockApi = bool.fromEnvironment(
    'USE_MOCK_API',
    defaultValue: false,
  );
  initDependencies(useMock: useMockApi);

  // CRITICAL: Run app initializer to handle version migrations
  // This prevents users from being logged out after app updates
  await getIt<AppInitializer>().run();

  runApp(const BarzApp());

  // Set preferred orientations for mobile
  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }
}

class BarzApp extends StatefulWidget {
  const BarzApp({super.key});

  @override
  BarzAppState createState() => BarzAppState();
}

class BarzAppState extends State<BarzApp> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldMessengerState> snackBarKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Barz',
      theme: getLightTheme(),
      darkTheme: getDarkTheme(),
      themeMode: ThemeMode.light,
      // Start with login screen - authentication required before main app
      home: const LoginWireframe(),
    );
  }
}

const defaultInputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(
    Radius.circular(16),
  ),
  borderSide: BorderSide(
    color: Color(0xFFDEE3F2),
    width: 1,
  ),
);
