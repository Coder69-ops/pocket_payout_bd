import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pocket_payout_bd/providers/user_provider.dart';
import 'package:pocket_payout_bd/screens/wrapper.dart';
import 'package:pocket_payout_bd/screens/splash_screen.dart';
import 'package:pocket_payout_bd/screens/auth_screen.dart';
import 'package:pocket_payout_bd/screens/home_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pocket_payout_bd/utils/firebase_options.dart';

// Flag to disable Impeller rendering
const bool disableImpeller = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Set system UI overlay style for a cleaner look
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF068D5D),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Error initializing Firebase: $e');
  }
  
  // Initialize MobileAds with proper request configuration
  await MobileAds.instance.initialize();
  
  // Configure mobile ads request for targeting
  final configuration = RequestConfiguration(
    tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
    tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.unspecified,
    testDeviceIds: ['EMULATOR'],
  );
  MobileAds.instance.updateRequestConfiguration(configuration);
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    
    // Additional renderer safety configs
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024; // 100 MB
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MaterialApp(
        title: 'Pocket Payout BD',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        routes: {
          '/auth': (context) => const AuthScreen(),
          '/home': (context) => const HomeScreen(),
        },
        home: const SplashScreen(child: Wrapper()),
      ),
    );
  }
}
