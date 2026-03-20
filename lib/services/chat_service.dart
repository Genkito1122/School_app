import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> createOrUpdateTeachersChat(String schoolId) async {
    try {
      print('🔄 Создание/обновление чата учителей для школы: $schoolId');

      final schoolDoc = await _firestore.collection('schools').doc(schoolId).get();
      if (!schoolDoc.exists) {
        print('❌ Школа не найдена: $schoolId');
        return;
      }

      final schoolData = schoolDoc.data()!;
      final schoolName = schoolData['name'];
      final directorId = schoolData['directorId'];

      final directorDoc = await _firestore.collection('directors').doc(directorId).get();
      final directorName = directorDoc.data()?['fullName'] ?? 'Директор';

      final teachersSnapshot = await _firestore
          .collection('teachers')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      final teacherIds = teachersSnapshot.docs.map((doc) => doc.id).toList();
      final allParticipants = [directorId, ...teacherIds];
      
      final participantNames = {
        directorId: directorName,
      };

      for (final teacherDoc in teachersSnapshot.docs) {
        final teacherData = teacherDoc.data();
        participantNames[teacherDoc.id] = teacherData['fullName'] ?? 'Учитель';
      }

      final chatId = 'teachers_$schoolId';

      await _firestore.collection('chats').doc(chatId).set({
        'chatId': chatId,
        'type': 'teachers',
        'name': 'Чат учителей $schoolName',
        'schoolId': schoolId,
        'participants': allParticipants,
        'participantNames': participantNames,
        'lastMessage': 'Чат учителей создан',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Чат учителей создан/обновлен: $chatId');
      print('👥 Участники: ${allParticipants.length} человек');
      
    } catch (e) {
      print('❌ Ошибка создания чата учителей: $e');
    }
  }


  Future<void> updateTeachersChatOnNewTeacher(String schoolId, String teacherId, String teacherName) async {
    try {
      print('🔄 Обновление чата учителей для нового учителя: $teacherName');

      final chatId = 'teachers_$schoolId';

      await _firestore.collection('chats').doc(chatId).update({
        'participants': FieldValue.arrayUnion([teacherId]),
        'participantNames.$teacherId': teacherName,
      });

      print('✅ Учитель $teacherName добавлен в чат учителей');
      
    } catch (e) {
      print('❌ Ошибка добавления учителя в чат: $e');
      await createOrUpdateTeachersChat(schoolId);
    }
  }

  Future<void> initializeSchoolChats({
    required String schoolId,
    required String schoolName,
    required String directorId,
    required String directorName,
  }) async {
    try {
      print('🔄 Инициализация всех чатов для школы: $schoolName');

      await createOrUpdateTeachersChat(schoolId);

      print('✅ Все чаты созданы для школы $schoolName');
    } catch (e) {
      print('❌ Ошибка инициализации чатов: $e');
    }
  }


  Future<void> sendAnnouncement({
  required String schoolId,
  required String text,
  required String senderName,
  required String senderRole,
  required List<String> targetChatTypes,
}) async {
  try {
    print('📢 Отправка объявления в школы: $schoolId');
    print('🎯 Цели: $targetChatTypes');

    final user = _auth.currentUser;
    if (user == null) return;

    final messageRef = _firestore.collection('messages').doc();
    await messageRef.set({
      'messageId': messageRef.id,
      'type': 'announcement',
      'schoolId': schoolId,
      'text': text,
      'senderId': user.uid,
      'senderName': senderName,
      'senderRole': senderRole,
      'isAnnouncement': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (targetChatTypes.contains('all') || targetChatTypes.contains('teachers')) {
      await _sendToTeachersChat(schoolId, text, senderName, senderRole);
    }

    if (targetChatTypes.contains('all') || targetChatTypes.contains('class')) {
      await _sendToAllClassChats(schoolId, text, senderName, senderRole);
    }

    print('✅ Объявление отправлено и сохранено в историю');
    
  } catch (e) {
    print('❌ Ошибка отправки объявления: $e');
    throw Exception('Не удалось отправить объявление');
  }
}

  Future<void> _sendToTeachersChat(
    String schoolId, 
    String text, 
    String senderName, 
    String senderRole
  ) async {
    try {
      final teachersChatId = 'teachers_$schoolId';
      
      await sendMessage(
        chatId: teachersChatId,
        text: text,
        senderName: senderName,
        senderRole: senderRole,
        isAnnouncement: true,
      );
      
      print('✅ Объявление отправлено в чат учителей');
    } catch (e) {
      print('❌ Ошибка отправки в чат учителей: $e');
    }
  }

  Future<void> _sendToAllClassChats(
    String schoolId, 
    String text, 
    String senderName, 
    String senderRole
  ) async {
    try {
      final classesSnapshot = await _firestore
          .collection('classes')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      int sentCount = 0;

      for (final classDoc in classesSnapshot.docs) {
        final classId = classDoc.id;
        
        final chatSnapshot = await _firestore
            .collection('chats')
            .where('classId', isEqualTo: classId)
            .where('type', isEqualTo: 'class')
            .limit(1)
            .get();

        if (chatSnapshot.docs.isNotEmpty) {
          final chatId = chatSnapshot.docs.first.id;
          
          await sendMessage(
            chatId: chatId,
            text: text,
            senderName: senderName,
            senderRole: senderRole,
            isAnnouncement: true,
          );
          
          sentCount++;
          print('✅ Объявление отправлено в класс: $classId');
        }
      }

      print('✅ Объявление разослано в $sentCount классных чатов');
      
    } catch (e) {
      print('❌ Ошибка рассылки по классам: $e');
    }
  }

  Stream<QuerySnapshot> getAnnouncementsHistory(String schoolId) {
  print('🔍 Загрузка истории объявлений для школы: $schoolId');
  
  return _firestore
      .collection('messages')
      .where('schoolId', isEqualTo: schoolId)
      .where('isAnnouncement', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .snapshots();
}


  Future<void> addStudentToClassChat({
    required String classId,
    required String studentId,
    required String studentName,
  }) async {
    try {
      print('🔄 Добавление ученика $studentName в чат класса');

      // Ищем классный чат
      final chatSnapshot = await _firestore
          .collection('chats')
          .where('classId', isEqualTo: classId)
          .where('type', isEqualTo: 'class')
          .limit(1)
          .get();

      if (chatSnapshot.docs.isNotEmpty) {
        final chatId = chatSnapshot.docs.first.id;
        
        await _firestore.collection('chats').doc(chatId).update({
          'participants': FieldValue.arrayUnion([studentId]),
          'participantNames.$studentId': studentName,
        });

        print('✅ Ученик $studentName добавлен в классный чат $classId');
      } else {
        print('⚠️ Классный чат не найден для classId: $classId');
      }
    } catch (e) {
      print('❌ Ошибка добавления ученика в чат: $e');
    }
  }


  Future<void> createClassChat({
    required String className,
    required String classId,
    required String schoolId,
    required String teacherId,
    required String teacherName,
  }) async {
    try {
      final chatId = 'class_${classId}_${DateTime.now().millisecondsSinceEpoch}';

      await _firestore.collection('chats').doc(chatId).set({
        'chatId': chatId,
        'type': 'class',
        'name': 'Класс $className',
        'schoolId': schoolId,
        'classId': classId,
        'teacherId': teacherId,
        'participants': [teacherId],
        'participantNames': {
          teacherId: teacherName,
        },
        'lastMessage': 'Чат класса создан',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Классный чат создан: $className');
    } catch (e) {
      print('❌ Ошибка создания классного чата: $e');
      throw Exception('Не удалось создать чат класса');
    }
  }


  Stream<QuerySnapshot> getUserChats() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: user.uid)
        .snapshots();
  }

  Stream<QuerySnapshot> getChatMessages(String chatId) {
    return _firestore
        .collection('messages')
        .where('chatId', isEqualTo: chatId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> sendMessage({
  required String chatId,
  required String text,
  required String senderName,
  required String senderRole,
  String type = 'text',
  bool isAnnouncement = false,
  String? fileUrl,
  String? fileName,
}) async {
  final user = _auth.currentUser;
  if (user == null) {
    print('❌ Пользователь не авторизован');
    return;
  }

  print('🔄 Отправка сообщения в чат: $chatId');
  print('📝 Текст: $text');
  print('👤 Отправитель: $senderName ($senderRole)');

  try {
    final messageRef = _firestore.collection('messages').doc();
    final messageData = {
      'messageId': messageRef.id,
      'chatId': chatId,
      'senderId': user.uid,
      'senderName': senderName,
      'senderRole': senderRole,
      'text': text,
      'type': type,
      'isAnnouncement': isAnnouncement,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await messageRef.set(messageData);
    print('✅ Сообщение отправлено с ID: ${messageRef.id}');

    String lastMessageText = text;
    if (type == 'file') {
      lastMessageText = '📎 $fileName'; // Красивое отображение в списке чатов
    } else if (isAnnouncement) {
      lastMessageText = '📢 $text';
    }

    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': lastMessageText,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
    print('✅ Чат обновлен');

  } catch (e) {
    print('❌ Ошибка отправки сообщения: $e');
    rethrow;
  }
}

Future<void> sendFileMessage({
    required String chatId,
    required String senderName,
    required String senderRole,
  }) async {
    try {
      // 1. Выбираем файл
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String fileName = result.files.single.name;
        
        // 2. Формируем путь в Storage
        String path = 'chats/$chatId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
        
        // 3. Загружаем
        UploadTask uploadTask = _storage.ref(path).putFile(file);
        TaskSnapshot snapshot = await uploadTask;
        
        // 4. Получаем ссылку на скачивание
        String downloadUrl = await snapshot.ref.getDownloadURL();

        // 5. Отправляем сообщение в чат, используя твой существующий sendMessage
        await sendMessage(
          chatId: chatId,
          text: 'Файл: $fileName', // Текст, который увидит юзер
          senderName: senderName,
          senderRole: senderRole,
          type: 'file',
          fileUrl: downloadUrl,
          fileName: fileName,
        );
      }
    } catch (e) {
      print('❌ Ошибка при работе с файлом: $e');
    }
  }

  Future<bool> canUserWriteToChat(String chatId) async {
  final user = _auth.currentUser;
  if (user == null) return false;

  final chatDoc = await _firestore.collection('chats').doc(chatId).get();
  if (!chatDoc.exists) return false;

  final chatData = chatDoc.data()!;
  final userRole = await _getUserRole();

  switch (chatData['type']) {
    case 'announcement':
      return userRole == 'director' || userRole == 'vice_principal'; 
    case 'teachers':
      return userRole == 'director' || userRole == 'teacher' || userRole == 'vice_principal';
    case 'class':
    case 'personal':
      return chatData['participants'].contains(user.uid);
    default:
      return false;
  }
}


  Future<String?> _getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    return userDoc.data()?['role'];
  }

  Future<Map<String, String>> getUserInfoForMessage() async {
    final user = _auth.currentUser;
    if (user == null) return {'name': '', 'role': ''};

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    final role = userData?['role'] ?? '';

    String fullName = '';
    switch (role) {
      case 'student':
        final studentDoc = await _firestore.collection('students').doc(user.uid).get();
        fullName = studentDoc.data()?['fullName'] ?? '';
        break;
      case 'teacher':
        final teacherDoc = await _firestore.collection('teachers').doc(user.uid).get();
        fullName = teacherDoc.data()?['fullName'] ?? '';
        break;
      case 'director':
        final directorDoc = await _firestore.collection('directors').doc(user.uid).get();
        fullName = directorDoc.data()?['fullName'] ?? '';
        break;
      default:
        fullName = 'Пользователь';
    }

    return {'name': fullName, 'role': role};
  }

  String getChatDisplayName(Map<String, dynamic> chatData, String currentUserId) {
    if (chatData['type'] == 'personal') {
      final participants = Map<String, String>.from(chatData['participantNames'] ?? {});
      for (final entry in participants.entries) {
        if (entry.key != currentUserId) {
          return entry.value;
        }
      }
    }
    
    return chatData['name'] ?? 'Без названия';
  }

  IconData getChatIcon(String chatType) {
    switch (chatType) {
      case 'class': return Icons.group;
      case 'teachers': return Icons.school;
      case 'personal': return Icons.person;
      case 'announcement': return Icons.campaign;
      default: return Icons.chat;
    }
  }

  Future<Map<String, dynamic>?> getChildData(String parentId) async {
  try {
    final parentDoc = await _firestore.collection('parents').doc(parentId).get();
    if (!parentDoc.exists) return null;

    final parentData = parentDoc.data()!;
    final childIds = List<String>.from(parentData['childIds'] ?? []);

    if (childIds.isEmpty) return null;

    final childDoc = await _firestore.collection('students').doc(childIds.first).get();
    if (!childDoc.exists) return null;

    final childData = childDoc.data()!;
    
    return {
      'childId': childIds.first,
      'childName': childData['fullName'],
      'className': childData['className'],
      'classId': childData['classId'],
      'schoolId': childData['schoolId'],
      'birthDate': childData['birthDate'],
    };
  } catch (e) {
    print('Ошибка получения данных ребенка: $e');
    return null;
  }
 }

 Future<String?> getChildClassChatId(String childId) async {
  try {
    final childDoc = await _firestore.collection('students').doc(childId).get();
    if (!childDoc.exists) return null;

    final childData = childDoc.data()!;
    final classId = childData['classId'];

    final chatSnapshot = await _firestore
        .collection('chats')
        .where('classId', isEqualTo: classId)
        .where('type', isEqualTo: 'class')
        .limit(1)
        .get();

    if (chatSnapshot.docs.isNotEmpty) {
      return chatSnapshot.docs.first.id;
    }
    return null;
  } catch (e) {
    print('Ошибка поиска классного чата: $e');
    return null;
  }
 }
}