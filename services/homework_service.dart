import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeworkService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== СОЗДАНИЕ И УПРАВЛЕНИЕ ДЗ ====================

  // Создать ДЗ
  Future<String> createHomework({
    required String classId,
    required String className,
    required String subjectId,
    required String subjectName,
    required String title,
    required String description,
    required DateTime deadline,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Пользователь не авторизован');

    final teacherDoc = await _firestore.collection('teachers').doc(user.uid).get();
    final teacherName = teacherDoc.data()?['fullName'] ?? 'Учитель';

    final homeworkRef = _firestore.collection('homeworks').doc();
    
    await homeworkRef.set({
      'homeworkId': homeworkRef.id,
      'classId': classId,
      'className': className,
      'subjectId': subjectId,
      'subjectName': subjectName,
      'teacherId': user.uid,
      'teacherName': teacherName,
      'title': title,
      'description': description,
      'deadline': Timestamp.fromDate(deadline),
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return homeworkRef.id;
  }

  // Получить ДЗ учителя
  Future<List<Map<String, dynamic>>> getTeacherHomeworks() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('homeworks')
        .where('teacherId', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .orderBy('deadline')
        .get();

    return _processHomeworks(snapshot);
  }

  // Получить активные ДЗ класса
  Future<List<Map<String, dynamic>>> getClassActiveHomeworks(String classId) async {
  try {
    print('🔄 Получение активных ДЗ для класса: $classId');
    
    final now = Timestamp.now();
    
    final snapshot = await _firestore
        .collection('homeworks')
        .where('classId', isEqualTo: classId)
        .where('isActive', isEqualTo: true)
        .where('deadline', isGreaterThanOrEqualTo: now) // Только не просроченные
        .orderBy('deadline')
        .get();

    print('📄 Найдено ДЗ: ${snapshot.docs.length}');
    
    for (final doc in snapshot.docs) {
      print('📝 ДЗ: ${doc.id} - ${doc.data()['title']}');
    }
    
    return _processHomeworks(snapshot);
  } catch (e) {
    print('❌ Ошибка получения ДЗ класса: $e');
    return [];
  }
}

  // Получить все ДЗ ученика (по его классу)
  Future<List<Map<String, dynamic>>> getStudentHomeworks(String studentId) async {
  try {
    print('🔄 HomeworkService.getStudentHomeworks для ученика: $studentId');
    
    // 1. Получаем данные ученика
    final studentDoc = await _firestore.collection('students').doc(studentId).get();
    
    if (!studentDoc.exists) {
      print('❌ Ученик $studentId не найден в Firestore');
      return [];
    }
    
    final studentData = studentDoc.data()!;
    final classId = studentData['classId'] as String?;
    
    if (classId == null || classId.isEmpty) {
      print('❌ У ученика $studentId нет classId или он пустой');
      print('   Данные ученика: $studentData');
      return [];
    }
    
    print('✅ Найден ученик: ${studentData['fullName']}');
    print('✅ Класс ученика: $classId (${studentData['className']})');
    
    // 2. Запрос ДЗ этого класса
    print('🔍 Ищем ДЗ для classId: $classId');
    
    final snapshot = await _firestore
        .collection('homeworks')
        .where('classId', isEqualTo: classId)
        .where('isActive', isEqualTo: true)
        .get();
    
    print('📄 Найдено ДЗ для класса $classId: ${snapshot.docs.length}');
    
    if (snapshot.docs.isEmpty) {
      // Проверим, есть ли вообще ДЗ с этим classId
      final debugQuery = await _firestore
          .collection('homeworks')
          .where('classId', isEqualTo: classId)
          .get();
      
      print('🔍 ДЗ без фильтра isActive: ${debugQuery.docs.length}');
      for (var doc in debugQuery.docs) {
        print('   📦 ${doc.id}: isActive=${doc.data()['isActive']}, title=${doc.data()['title']}');
      }
    }
    
    // 3. Обработка результатов
    final now = DateTime.now();
    final List<Map<String, dynamic>> result = [];
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final deadline = data['deadline'] as Timestamp?;
      
      if (deadline == null) {
        print('⚠️ У ДЗ ${doc.id} нет дедлайна');
        continue;
      }
      
      final deadlineDate = deadline.toDate();
      final isOverdue = deadlineDate.isBefore(now);
      final difference = deadlineDate.difference(now);
      final daysLeft = isOverdue ? 0 : (difference.inDays + 1);
      
      result.add({
        'homeworkId': doc.id,
        ...data,
        'isOverdue': isOverdue,
        'daysLeft': daysLeft,
      });
      
      print('   ✅ Добавлено ДЗ: ${data['title']}');
    }
    
    print('🎉 Итог: возвращаем ${result.length} ДЗ');
    return result;
    
  } catch (e) {
    print('❌ Критическая ошибка в getStudentHomeworks: $e');
    print('Stack trace: ${e.toString()}');
    return [];
  }
}

  // Получить ДЗ по предмету
  Future<List<Map<String, dynamic>>> getHomeworksBySubject(
    String classId, 
    String subjectId
  ) async {
    final now = Timestamp.now();
    
    final snapshot = await _firestore
        .collection('homeworks')
        .where('classId', isEqualTo: classId)
        .where('subjectId', isEqualTo: subjectId)
        .where('isActive', isEqualTo: true)
        .where('deadline', isGreaterThanOrEqualTo: now)
        .orderBy('deadline')
        .get();

    return _processHomeworks(snapshot);
  }

  // Удалить ДЗ
  Future<void> deleteHomework(String homeworkId) async {
    await _firestore.collection('homeworks').doc(homeworkId).update({
      'isActive': false,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  // Автоматически деактивировать просроченные ДЗ
  Future<void> deactivateExpiredHomeworks() async {
    final now = Timestamp.now();
    
    final snapshot = await _firestore
        .collection('homeworks')
        .where('isActive', isEqualTo: true)
        .where('deadline', isLessThan: now)
        .get();

    final batch = _firestore.batch();
    
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'isActive': false,
        'expiredAt': FieldValue.serverTimestamp(),
      });
    }

    if (snapshot.docs.isNotEmpty) {
      await batch.commit();
      print('✅ Деактивировано ${snapshot.docs.length} просроченных ДЗ');
    }
  }

  // Получить статистику по ДЗ
  Future<Map<String, dynamic>> getHomeworkStats(String classId) async {
    final now = Timestamp.now();
    
    final activeSnapshot = await _firestore
        .collection('homeworks')
        .where('classId', isEqualTo: classId)
        .where('isActive', isEqualTo: true)
        .where('deadline', isGreaterThanOrEqualTo: now)
        .get();

    final totalSnapshot = await _firestore
        .collection('homeworks')
        .where('classId', isEqualTo: classId)
        .where('isActive', isEqualTo: false)
        .get();

    return {
      'active': activeSnapshot.docs.length,
      'total': activeSnapshot.docs.length + totalSnapshot.docs.length,
      'expired': totalSnapshot.docs.length,
    };
  }

  // ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================

  List<Map<String, dynamic>> _processHomeworks(QuerySnapshot snapshot) {
  final now = DateTime.now();
  
  return snapshot.docs.map((doc) {
    final data = doc.data() as Map<String, dynamic>;
    final deadline = data['deadline'] as Timestamp?;
    
    // Если deadline нет, пропускаем
    if (deadline == null) return null;
    
    final deadlineDate = deadline.toDate();
    final isOverdue = deadlineDate.isBefore(now);
    final difference = deadlineDate.difference(now);
    
    return {
      'homeworkId': doc.id,
      ...data,
      'isOverdue': isOverdue,
      'daysLeft': isOverdue ? 0 : (difference.inDays + 1), // Отрицательные дни не показываем
    };
  }).where((item) => item != null).cast<Map<String, dynamic>>().toList();
 }

  int _calculateDaysLeft(Timestamp deadline) {
    final now = DateTime.now();
    final deadlineDate = deadline.toDate();
    final difference = deadlineDate.difference(now);
    
    return difference.inDays + 1; // +1 чтобы сегодняшний день считался как 1 день
  }

  // Получить предметы учителя (для выпадающего списка)
  Future<List<Map<String, dynamic>>> getTeacherSubjectsForHomework() async {
  final user = _auth.currentUser;
  if (user == null) return [];

  // 1. Получаем ID учителя
  final teacherId = user.uid;

  // 2. Получаем классы учителя
  final teacherDoc = await _firestore.collection('teachers').doc(teacherId).get();
  if (!teacherDoc.exists) return [];

  final teacherData = teacherDoc.data()!;
  final classIds = List<String>.from(teacherData['classIds'] ?? []);
  final teacherName = teacherData['fullName'] ?? 'Учитель';

  if (classIds.isEmpty) return [];

  // 3. Получаем предметы из расписания этих классов
  final subjectsSet = <String, Map<String, dynamic>>{};

  for (final classId in classIds) {
    final scheduleDoc = await _firestore.collection('schedules').doc(classId).get();
    if (!scheduleDoc.exists) continue;

    final data = scheduleDoc.data()!;
    final days = data['days'] as List<dynamic>? ?? [];

    for (final day in days) {
      final lessons = day['lessons'] as List<dynamic>? ?? [];
      for (final lesson in lessons) {
        final subject = lesson['subject']?.toString() ?? '';
        final subjectId = lesson['subjectId']?.toString() ?? '';
        final lessonTeacherId = lesson['teacherId']?.toString() ?? '';

        // Сравниваем с ID текущего учителя
        if (subject.isNotEmpty && 
            subjectId.isNotEmpty && 
            lessonTeacherId == teacherId && 
            !subjectsSet.containsKey(subjectId)) {
          
          // Получаем название класса
          final classDoc = await _firestore.collection('classes').doc(classId).get();
          final className = classDoc.data()?['name'] ?? 'Неизвестно';

          subjectsSet[subjectId] = {
            'subjectId': subjectId,
            'subjectName': subject,
            'classId': classId,
            'className': className,
            'teacherId': teacherId,
            'teacherName': teacherName,
          };
        }
      }
    }
  }

  return subjectsSet.values.toList();
 }
}