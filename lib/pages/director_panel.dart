import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_app/services/chat_service.dart';
import 'package:school_app/services/code_service.dart';
import 'package:school_app/pages/create_class_page.dart';
import 'package:clipboard/clipboard.dart';
import 'package:school_app/pages/announcement_page.dart';

class DirectorPanel extends StatefulWidget {
  const DirectorPanel({super.key});

  @override
  State<DirectorPanel> createState() => _DirectorPanelState();
}

class _DirectorPanelState extends State<DirectorPanel> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final CodeService _codeService = CodeService();
  final ChatService _chatService = ChatService();
  
  Map<String, dynamic>? _directorData;
  Map<String, dynamic>? _schoolData;
  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _vicePrincipals = []; 
  List<Map<String, dynamic>> _classes = [];
  
  int _currentTab = 0;
  int _codesTabIndex = 0; 

  @override
  void initState() {
    super.initState();
    _loadDirectorData();
  }

  Future<void> _loadDirectorData() async {
    if (_currentUser == null) return;

    try {
      final directorDoc = await FirebaseFirestore.instance
          .collection('directors')
          .doc(_currentUser.uid)
          .get();

      if (directorDoc.exists) {
        final directorData = directorDoc.data();
        
        setState(() {
          _directorData = directorData;
        });
        
        final schoolId = directorData?['schoolId'];
        
        if (schoolId != null && schoolId is String && schoolId.isNotEmpty) {
          await _loadSchoolData(schoolId);
        } else {
          await _findSchoolByDirectorId();
        }
      }
    } catch (e) {
      print('❌ Ошибка загрузки данных директора: $e');
    }
  }

  Future<void> _loadSchoolData(String schoolId) async {
    try {
      final schoolDoc = await FirebaseFirestore.instance
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
        await _loadVicePrincipals(schoolId); // ЗАГРУЖАЕМ ЗАВУЧЕЙ
        await _loadClasses(schoolId);
      } else {
        throw Exception('Школа не найдена');
      }
    } catch (e) {
      print('❌ Ошибка загрузки школы: $e');
      rethrow;
    }
  }

  Future<void> _loadTeachers(String schoolId) async {
    final teachersSnapshot = await FirebaseFirestore.instance
        .collection('teachers')
        .where('schoolId', isEqualTo: schoolId)
        .get();

    setState(() {
      _teachers = teachersSnapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> _loadVicePrincipals(String schoolId) async {
    final vicePrincipalsSnapshot = await FirebaseFirestore.instance
        .collection('vice_principals')
        .where('schoolId', isEqualTo: schoolId)
        .get();

    setState(() {
      _vicePrincipals = vicePrincipalsSnapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> _loadClasses(String schoolId) async {
    final classesSnapshot = await FirebaseFirestore.instance
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.red,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Панель директора',
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
              ],
            ),
          ),

          Container(
            color: Colors.grey[100],
            child: Row(
              children: [
                _buildTab(0, 'Обзор', Icons.dashboard),
                _buildTab(1, 'Учителя', Icons.person),
                _buildTab(2, 'Завучи', Icons.supervisor_account), // НОВАЯ ВКЛАДКА
                _buildTab(3, 'Классы', Icons.group),
                _buildTab(4, 'Коды', Icons.vpn_key),
              ],
            ),
          ),

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
                Icon(icon, color: isSelected ? Colors.red : Colors.grey),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.red : Colors.grey,
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
      return const Center(child: CircularProgressIndicator());
    }

    switch (_currentTab) {
      case 0: return _buildOverviewTab();
      case 1: return _buildTeachersTab();
      case 2: return _buildVicePrincipalsTab();
      case 3: return _buildClassesTab();
      case 4: return _buildCodesTab();
      default: return const Center(child: Text('Раздел в разработке'));
    }
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  _buildActionButton('Управление объявлениями', Icons.campaign, _openAnnouncements),
                  _buildActionButton('Обновить чат учителей', Icons.refresh, _refreshTeachersChat),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              Expanded(
                child: _buildStatCard('Учителя', _teachers.length.toString(), Icons.person),
              ),
              Expanded(
                child: _buildStatCard('Завучи', _vicePrincipals.length.toString(), Icons.supervisor_account),
              ),
              Expanded(
                child: _buildStatCard('Классы', _classes.length.toString(), Icons.group),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
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
                      _buildActionButton('Добавить учителя', Icons.person_add, () {
                        setState(() {
                          _currentTab = 4;
                          _codesTabIndex = 0;
                        });
                      }),
                      _buildActionButton('Добавить завуча', Icons.supervisor_account, () {
                        setState(() {
                          _currentTab = 4;
                          _codesTabIndex = 1;
                        });
                      }),
                      _buildActionButton('Создать класс', Icons.group_add, _createClass),
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
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentTab = 4;
                    _codesTabIndex = 0;
                  });
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Добавить учителя'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
                      Icon(Icons.person, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Нет учителей', style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('Добавьте первого учителя', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _teachers.length,
                  itemBuilder: (context, index) {
                    final teacher = _teachers[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Text(
                            teacher['fullName']?.toString().substring(0, 1) ?? '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(teacher['fullName'] ?? 'Неизвестно'),
                        subtitle: Text(teacher['email'] ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () => _showTeacherMenu(teacher),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildVicePrincipalsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Text(
                'Завучи школы',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentTab = 4;
                    _codesTabIndex = 1;
                  });
                },
                icon: const Icon(Icons.supervisor_account),
                label: const Text('Добавить завуча'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: _vicePrincipals.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.supervisor_account, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Нет завучей', style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('Добавьте первого завуча', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _vicePrincipals.length,
                  itemBuilder: (context, index) {
                    final vicePrincipal = _vicePrincipals[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.purple,
                          child: Text(
                            vicePrincipal['fullName']?.toString().substring(0, 1) ?? '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(vicePrincipal['fullName'] ?? 'Неизвестно'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(vicePrincipal['email'] ?? ''),
                            Text('Телефон: ${vicePrincipal['phone'] ?? 'не указан'}'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () => _showVicePrincipalMenu(vicePrincipal),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
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
              ElevatedButton.icon(
                onPressed: _createClass,
                icon: const Icon(Icons.group_add),
                label: const Text('Создать класс'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
                      Icon(Icons.group, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Нет классов', style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('Создайте первый класс', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _classes.length,
                  itemBuilder: (context, index) {
                    final classData = _classes[index];
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
                              .collection('teachers')
                              .doc(classData['teacherId'])
                              .get(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              final teacher = snapshot.data!.data() as Map<String, dynamic>?;
                              return Text('Классный руководитель: ${teacher?['fullName'] ?? 'Не назначен'}');
                            }
                            return const Text('Загрузка...');
                          },
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () => _showClassMenu(classData),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ЕДИНАЯ ВКЛАДКА С КОДАМИ
  Widget _buildCodesTab() {
    return Column(
      children: [
        // Переключатель между кодами учителей и завучей
        Container(
          color: Colors.grey[100],
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _codesTabIndex = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _codesTabIndex == 0 ? Colors.white : Colors.grey[100],
                      border: _codesTabIndex == 0 
                          ? const Border(bottom: BorderSide(color: Colors.red, width: 2))
                          : null,
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.person, color: _codesTabIndex == 0 ? Colors.red : Colors.grey),
                        Text(
                          'Учителя',
                          style: TextStyle(
                            color: _codesTabIndex == 0 ? Colors.red : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _codesTabIndex = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _codesTabIndex == 1 ? Colors.white : Colors.grey[100],
                      border: _codesTabIndex == 1 
                          ? const Border(bottom: BorderSide(color: Colors.purple, width: 2))
                          : null,
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.supervisor_account, color: _codesTabIndex == 1 ? Colors.purple : Colors.grey),
                        Text(
                          'Завучи',
                          style: TextStyle(
                            color: _codesTabIndex == 1 ? Colors.purple : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Контент вкладки
        Expanded(
          child: _codesTabIndex == 0 
              ? _buildTeacherCodesContent()
              : _buildVicePrincipalCodesContent(),
        ),
      ],
    );
  }

  Widget _buildTeacherCodesContent() {
    final teacherCodes = List<String>.from(_schoolData?['teacherCodes'] ?? []);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Коды для учителей',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Сгенерируйте код и передайте его учителю для регистрации в вашей школе',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _generateTeacherCode,
                      icon: const Icon(Icons.vpn_key),
                      label: const Text('Сгенерировать новый код'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Text(
            'Активные коды:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: teacherCodes.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.vpn_key, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Нет активных кодов', style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 8),
                        Text('Сгенерируйте код для учителя', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: teacherCodes.length,
                    itemBuilder: (context, index) {
                      final code = teacherCodes[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.vpn_key, color: Colors.green),
                          title: Text(
                            code,
                            style: const TextStyle(fontFamily: 'Monospace', fontSize: 16),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.content_copy, size: 20),
                            onPressed: () => _copyToClipboard(code),
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

  Widget _buildVicePrincipalCodesContent() {
    final vicePrincipalCodes = List<String>.from(_schoolData?['vicePrincipalCodes'] ?? []);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Коды для завучей',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Сгенерируйте код и передайте его будущему завучу для регистрации',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _generateVicePrincipalCode,
                      icon: const Icon(Icons.supervisor_account),
                      label: const Text('Сгенерировать код для завуча'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Text(
            'Активные коды:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: vicePrincipalCodes.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.supervisor_account, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Нет активных кодов', style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 8),
                        Text('Сгенерируйте код для завуча', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: vicePrincipalCodes.length,
                    itemBuilder: (context, index) {
                      final code = vicePrincipalCodes[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.supervisor_account, color: Colors.purple),
                          title: Text(
                            code,
                            style: const TextStyle(fontFamily: 'Monospace', fontSize: 16),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.content_copy, size: 20),
                            onPressed: () => _copyToClipboard(code),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Colors.red),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
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
        backgroundColor: Colors.red[50],
        foregroundColor: Colors.red,
      ),
    );
  }

  // ГЕНЕРАЦИЯ КОДА ДЛЯ ЗАВУЧА
  Future<void> _generateVicePrincipalCode() async {
    try {
      if (_schoolData == null) {
        throw Exception('Данные школы не загружены');
      }

      final schoolId = _schoolData!['schoolId'];
      
      if (schoolId == null || schoolId.isEmpty) {
        throw Exception('ID школы не найден');
      }

      print('🔄 Генерация кода завуча для школы: $schoolId');
      
      final newCode = await _codeService.generateVicePrincipalCode(schoolId);
      
      print('✅ Код завуча сгенерирован: $newCode');

      await _loadSchoolData(schoolId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Новый код для завуча создан: $newCode'),
          backgroundColor: Colors.purple,
        ),
      );
      
    } catch (e) {
      print('❌ Ошибка в _generateVicePrincipalCode: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка создания кода: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showVicePrincipalMenu(Map<String, dynamic> vicePrincipal) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.chat),
            title: const Text('Написать сообщение'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.visibility),
            title: const Text('Просмотреть профиль'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Удалить завуча', style: TextStyle(color: Colors.red)),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // Остальные методы без изменений
  Future<void> _generateTeacherCode() async {
    try {
      if (_schoolData == null) {
        throw Exception('Данные школы не загружены');
      }

      final schoolId = _schoolData!['schoolId'];
      
      if (schoolId == null || schoolId.isEmpty) {
        throw Exception('ID школы не найден');
      }

      print('🔄 Генерация кода для школы: $schoolId');
      
      final newCode = await _codeService.generateTeacherCode(schoolId);
      
      print('✅ Код сгенерирован: $newCode');

      final ChatService chatService = ChatService();
      await chatService.createOrUpdateTeachersChat(schoolId);
      
      await _loadSchoolData(schoolId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Новый код создан: $newCode'),
          backgroundColor: Colors.green,
        ),
      );
      
    } catch (e) {
      print('❌ Ошибка в _generateTeacherCode: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка создания кода: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _createClass() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateClassPage(
          schoolId: _schoolData!['schoolId'],
          schoolName: _schoolData!['name'],
        ),
      ),
    );
  }

  void _showTeacherMenu(Map<String, dynamic> teacher) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.chat),
            title: const Text('Написать сообщение'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.visibility),
            title: const Text('Просмотреть профиль'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Удалить учителя', style: TextStyle(color: Colors.red)),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showClassMenu(Map<String, dynamic> classData) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Редактировать класс'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text('Управление учениками'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.chat),
            title: const Text('Открыть чат класса'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Удалить класс', style: TextStyle(color: Colors.red)),
            onTap: () => Navigator.pop(context),
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка копирования: $e')),
      );
    }
  }

  Future<void> _findSchoolByDirectorId() async {
    try {
      final schoolsSnapshot = await FirebaseFirestore.instance
          .collection('schools')
          .where('directorId', isEqualTo: _currentUser!.uid)
          .limit(1)
          .get();

      if (schoolsSnapshot.docs.isNotEmpty) {
        final schoolDoc = schoolsSnapshot.docs.first;
        final schoolId = schoolDoc.id;
        
        await FirebaseFirestore.instance.collection('directors').doc(_currentUser.uid).update({
          'schoolId': schoolId,
        });
        await _loadSchoolData(schoolId);
      } else {
        throw Exception('Школа не назначена для этого директора');
      }
    } catch (e) {
      print('❌ Ошибка поиска школы: $e');
      rethrow;
    }
  }

  void _openAnnouncements() {
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

  Future<void> _refreshTeachersChat() async {
    try {
      if (_schoolData == null) return;
      final ChatService chatService = ChatService();
      await chatService.createOrUpdateTeachersChat(_schoolData!['schoolId']);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Чат учителей обновлен!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showNoSchoolMessage() {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Директор не привязан к школе. Ожидайте подтверждения заявки.'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}