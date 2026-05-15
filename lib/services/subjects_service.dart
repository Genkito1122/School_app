import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubjectsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== ПРЕДМЕТЫ ШКОЛЫ ====================

  // Создать предмет для школы
  Future<String> createSubject({
    required String schoolId,
    required String subjectName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Пользователь не авторизован');

    // Проверяем, не существует ли уже такой предмет
    final existing = await _firestore
        .collection('school_subjects')
        .where('schoolId', isEqualTo: schoolId)
        .where('name', isEqualTo: subjectName)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('Предмет "$subjectName" уже существует в школе');
    }

    final subjectRef = _firestore.collection('school_subjects').doc();
    
    await subjectRef.set({
      'subjectId': subjectRef.id,
      'name': subjectName,
      'schoolId': schoolId,
      'createdBy': user.uid,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return subjectRef.id;
  }

  // Получить все предметы школы
   Future<List<Map<String, dynamic>>> getSchoolSubjects(String schoolId) async {
  try {
    print('🔍 Поиск предметов для школы: $schoolId');
    
    // Способ 1: Без orderBy (чтобы избежать ошибки индекса)
    final snapshot = await _firestore
        .collection('school_subjects')
        .where('schoolId', isEqualTo: schoolId)
        .where('isActive', isEqualTo: true)
        .get();

    print('Найдено предметов: ${snapshot.docs.length}');
    
    // Собираем и сортируем на клиенте
    final subjects = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'subjectId': doc.id,
        ...data,
      };
    }).toList();
    
    // Сортировка по имени
    subjects.sort((a, b) {
      final nameA = a['name']?.toString() ?? '';
      final nameB = b['name']?.toString() ?? '';
      return nameA.compareTo(nameB);
    });
    
    // Логируем найденные предметы
    for (final subject in subjects) {
      print(' Найден предмет: ${subject['name']}');
    }
    
    return subjects;
    
  } catch (e) {
    print('❌ Ошибка загрузки предметов: $e');
    
    // Способ 2: Запасной вариант - загрузить все и отфильтровать
    try {
      print('Пробуем запасной способ загрузки...');
      final allSnapshot = await _firestore
          .collection('school_subjects')
          .get();
      
      final filteredSubjects = allSnapshot.docs
          .where((doc) {
            final data = doc.data();
            return data['schoolId'] == schoolId && 
                   (data['isActive'] ?? true) == true;
          })
          .map((doc) {
            final data = doc.data();
            return {
              'subjectId': doc.id,
              ...data,
            };
          })
          .toList();
      
      filteredSubjects.sort((a, b) {
        final nameA = a['name']?.toString() ?? '';
        final nameB = b['name']?.toString() ?? '';
        return nameA.compareTo(nameB);
      });
      
      print('Запасной способ: найдено ${filteredSubjects.length} предметов');
      return filteredSubjects;
      
    } catch (e2) {
      print('Запасной способ тоже не сработал: $e2');
      return [];
    }
  }
}

  // Обновить предмет
  Future<void> updateSubject({
    required String subjectId,
    required String newName,
  }) async {
    await _firestore.collection('school_subjects').doc(subjectId).update({
      'name': newName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Удалить предмет (деактивировать)
  Future<void> deleteSubject(String subjectId) async {
    await _firestore.collection('school_subjects').doc(subjectId).update({
      'isActive': false,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== НАЗНАЧЕНИЕ УЧИТЕЛЕЙ ====================

  // Назначить учителя на предмет
  Future<void> assignTeacherToSubject({
    required String subjectId,
    required String teacherId,
    required String schoolId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Пользователь не авторизован');

    // Проверяем, не назначен ли уже этот учитель
    final existing = await _firestore
        .collection('teacher_subject_assignments')
        .where('subjectId', isEqualTo: subjectId)
        .where('teacherId', isEqualTo: teacherId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('Учитель уже назначен на этот предмет');
    }

    final assignmentRef = _firestore.collection('teacher_subject_assignments').doc();
    
    await assignmentRef.set({
      'assignmentId': assignmentRef.id,
      'subjectId': subjectId,
      'teacherId': teacherId,
      'schoolId': schoolId,
      'assignedBy': user.uid,
      'isActive': true,
      'assignedAt': FieldValue.serverTimestamp(),
    });
  }

  // Удалить назначение учителя
  Future<void> removeTeacherFromSubject(String assignmentId) async {
    await _firestore.collection('teacher_subject_assignments').doc(assignmentId).update({
      'isActive': false,
      'removedAt': FieldValue.serverTimestamp(),
    });
  }

  // Получить учителей предмета
  Future<List<Map<String, dynamic>>> getSubjectTeachers(String subjectId) async {
    final snapshot = await _firestore
        .collection('teacher_subject_assignments')
        .where('subjectId', isEqualTo: subjectId)
        .where('isActive', isEqualTo: true)
        .get();

    final List<Map<String, dynamic>> result = [];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final teacherId = data['teacherId'];
      
      // Получаем информацию об учителе
      final teacherDoc = await _firestore.collection('teachers').doc(teacherId).get();
      if (teacherDoc.exists) {
        final teacherData = teacherDoc.data();
        result.add({
          'assignmentId': doc.id,
          'subjectId': subjectId,
          'teacherId': teacherId,
          'teacherName': teacherData?['fullName'] ?? 'Неизвестно',
          'teacherEmail': teacherData?['email'] ?? '',
          'assignedAt': data['assignedAt'],
        });
      }
    }

    return result;
  }

  // Получить предметы учителя
  Future<List<Map<String, dynamic>>> getTeacherSubjects(String teacherId) async {
    final snapshot = await _firestore
        .collection('teacher_subject_assignments')
        .where('teacherId', isEqualTo: teacherId)
        .where('isActive', isEqualTo: true)
        .get();

    final List<Map<String, dynamic>> result = [];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final subjectId = data['subjectId'];
      
      // Получаем информацию о предмете
      final subjectDoc = await _firestore.collection('school_subjects').doc(subjectId).get();
      if (subjectDoc.exists) {
        final subjectData = subjectDoc.data();
        result.add({
          'assignmentId': doc.id,
          'subjectId': subjectId,
          'subjectName': subjectData?['name'] ?? 'Неизвестно',
          'assignedAt': data['assignedAt'],
        });
      }
    }

    return result;
  }

  // Получить доступных учителей для предмета (тех, кто еще не назначен)
  Future<List<Map<String, dynamic>>> getAvailableTeachersForSubject(
    String schoolId, 
    String subjectId
  ) async {
    // 1. Получаем всех учителей школы
    final allTeachersSnapshot = await _firestore
        .collection('teachers')
        .where('schoolId', isEqualTo: schoolId)
        .get();

    // 2. Получаем уже назначенных учителей
    final assignedSnapshot = await _firestore
        .collection('teacher_subject_assignments')
        .where('subjectId', isEqualTo: subjectId)
        .where('isActive', isEqualTo: true)
        .get();

    final assignedTeacherIds = assignedSnapshot.docs
        .map((doc) => doc.data()['teacherId'] as String)
        .toSet();

    // 3. Фильтруем
    final List<Map<String, dynamic>> availableTeachers = [];

    for (final doc in allTeachersSnapshot.docs) {
      final teacherId = doc.id;
      if (!assignedTeacherIds.contains(teacherId)) {
        final data = doc.data();
        availableTeachers.add({
          'teacherId': teacherId,
          'fullName': data['fullName'] ?? 'Неизвестно',
          'email': data['email'] ?? '',
        });
      }
    }

    return availableTeachers;
  }

  // Получить предметы для расписания (предмет + учителя)
  Future<List<Map<String, dynamic>>> getSubjectsForSchedule(String schoolId) async {
    final subjects = await getSchoolSubjects(schoolId);
    final List<Map<String, dynamic>> result = [];

    for (final subject in subjects) {
      final teachers = await getSubjectTeachers(subject['subjectId']);
      
      result.add({
        'subjectId': subject['subjectId'],
        'subjectName': subject['name'],
        'teachers': teachers,
      });
    }

    return result;
  }

  // Получить учителя по предмету и классу (для расписания)
  Future<Map<String, dynamic>?> getTeacherForClassSubject(
    String classId, 
    String subjectId
  ) async {
    // Пока возвращаем первого учителя предмета
    final teachers = await getSubjectTeachers(subjectId);
    if (teachers.isNotEmpty) {
      return teachers.first;
    }
    return null;
  }
}