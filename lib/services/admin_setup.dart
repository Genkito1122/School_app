import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminSetup {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createDefaultAdmin() async {
    try {
      // Проверяем, есть ли уже админ
      final adminSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .limit(1)
          .get();

      if (adminSnapshot.docs.isEmpty) {
        // Создаём админа
        final adminEmail = 'admin@schoolapp.ru';
        final adminPassword = 'Admin123456';

        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: adminEmail,
          password: adminPassword,
        );

        final uid = userCredential.user!.uid;

        // Создаём запись в users
        await _firestore.collection('users').doc(uid).set({
          'uid': uid,
          'email': adminEmail,
          'username': 'admin',
          'role': 'admin',
          'profileComplete': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Создаём запись в admins
        await _firestore.collection('admins').doc(uid).set({
          'uid': uid,
          'fullName': 'Администратор Системы',
          'permissions': ['all'],
          'createdAt': FieldValue.serverTimestamp(),
        });

      }
    } catch (e) {
    }
  }
}