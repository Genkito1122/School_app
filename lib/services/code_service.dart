import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_app/services/chat_service.dart';

class CodeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ADMIN 
  Future<String> generateAdminCode({String? createdByAdminId}) async {
    final newCode = 'ADM${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    
    await _firestore.collection('admin_codes').doc(newCode).set({
      'code': newCode,
      'createdBy': createdByAdminId ?? 'system',
      'createdByRef': createdByAdminId != null ? 'admins/$createdByAdminId' : 'system',
      'used': false,
      'usedBy': null,
      'usedByRef': null,
      'purpose': 'director_registration',
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
    });
    
    return newCode;
  }

  Future<List<Map<String, dynamic>>> getActiveAdminCodes() async {
    final snapshot = await _firestore
        .collection('admin_codes')
        .where('used', isEqualTo: false)
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'code': data['code'],
        'createdAt': data['createdAt'],
        'expiresAt': data['expiresAt'],
        'createdByRef': data['createdByRef'],
      };
    }).toList();
  }

  Future<bool> verifyAdminCode(String code) async {
    try {
      final snapshot = await _firestore
          .collection('admin_codes')
          .where('code', isEqualTo: code)
          .where('used', isEqualTo: false)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .limit(1)
          .get();

      print('Проверка кода $code: найдено ${snapshot.docs.length} записей');
      
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        print('Код действителен: ${data['code']}');
        return true;
      }
      
      print('Код не найден или недействителен');
      return false;
    } catch (e) {
      print('Ошибка проверки кода: $e');
      return false;
    }
  }

  Future<void> useAdminCode(String code, String usedByDirectorId) async {
    await _firestore.collection('admin_codes').doc(code).update({
      'used': true,
      'usedBy': usedByDirectorId,
      'usedByRef': 'directors/$usedByDirectorId',
      'usedAt': FieldValue.serverTimestamp(),
    });
  }

  // Zavuch
  
  Future<String> generateVicePrincipalCode(String schoolId) async {
    try {
      print('🔄 generateVicePrincipalCode вызван с schoolId: "$schoolId"');
      
      if (schoolId.isEmpty) {
        throw Exception('School ID is empty');
      }

      final newCode = 'VPR${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      print('🎯 Сгенерирован код завуча: $newCode');

      final schoolDoc = await _firestore.collection('schools').doc(schoolId).get();
      if (!schoolDoc.exists) {
        throw Exception('Школа с ID $schoolId не найдена');
      }

      print('✅ Школа найдена, обновляем vicePrincipalCodes...');
      
      await _firestore.collection('schools').doc(schoolId).update({
        'vicePrincipalCodes': FieldValue.arrayUnion([newCode]),
      });

      print('✅ Код завуча $newCode добавлен в школу $schoolId');
      return newCode;
    } catch (e) {
      print('❌ Ошибка в generateVicePrincipalCode: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> verifyVicePrincipalCode(String code) async {
    try {
      print('🔍 Проверка кода завуча: $code');
      
      final snapshot = await _firestore
          .collection('schools')
          .where('vicePrincipalCodes', arrayContains: code)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final school = snapshot.docs.first;
        return {
          'schoolId': school.id,
          'schoolName': school.data()['name'],
          'isValid': true,
        };
      }
      print('❌ Код завуча не найден: $code');
      return null;
    } catch (e) {
      print('❌ Ошибка проверки кода завуча: $e');
      return null;
    }
  }

  Future<void> useVicePrincipalCode(String schoolId, String code) async {
    try {
      await _firestore.collection('schools').doc(schoolId).update({
        'vicePrincipalCodes': FieldValue.arrayRemove([code]),
      });
      print('✅ Код завуча $code использован и удален');
    } catch (e) {
      print('❌ Ошибка использования кода завуча: $e');
      rethrow;
    }
  }

  Future<List<String>> getSchoolVicePrincipalCodes(String schoolId) async {
    try {
      final doc = await _firestore.collection('schools').doc(schoolId).get();
      return List<String>.from(doc.data()?['vicePrincipalCodes'] ?? []);
    } catch (e) {
      print('❌ Ошибка получения кодов завучей: $e');
      return [];
    }
  }

  //Director
  
  Future<void> createDirectorRequest({
    required String userId,
    required String fullName,
    required String schoolName,
    required String schoolAddress,
    required String email,
    required String phone,
    required String adminCode,
  }) async {
    final userExists = await verifyUserExists(userId);
    if (!userExists) {
      throw Exception('Пользователь не найден');
    }

    await _firestore.collection('admin_requests').add({
      'type': 'director_appointment',
      'applicantId': userId,
      'applicantName': fullName,
      'applicantEmail': email,
      'applicantPhone': phone,
      'schoolName': schoolName,
      'schoolAddress': schoolAddress,
      'adminCode': adminCode,
      'status': 'pending',
      'directorCode': _generateDirectorCode(),
      'applicantUserRef': 'users/$userId',
      'processedBy': null,
      'processedByRef': null,
      'processedAt': null,
      'schoolId': null,
      'schoolRef': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getPendingRequests() {
    return _firestore
        .collection('admin_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getAllRequests() {
    return _firestore
        .collection('admin_requests')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<Map<String, dynamic>> approveDirectorRequest({
    required String requestId,
    required String adminId,
    required String adminName,
  }) async {
    final requestDoc = await _firestore.collection('admin_requests').doc(requestId).get();
    
    if (!requestDoc.exists) {
      throw Exception('Заявка не найдена');
    }

    final requestData = requestDoc.data()!;
    final schoolCode = _generateSchoolCode();
    
  
    final schoolRef = await _firestore.collection('schools').add({
      'name': requestData['schoolName'],
      'address': requestData['schoolAddress'],
      'directorId': requestData['applicantId'],
      'schoolCode': schoolCode,
      'teacherCodes': [],
      'vicePrincipalCodes': [], // ДОБАВЛЯЕМ ЭТО
      'createdBy': adminId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final ChatService chatService = ChatService();
    await chatService.initializeSchoolChats(
      schoolId: schoolRef.id,
      schoolName: requestData['schoolName'],
      directorId: requestData['applicantId'],
      directorName: requestData['applicantName'],
    );

    await _firestore.collection('directors').doc(requestData['applicantId']).set({
      'uid': requestData['applicantId'],
      'fullName': requestData['applicantName'],
      'schoolId': schoolRef.id, 
      'schoolName': requestData['schoolName'],
      'email': requestData['applicantEmail'],
      'phone': requestData['applicantPhone'],
      'directorCode': requestData['directorCode'],
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _firestore.collection('admin_requests').doc(requestId).update({
      'status': 'approved',
      'processedBy': adminId,
      'processedByAdmin': adminName,
      'processedByRef': 'admins/$adminId',
      'processedAt': FieldValue.serverTimestamp(),
      'schoolId': schoolRef.id,
      'schoolCode': schoolCode,
      'schoolRef': 'schools/${schoolRef.id}',
    });

    if (requestData['applicantId'] != null) {
      await _firestore.collection('users').doc(requestData['applicantId']).update({
        'role': 'director',
        'profileComplete': true,
      });
    }

    return {
      'schoolId': schoolRef.id,
      'schoolCode': schoolCode,
      'schoolName': requestData['schoolName'],
    };
  }

  Future<void> rejectDirectorRequest({
    required String requestId,
    required String adminId,
    required String adminName,
    required String reason,
  }) async {
    await _firestore.collection('admin_requests').doc(requestId).update({
      'status': 'rejected',
      'processedBy': adminId,
      'processedByAdmin': adminName,
      'processedByRef': 'admins/$adminId', 
      'processedAt': FieldValue.serverTimestamp(),
      'rejectionReason': reason,
    });
  }

  // Teacher
  
  Future<String> generateTeacherCode(String schoolId) async {
    try {
      print('generateTeacherCode вызван с schoolId: "$schoolId"');
      
      if (schoolId.isEmpty) {
        throw Exception('School ID is empty');
      }

      final newCode = 'TCH${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      print('Сгенерирован код: $newCode');

      final schoolDoc = await _firestore.collection('schools').doc(schoolId).get();
      if (!schoolDoc.exists) {
        throw Exception('Школа с ID $schoolId не найдена');
      }

      print('Школа найдена, обновляем teacherCodes...');
      
      await _firestore.collection('schools').doc(schoolId).update({
        'teacherCodes': FieldValue.arrayUnion([newCode]),
      });

      print('Код $newCode добавлен в школу $schoolId');
      return newCode;
    } catch (e) {
      print('Ошибка в generateTeacherCode: $e');
      rethrow;
    }
  }

  Future<List<String>> getSchoolTeacherCodes(String schoolId) async {
    final doc = await _firestore.collection('schools').doc(schoolId).get();
    return List<String>.from(doc.data()?['teacherCodes'] ?? []);
  }

  Future<Map<String, dynamic>?> verifyTeacherCode(String code) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .where('teacherCodes', arrayContains: code)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final school = snapshot.docs.first;
        return {
          'schoolId': school.id,
          'schoolName': school.data()['name'],
          'isValid': true,
        };
      }
      return null;
    } catch (e) {
      print('Ошибка проверки кода учителя: $e');
      return null;
    }
  }

  Future<void> useTeacherCode(String schoolId, String code) async {
    await _firestore.collection('schools').doc(schoolId).update({
      'teacherCodes': FieldValue.arrayRemove([code]),
    });
  }

  Future<void> revokeTeacherCode(String schoolId, String code) async {
    await _firestore.collection('schools').doc(schoolId).update({
      'teacherCodes': FieldValue.arrayRemove([code]),
    });
  }

  Future<void> revokeVicePrincipalCode(String schoolId, String code) async {
    await _firestore.collection('schools').doc(schoolId).update({
      'vicePrincipalCodes': FieldValue.arrayRemove([code]),
    });
  }

  // Student
  
  Future<Map<String, dynamic>?> verifyClassCode(String code) async {
  try {
    final snapshot = await _firestore
        .collection('classes')
        .where('classCode', isEqualTo: code)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final classDoc = snapshot.docs.first;
      final classData = classDoc.data();
      
      // Получаем информацию о школе
      final schoolDoc = await _firestore
          .collection('schools')
          .doc(classData['schoolId'])
          .get();
      
      return {
        'classId': classDoc.id,
        'className': classData['name'],
        'schoolId': classData['schoolId'],
        'schoolName': schoolDoc.data()?['name'] ?? 'Школа',
        'teacherId': classData['teacherId'],
        'isValid': true,
      };
    }
    return null;
  } catch (e) {
    print('Ошибка проверки кода класса: $e');
    return null;
  }
}

  Future<String> generateClassCode(String classId) async {
  final newCode = 'CLS${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  
  // Сохраняем код в документе класса
  await _firestore.collection('classes').doc(classId).update({
    'classCode': newCode, // ← ОДИН код на весь класс
    'classCodeGeneratedAt': FieldValue.serverTimestamp(),
    'classCodeGeneratedBy': 'teacher',
  });
  
  return newCode;
}


  Future<void> useClassCode(String classId, String code) async {
  await _firestore.collection('class_code_usage').add({
    'classId': classId,
    'code': code,
    'usedAt': FieldValue.serverTimestamp(),
  });
}

  
  Future<bool> verifyUserExists(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.exists;
    } catch (e) {
      print('Ошибка проверки пользователя: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      print('Загрузка статистики...');
      
      final futures = await Future.wait([
        _firestore.collection('schools').get(),
        _firestore.collection('admin_requests').where('status', isEqualTo: 'pending').get(),
        _firestore.collection('admin_requests').get(),
        _firestore.collection('admin_codes').where('used', isEqualTo: false).get(),
        _firestore.collection('users').get(),
        _firestore.collection('directors').where('schoolId', isNull: false).get(),
      ]);

      final schoolsSnapshot = futures[0] as QuerySnapshot;
      final pendingRequestsSnapshot = futures[1] as QuerySnapshot;
      final allRequestsSnapshot = futures[2] as QuerySnapshot;
      final adminCodesSnapshot = futures[3] as QuerySnapshot;
      final usersSnapshot = futures[4] as QuerySnapshot;
      final directorsWithSchoolSnapshot = futures[5] as QuerySnapshot;

      final now = DateTime.now();
      final activeCodes = adminCodesSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final expiresAt = data['expiresAt'] as Timestamp?;
        return expiresAt != null && expiresAt.toDate().isAfter(now);
      }).length;

      final usersByRole = {
        'admin': 0,
        'director': 0,
        'vice_principal': 0, 
        'teacher': 0,
        'student': 0,
        'parent': 0,
      };

      for (final doc in usersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final role = data['role'];
        if (role != null && usersByRole.containsKey(role)) {
          usersByRole[role] = usersByRole[role]! + 1;
        }
      }

      final stats = {
        'schoolsCount': schoolsSnapshot.size,
        'pendingRequests': pendingRequestsSnapshot.size,
        'totalRequests': allRequestsSnapshot.size,
        'activeAdminCodes': activeCodes,
        'totalUsers': usersSnapshot.size,
        'directorsWithSchool': directorsWithSchoolSnapshot.size, 
        'usersByRole': usersByRole,
      };

      print('Статистика загружена: $stats');
      return stats;
    } catch (e) {
      print('Ошибка загрузки статистики: $e');
      return {
        'schoolsCount': 0,
        'pendingRequests': 0,
        'totalRequests': 0,
        'activeAdminCodes': 0,
        'totalUsers': 0,
        'directorsWithSchool': 0,
        'usersByRole': {
          'admin': 0,
          'director': 0,
          'vice_principal': 0,
          'teacher': 0,
          'student': 0,
          'parent': 0,
        },
      };
    }
  }

  String _generateDirectorCode() => 'DIR${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  String _generateSchoolCode() => 'SCH${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
}