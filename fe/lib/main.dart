import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'firebase_options.dart';
import 'core/utils/injections.dart';
import 'core/services/app_initializer.dart';
import 'core/design/design_system.dart';
import 'core/router/app_router.dart';
import 'core/theme/theme_cubit.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/locale/locale_cubit.dart';
import 'package:barz/features/location/presentation/bloc/location_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await initInjections();
  await getItInjector<AppInitializer>().run();

  runApp(const DobarApp());

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

class DobarApp extends StatefulWidget {
  const DobarApp({super.key});

  @override
  DobarAppState createState() => DobarAppState();
}

class DobarAppState extends State<DobarApp> with WidgetsBindingObserver {
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
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getItInjector<ThemeCubit>()),
        BlocProvider(create: (_) => getItInjector<LocaleCubit>()),
        BlocProvider(create: (_) => getItInjector<LocationCubit>()),
      ],
      child: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, locale) {
          return BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (context, themeMode) {
              return MaterialApp.router(
                routerConfig: appRouter,
                debugShowCheckedModeBanner: false,
                title: 'Dobar',
                locale: locale,
                theme: getBarzLightTheme(),
                darkTheme: getBarzDarkTheme(),
                themeMode: themeMode,
                localizationsDelegates: [
                  ...AppLocalizations.localizationsDelegates,
                  ...PhoneFieldLocalization.delegates,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
              );
            },
          );
        },
      ),
    );
  }
}

const defaultInputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(16)),
  borderSide: BorderSide(color: Color(0xFFDEE3F2), width: 1),
);
