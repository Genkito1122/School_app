import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_app/services/chat_service.dart';
import 'package:school_app/pages/schedule_editor_page.dart';
import 'package:school_app/pages/announcement_page.dart';
import 'package:school_app/pages/chat_detail_page.dart';
import 'package:school_app/services/subjects_service.dart';
import 'package:school_app/pages/subject_manager_page.dart';

class VicePrincipalPanel extends StatefulWidget {
  const VicePrincipalPanel({super.key});

  @override
  State<VicePrincipalPanel> createState() => _VicePrincipalPanelState();
}

class _VicePrincipalPanelState extends State<VicePrincipalPanel> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Map<String, dynamic>? _vicePrincipalData;
  Map<String, dynamic>? _schoolData;
  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _classes = [];
  
  int _currentTab = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVicePrincipalData();
  }

  Future<void> _loadVicePrincipalData() async {
    if (_currentUser == null) return;

    try {
      final vicePrincipalDoc = await _firestore
          .collection('vice_principals')
          .doc(_currentUser.uid)
          .get();

      if (vicePrincipalDoc.exists) {
        final data = vicePrincipalDoc.data();
        
        setState(() {
          _vicePrincipalData = data;
        });
        
        final schoolId = data?['schoolId'];
        
        if (schoolId != null) {
          await _loadSchoolData(schoolId);
        }
      }
    } catch (e) {
      print('❌ Ошибка загрузки данных завуча: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSchoolData(String schoolId) async {
    try {
      final schoolDoc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .get();

      if (schoolDoc.exists) {
        final schoolData = schoolDoc.data();
        
        setState(() {
          _schoolData = {
            ...?schoolData, 
            'schoolId': schoolDoc.id, 
          };
        });
        
        await _loadTeachers(schoolId);
        await _loadClasses(schoolId);
      }
    } catch (e) {
      print('❌ Ошибка загрузки школы: $e');
    }
  }

  Future<void> _loadTeachers(String schoolId) async {
    final teachersSnapshot = await _firestore
        .collection('teachers')
        .where('schoolId', isEqualTo: schoolId)
        .get();

    setState(() {
      _teachers = teachersSnapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> _loadClasses(String schoolId) async {
    final classesSnapshot = await _firestore
        .collection('classes')
        .where('schoolId', isEqualTo: schoolId)
        .get();

    setState(() {
      _classes = classesSnapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Заголовок
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.purple,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Панель завуча',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _schoolData?['name'] ?? 'Загрузка...',
                  style: const TextStyle(color: Colors.white70),
                ),
                Text(
                  _vicePrincipalData?['fullName'] ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          // Вкладки
          Container(
            color: Colors.grey[100],
            child: Row(
              children: [
                _buildTab(0, 'Обзор', Icons.dashboard),
                _buildTab(1, 'Классы', Icons.group),
                _buildTab(2, 'Учителя', Icons.person),
                _buildTab(3, 'Расписание', Icons.schedule),
                _buildTab(4, 'Предметы', Icons.subject),
                _buildTab(5, 'Объявления', Icons.campaign),
              ],
            ),
          ),

          // Контент
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildCurrentTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String title, IconData icon) {
    final isSelected = _currentTab == index;
    return Expanded(
      child: Material(
        color: isSelected ? Colors.white : Colors.grey[100],
        child: InkWell(
          onTap: () => setState(() => _currentTab = index),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: isSelected ? Colors.purple : Colors.grey),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.purple : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    if (_schoolData == null) {
      return const Center(
        child: Text('Школа не найдена'),
      );
    }

    switch (_currentTab) {
      case 0: return _buildOverviewTab();
      case 1: return _buildClassesTab();
      case 2: return _buildTeachersTab();
      case 3: return _buildScheduleTab();
      case 4: return _buildSubjectsTab();
      case 5: return _buildAnnouncementsTab();
      default: return const Center(child: Text('Раздел в разработке'));
    }
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Карточка школы
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Информация о школе',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('Название', _schoolData!['name']),
                  _buildInfoRow('Адрес', _schoolData!['address']),
                  _buildInfoRow('Код школы', _schoolData!['schoolCode']),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Статистика
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildStatCard('Классы', _classes.length.toString(), Icons.group, Colors.blue),
              _buildStatCard('Учителя', _teachers.length.toString(), Icons.person, Colors.green),
              _buildStatCard('Завучи', '1', Icons.supervisor_account, Colors.purple),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Быстрые действия
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Быстрые действия',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildActionButton('Редактировать расписание', Icons.schedule, () {
                        setState(() => _currentTab = 3);
                      }),
                      _buildActionButton('Отправить объявление', Icons.campaign, () {
                        setState(() => _currentTab = 5);
                      }),
                      _buildActionButton('Чат учителей', Icons.chat, _openTeachersChat),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Text(
                'Классы школы',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                'Всего: ${_classes.length}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: _classes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Нет классов', style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('Классы еще не созданы', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _classes.length,
                  itemBuilder: (context, index) {
                    final classData = _classes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text(
                            classData['name']?.toString().substring(0, 1) ?? '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(classData['name'] ?? 'Без названия'),
                        subtitle: FutureBuilder<DocumentSnapshot>(
                          future: _firestore
                              .collection('teachers')
                              .doc(classData['teacherId'])
                              .get(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final teacher = snapshot.data!.data() as Map<String, dynamic>;
                              return Text('Кл.рук: ${teacher['fullName']}');
                            }
                            return const Text('Загрузка...');
                          },
                        ),
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: () => _openClassSchedule(classData),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTeachersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Text(
                'Учителя школы',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                'Всего: ${_teachers.length}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: _teachers.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Нет учителей', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _teachers.length,
                  itemBuilder: (context, index) {
                    final teacher = _teachers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Text(
                            teacher['fullName']?.toString().substring(0, 1) ?? '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(teacher['fullName'] ?? 'Неизвестно'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(teacher['email'] ?? ''),
                            if (teacher['phone'] != null)
                              Text('Телефон: ${teacher['phone']}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildScheduleTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Редактирование расписания',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Выберите класс для редактирования расписания',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          
          if (_classes.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.group_off, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Нет классов для редактирования', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _classes.length,
                itemBuilder: (context, index) {
                  final classData = _classes[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(
                          classData['name']?.toString().substring(0, 1) ?? '?',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(classData['name'] ?? 'Без названия'),
                      subtitle: const Text('Редактировать расписание'),
                      trailing: const Icon(Icons.edit),
                      onTap: () => _openClassSchedule(classData),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Text(
                'Объявления',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _sendAnnouncement,
                icon: const Icon(Icons.add),
                label: const Text('Новое объявление'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.campaign, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Система объявлений', style: TextStyle(fontSize: 18)),
                SizedBox(height: 8),
                Text('Создавайте и отправляйте объявления учителям и классам', 
                    style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.purple[50],
        foregroundColor: Colors.purple,
      ),
    );
  }

  void _openClassSchedule(Map<String, dynamic> classData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduleEditorPage(
          classId: classData['classId'],
          className: classData['name'],
          isVicePrincipal: true,
        ),
      ),
    );
  }

  Future<void> _openTeachersChat() async {
    if (_schoolData == null) return;

    try {
      final chatId = 'teachers_${_schoolData!['schoolId']}';
      
      // Проверяем существование чата
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      
      if (!chatDoc.exists) {
        final ChatService chatService = ChatService();
        await chatService.createOrUpdateTeachersChat(_schoolData!['schoolId']);
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailPage(
            chatId: chatId,
            chatName: 'Чат учителей',
            chatType: 'teachers',
          ),
        ),
      );
    } catch (e) {
      print('❌ Ошибка открытия чата учителей: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _sendAnnouncement() {
    if (_schoolData == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnnouncementPage(
          schoolId: _schoolData!['schoolId'],
          schoolName: _schoolData!['name'],
        ),
      ),
    );
  }

  Widget _buildSubjectsTab() {
  return Column(
    children: [
      // ЗАГОЛОВОК С КНОПКОЙ - ИСПРАВЛЕННАЯ ВЕРСИЯ
      Container(
        padding: const EdgeInsets.all(16.0),
        color: Colors.grey[50],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Управление предметами',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
            const SizedBox(height: 8),
            
            // Кнопка занимает всю ширину
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SubjectsManagerPage(
                        schoolId: _schoolData!['schoolId'],
                        schoolName: _schoolData!['name'],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.settings, size: 18),
                label: const Text('Открыть управление предметами'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
      
      // ОСТАЛЬНОЙ КОД БЕЗ ИЗМЕНЕНИЙ
      Expanded(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: SubjectsService().getSchoolSubjects(_schoolData!['schoolId']),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.subject, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('Нет предметов', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    const Text(
                      'Предметы можно добавить в разделе управления',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SubjectsManagerPage(
                              schoolId: _schoolData!['schoolId'],
                              schoolName: _schoolData!['name'],
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                      ),
                      child: const Text('Добавить предметы'),
                    ),
                  ],
                ),
              );
            }

            final subjects = snapshot.data!;
            
            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: subjects.length,
              itemBuilder: (context, index) {
                final subject = subjects[index];
                
                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: SubjectsService().getSubjectTeachers(subject['subjectId']),
                  builder: (context, teachersSnapshot) {
                    final teachers = teachersSnapshot.data ?? [];
                    
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.purple,
                          child: Text(
                            subject['name'].toString().substring(0, 1),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          subject['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              teachers.isEmpty 
                                ? 'Нет назначенных учителей' 
                                : 'Учителей: ${teachers.length}',
                              style: TextStyle(
                                color: teachers.isEmpty ? Colors.grey : Colors.green,
                              ),
                            ),
                          ],
                        ),
                        trailing: teachers.isNotEmpty
                            ? Chip(
                                label: Text('${teachers.length}'),
                                backgroundColor: Colors.purple[50],
                              )
                            : const Chip(
                                label: Text('0'),
                                backgroundColor: Colors.grey,
                              ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    ],
  );
 }
}