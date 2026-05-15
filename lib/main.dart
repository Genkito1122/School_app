import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_app/auth/Auth.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_app/pages/select_role.dart';
import 'package:school_app/pages/main_page.dart';
import 'package:school_app/pages/profile_setup.dart';
import 'package:school_app/services/homework_service.dart';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';


void main() async {
    await dotenv.load();
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  

  _startHomeworkCleanup();
  
  runApp(const MyApp());
}


void _startHomeworkCleanup() {
  Timer.periodic(const Duration(hours: 24), (timer) async {
    try {
      final homeworkService = HomeworkService();
      await homeworkService.deactivateExpiredHomeworks();
      print('✅ Автоматическая очистка просроченных ДЗ выполнена');
    } catch (e) {
      print('❌ Ошибка автоматической очистки ДЗ: $e');
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const AuthCheck(),
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }


        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              if (!userSnapshot.hasData || !userSnapshot.data!.exists) {

                FirebaseAuth.instance.signOut();
                return const Auth();
              }

              final data = userSnapshot.data!.data() as Map<String, dynamic>;
              final role = data['role'];
              final profileComplete = data['profileComplete'] ?? false;

              if (role == null) {
                return SelectRolePage(uid: snapshot.data!.uid);
              } else if (!profileComplete) {
                return ProfileSetupPage(uid: snapshot.data!.uid, role: role);
              } else {
                return const MainPage(); 
              }
            },
          );
        }


        return const Auth();
      },
    );
  }
}
