import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocket_payout_bd/providers/user_provider.dart';
import 'package:pocket_payout_bd/screens/wrapper.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pocket_payout_bd/utils/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pocket_payout_bd/utils/constants.dart';
import 'package:pocket_payout_bd/services/ad_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Disable Firestore persistence to prevent the database lock error
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
  
  // Initialize AdService (which handles Google Mobile Ads)
  await AdService().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        home: const Wrapper(),
      ),
    );
  }
}
