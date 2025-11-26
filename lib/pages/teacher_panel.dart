import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_app/services/chat_service.dart';
import 'package:school_app/services/code_service.dart';
import 'package:clipboard/clipboard.dart';
import 'package:school_app/pages/schedule_editor_page.dart';

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
        .doc(_currentUser!.uid)
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

          // Вкладки
          Container(
            color: Colors.grey[100],
            child: Row(
              children: [
                _buildTab(0, 'Мои классы', Icons.group),
                _buildTab(1, 'Расписание', Icons.schedule),
                _buildTab(2, 'Коды учеников', Icons.vpn_key),
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
      case 1: return _buildScheduleTab();
      case 2: return _buildStudentCodesTab();
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
                onPressed: _addStudentsToClass,
                icon: const Icon(Icons.person_add),
                label: const Text('Добавить учеников'),
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
                            if (snapshot.hasData) {
                              final classData = snapshot.data!.data() as Map<String, dynamic>?;
                              final studentCount = (classData?['studentIds'] as List?)?.length ?? 0;
                              return Text('Учеников: $studentCount');
                            }
                            return const Text('Загрузка...');
                          },
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () => _showClassMenu(classData),
                        ),
                        onTap: () {
                          // Разработать: Открыть детали класса
                        },
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
        // ФИКС: Заменяем Row на Column на маленьких экранах
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 400) {
              // Для широких экранов - Row
              return Row(
                children: [
                  const Text(
                    'Расписание',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _openScheduleEditor,
                    icon: const Icon(Icons.edit),
                    label: const Text('Редактировать расписание'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ],
              );
            } else {
              // Для узких экранов - Column
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Расписание',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openScheduleEditor,
                      icon: const Icon(Icons.edit),
                      label: const Text('Редактировать расписание'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  ),
                ],
              );
            }
          },
        ),
        
        const SizedBox(height: 16),
        
        // Показываем список классов учителя с возможностью выбора
        if (_myClasses.isNotEmpty) ...[
          const Text(
            'Выберите класс для редактирования расписания:',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: ListView.builder(
              itemCount: _myClasses.length,
              itemBuilder: (context, index) {
                final classData = _myClasses[index];
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
                    subtitle: const Text('Классный руководитель: Вы'),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () => _openScheduleForClass(classData),
                  ),
                );
              },
            ),
          ),
        ] else ...[
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
        ],
      ],
    ),
  );
}

// Метод для открытия редактора расписания
void _openScheduleEditor() {
  // Показываем диалог выбора класса
  if (_myClasses.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('У вас нет классов для редактирования')),
    );
    return;
  }

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Выберите класс'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _myClasses.length,
          itemBuilder: (context, index) {
            final classData = _myClasses[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue,
                child: Text(
                  classData['name']?.toString().substring(0, 1) ?? '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(classData['name'] ?? 'Без названия'),
              onTap: () {
                Navigator.pop(context);
                _openScheduleForClass(classData);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
      ],
    ),
  );
 }

 // Метод для открытия расписания конкретного класса
 void _openScheduleForClass(Map<String, dynamic> classData) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ScheduleEditorPage(
        classId: classData['classId'],
        className: classData['name'],
      ),
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
            'Коды для учеников',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Сгенерируйте коды для регистрации учеников в ваших классах',
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
                  final studentCodes = List<String>.from(classData['studentCodes'] ?? []);
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            classData['name'] ?? 'Без названия',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          
                          if (studentCodes.isEmpty)
                            const Text('Нет активных кодов', style: TextStyle(color: Colors.grey))
                          else
                            Column(
                              children: studentCodes.map((code) => ListTile(
                                leading: const Icon(Icons.vpn_key, color: Colors.green),
                                title: Text(code, style: const TextStyle(fontFamily: 'Monospace')),
                                trailing: IconButton(
                                  icon: const Icon(Icons.content_copy, size: 20),
                                  onPressed: () => _copyToClipboard(code),
                                ),
                              )).toList(),
                            ),
                          
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _generateStudentCode(classData['classId']),
                              icon: const Icon(Icons.vpn_key),
                              label: const Text('Сгенерировать код'),
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
              ),
            ),
        ],
      ),
    );
  }

  // Методы действий
  void _addStudentsToClass() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Добавление учеников - в разработке')),
    );
  }

  void _createSchedule() {
    // TODO: Реализовать создание расписания
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Создание расписания - в разработке')),
    );
  }

  Future<void> _generateStudentCode(String classId) async {
    try {
      // Генерируем код ученика
      final newCode = 'STU${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      
      // Добавляем код в класс
      await FirebaseFirestore.instance.collection('classes').doc(classId).update({
        'studentCodes': FieldValue.arrayUnion([newCode]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Новый код создан: $newCode'),
          backgroundColor: Colors.green,
        ),
      );

      // Обновляем данные
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

  void _showClassMenu(Map<String, dynamic> classData) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Управление учениками'),
            onTap: () {
              Navigator.pop(context);
              _addStudentsToClass();
            },
          ),
          ListTile(
            leading: const Icon(Icons.chat),
            title: const Text('Открыть чат класса'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Открыть чат класса
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment),
            title: const Text('Домашние задания'),
            onTap: () {
              Navigator.pop(context);
              setState(() => _currentTab = 2);
            },
          ),
        ],
      ),
    );
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
   }  catch (e) {
     ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ошибка копирования: $e')),
     );
   }
 }
}