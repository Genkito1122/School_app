import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_app/services/chat_service.dart';
import 'package:school_app/services/code_service.dart';
import 'package:clipboard/clipboard.dart';
import 'package:school_app/pages/schedule_editor_page.dart';
import 'package:school_app/pages/teacher_grades_page.dart';
import 'package:school_app/pages/teacher_homework_page.dart';

class TeacherPanel extends StatefulWidget {
  const TeacherPanel({super.key});

  @override
  State<TeacherPanel> createState() => _TeacherPanelState();
}

class _TeacherPanelState extends State<TeacherPanel> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final CodeService _codeService = CodeService();
  final ChatService _chatService = ChatService();
  
  Map<String, dynamic>? _teacherData;
  List<Map<String, dynamic>> _myClasses = [];
  
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    if (_currentUser == null) return;

    final teacherDoc = await FirebaseFirestore.instance
        .collection('teachers')
        .doc(_currentUser.uid)
        .get();

    if (teacherDoc.exists) {
      setState(() {
        _teacherData = teacherDoc.data();
      });
      
      await _loadMyClasses();
    }
  }

  Future<void> _loadMyClasses() async {
    if (_teacherData == null) return;

    final classIds = List<String>.from(_teacherData?['classIds'] ?? []);
    
    if (classIds.isEmpty) return;

    final classesSnapshot = await FirebaseFirestore.instance
        .collection('classes')
        .where('classId', whereIn: classIds)
        .get();

    setState(() {
      _myClasses = classesSnapshot.docs.map((doc) => doc.data()).toList();
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
            color: Colors.green,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Панель учителя',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _teacherData?['fullName'] ?? 'Загрузка...',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

          // ОБНОВЛЕННЫЕ ВКЛАДКИ
          Container(
            color: Colors.grey[100],
            child: Row(
              children: [
                _buildTab(0, 'Мои классы', Icons.group),
                _buildTab(1, 'Журнал', Icons.grade),  
                _buildTab(2, 'ДЗ', Icons.assignment),
                _buildTab(3, 'Коды', Icons.vpn_key),
              ],
            ),
          ),

          // Контент
          Expanded(
            child: _buildCurrentTab(),
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
                Icon(icon, color: isSelected ? Colors.green : Colors.grey),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.green : Colors.grey,
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
    if (_teacherData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_currentTab) {
      case 0: return _buildMyClassesTab();
      case 1: return _buildGradesTab(); 
      case 2: return _buildHomeworkTab();
      case 3: return _buildStudentCodesTab();
      default: return const Center(child: Text('Раздел в разработке'));
    }
  }

  Widget _buildMyClassesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Text(
                'Мои классы',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _viewClassSchedule,
                icon: const Icon(Icons.schedule),
                label: const Text('Расписание'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: _myClasses.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Нет классов', style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('Вас пока не назначили классным руководителем', 
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _myClasses.length,
                  itemBuilder: (context, index) {
                    final classData = _myClasses[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                          future: FirebaseFirestore.instance
                              .collection('classes')
                              .doc(classData['classId'])
                              .get(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final classInfo = snapshot.data!.data() as Map<String, dynamic>;

                              final classCode = classInfo['classCode'] as String?;
                              final hasCode = classCode != null && classCode.isNotEmpty;
                              
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (hasCode)
                                    Text(
                                      'Код: $classCode',
                                      style: const TextStyle(fontSize: 12, color: Colors.green),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Школа: ${classData['schoolName'] ?? 'Не указана'}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              );
                            }
                            return const Text('Загрузка...');
                          },
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.schedule),
                              onPressed: () => _openClassSchedule(classData),
                              tooltip: 'Расписание класса',
                            ),
                            IconButton(
                              icon: const Icon(Icons.grade),
                              onPressed: () => _openClassGrades(classData),
                              tooltip: 'Журнал оценок',
                            ),
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

  Widget _buildGradesTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.grade, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          const Text(
            'Журнал оценок',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Выставление и просмотр оценок',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          
          if (_myClasses.isNotEmpty)
            SizedBox(
              width: 200,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_myClasses.isNotEmpty) {
                    _openClassGrades(_myClasses.first);
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Открыть журнал'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            )
          else
            const Text(
              'У вас нет классов для ведения журнала',
              style: TextStyle(color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildHomeworkTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assignment, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          const Text(
            'Домашние задания',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Создание и управление домашними заданиями',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          
          SizedBox(
            width: 200,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TeacherHomeworkPage(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Создать ДЗ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCodesTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Код класса для учеников',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Создайте код для регистрации учеников в вашем классе',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),

          if (_myClasses.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.group_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Нет классов', style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('Вас не назначили классным руководителем', 
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _myClasses.length,
                itemBuilder: (context, index) {
                  final classData = _myClasses[index];
                  final className = classData['name'] ?? 'Без названия';
                  final classId = classData['classId'];
                  
                  // Загружаем текущий код класса
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('classes')
                        .doc(classId)
                        .get(),
                    builder: (context, snapshot) {
                      String? currentCode;
                      bool hasCode = false;
                      
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<String, dynamic>?;
                        currentCode = data?['classCode'] as String?;
                        hasCode = currentCode != null && currentCode.isNotEmpty;
                      }
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                className,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              
                              if (hasCode)
                                Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.green),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.vpn_key, color: Colors.green),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  currentCode!,
                                                  style: const TextStyle(
                                                    fontFamily: 'Monospace',
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                const Text(
                                                  'Действующий код класса',
                                                  style: TextStyle(fontSize: 12, color: Colors.green),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.content_copy, size: 20),
                                            onPressed: () => _copyToClipboard(currentCode!),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Дайте этот код ученикам для регистрации в классе',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                )
                              else
                                const Text(
                                  'Код класса не создан',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _generateClassCode(classId, className),
                                  icon: const Icon(Icons.vpn_key),
                                  label: Text(hasCode ? 'Обновить код' : 'Создать код класса'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // === МЕТОДЫ НАВИГАЦИИ ===

  void _openClassSchedule(Map<String, dynamic> classData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduleEditorPage(
          classId: classData['classId'],
          className: classData['name'],
          isVicePrincipal: false, // Учитель - только просмотр + ДЗ
        ),
      ),
    );
  }

  void _viewClassSchedule() {
    if (_myClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У вас нет классов для просмотра')),
      );
      return;
    }
    _openClassSchedule(_myClasses.first);
  }

  void _openClassGrades(Map<String, dynamic> classData) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Пользователь не авторизован')),
    );
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => TeacherGradesPage(
        teacherId: user.uid, 
      ),
    ),
  );
}

  void _openHomeworkPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TeacherHomeworkPage(),
      ),
    );
  }


  Future<void> _generateClassCode(String classId, String className) async {
    try {
      final codeService = CodeService();
      final newCode = await codeService.generateClassCode(classId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Код класса создан: $newCode'),
              const SizedBox(height: 4),
              Text(
                'Дайте этот код ученикам для регистрации в классе $className',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );

      // Обновляем UI
      await _loadMyClasses();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка создания кода: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _copyToClipboard(String text) async {
    try {
      await FlutterClipboard.copy(text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Код "$text" скопирован'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка копирования: $e')),
      );
    }
  }
}