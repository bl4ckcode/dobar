import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/home/presentation/pages/home_page.dart';
import 'package:barz/shared/data/data_sources/app_shared_prefs.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inject all dependencies
  await initInjections();

  runApp(DevicePreview(
    builder: (context) {
      return const BarzApp();
    },
    enabled: false,
  ));

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
}

class BarzApp extends StatefulWidget {
  const BarzApp({super.key});

  @override
  BarzAppState createState() => BarzAppState();
}

class BarzAppState extends State<BarzApp> with WidgetsBindingObserver {
  Locale locale = const Locale("en");
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
    return ChangeNotifierProvider(
      create: (_) => AppNotifier(),
      child: Consumer<AppNotifier>(
        builder: (context, value, child) {
          return ScreenUtilInit(
            designSize: const Size(360, 690),
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (context, child) {
              return MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: ThemeData(
                  scaffoldBackgroundColor: Colors.white,
                  primarySwatch: Colors.blue,
                  fontFamily: "Intel",
                  elevatedButtonTheme: ElevatedButtonThemeData(
                    style:
                        ElevatedButton.styleFrom(foregroundColor: Colors.white),
                  ),
                  inputDecorationTheme: const InputDecorationTheme(
                    filled: true,
                    fillColor: Colors.white,
                    errorStyle: TextStyle(height: 0),
                    border: defaultInputBorder,
                    enabledBorder: defaultInputBorder,
                    focusedBorder: defaultInputBorder,
                    errorBorder: defaultInputBorder,
                  ),
                  colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
                  useMaterial3: true,
                ),
                home: const HomePage(),
              );
            },
          );
        },
      ),
    );
  }
}

class AppNotifier extends ChangeNotifier {
  late bool darkTheme;

  AppNotifier() {
    _initialise();
  }

  Future _initialise() async {
    darkTheme = getItInjector<AppSharedPrefs>().getIsDarkTheme();

    notifyListeners();
  }

  void updateThemeTitle(bool newDarkTheme) {
    darkTheme = newDarkTheme;
    if (getItInjector<AppSharedPrefs>().getIsDarkTheme()) {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    } else {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    }
    notifyListeners();
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
