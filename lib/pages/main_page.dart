import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_app/pages/admin_panel.dart';
import 'package:school_app/pages/director_panel.dart';
import 'package:school_app/pages/student_grades_page.dart';
import 'package:school_app/pages/vice_principal_panel.dart';
import 'package:school_app/pages/teacher_panel.dart';
import 'package:school_app/pages/chats_page.dart';
import 'package:school_app/pages/schedule_view_page.dart';
import 'package:school_app/pages/student_homework_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  int _currentIndex = 0;
  String? _userRole;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    
    final userData = userDoc.data();
    if (userData != null) {
      setState(() {
        _userRole = userData['role'];
      });

      await _loadUserName(userData['role']);
    }
  }

  Future<void> _loadUserName(String role) async {
    String collectionName = '';
    
    switch (role) {
      case 'student':
        collectionName = 'students';
        break;
      case 'teacher':
        collectionName = 'teachers';
        break;
      case 'vice_principal':
        collectionName = 'vice_principals';
        break;
      case 'parent':
        collectionName = 'parents';
        break;
      case 'director':
        collectionName = 'directors';
        break;
      case 'admin':
        collectionName = 'admins';
        break;
      default:
        return;
    }

    try {
      final profileDoc = await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(user!.uid)
          .get();

      if (profileDoc.exists) {
        setState(() {
          _userName = profileDoc.data()?['fullName'] ?? 'Пользователь';
        });
      }
    } catch (e) {
      print('Ошибка загрузки имени: $e');
    }
  }

  List<Widget> _buildScreens() {
    if (_userRole == 'admin') {
      return [
        const AdminPanel(),
        _buildProfileScreen(),
      ];
    } else if (_userRole == 'director') {
      return [
        const DirectorPanel(),
        const ChatsPage(), 
        _buildProfileScreen(),
      ];
    } else if (_userRole == 'vice_principal') {
      return [
        const VicePrincipalPanel(),
        const ChatsPage(),
        _buildProfileScreen(),
      ];
    } else if (_userRole == 'teacher') {
      return [
        const TeacherPanel(),
        const ChatsPage(),
        const ScheduleViewPage(),
        _buildProfileScreen(),
      ];
    } else if (_userRole == 'parent') {
      return [
        const ChatsPage(),
        const ScheduleViewPage(),
        const StudentGradesPage(),
        const StudentHomeworkPage(),
        _buildProfileScreen(),
      ];
    } else {
      // Для учеников
      return [
        const ChatsPage(),
        const ScheduleViewPage(),
        const StudentGradesPage(), 
        const StudentHomeworkPage(),
        _buildProfileScreen(),
      ];
    }
  }

  Widget _buildProfileScreen() {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: _getRoleColor(_userRole),
                      child: Text(
                        _userName?.substring(0, 1) ?? 'П',
                        style: const TextStyle(fontSize: 24, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName ?? 'Загрузка...',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getRoleDisplayName(_userRole),
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          Text(
                            user?.email ?? '',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  _buildProfileItem('Редактировать профиль', Icons.edit, () {
                    _showComingSoon('Редактирование профиля');
                  }),
                  _buildProfileItem('Настройки', Icons.settings, () {
                    _showComingSoon('Настройки');
                  }),
                  _buildProfileItem('Помощь', Icons.help, () {
                    _showComingSoon('Помощь');
                  }),
                  const SizedBox(height: 20),
                  Card(
                    color: Colors.red[50],
                    child: ListTile(
                      leading: Icon(Icons.logout, color: Colors.red[700]),
                      title: Text('Выйти', style: TextStyle(color: Colors.red[700])),
                      onTap: _logout,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(String title, IconData icon, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - скоро будет доступно!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'student': return Colors.blue;
      case 'teacher': return Colors.green;
      case 'vice_principal': return Colors.purple;
      case 'parent': return Colors.orange;
      case 'director': return Colors.red;
      case 'admin': return Colors.teal;
      default: return Colors.grey;
    }
  }

  String _getRoleDisplayName(String? role) {
    switch (role) {
      case 'student': return 'Ученик';
      case 'teacher': return 'Учитель';
      case 'vice_principal': return 'Завуч';
      case 'parent': return 'Родитель';
      case 'director': return 'Директор';
      case 'admin': return 'Администратор';
      default: return 'Пользователь';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = _buildScreens();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_userName ?? 'Шкилла'),
        backgroundColor: _getRoleColor(_userRole),
        foregroundColor: Colors.white,
        actions: [
          if (_userRole == 'admin')
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () => setState(() => _currentIndex = 0),
              tooltip: 'Админ-панель',
            ),
          if (_userRole == 'director')
            IconButton(
              icon: const Icon(Icons.school),
              onPressed: () => setState(() => _currentIndex = 0),
              tooltip: 'Панель управления',
            ),
          if (_userRole == 'vice_principal')
            IconButton(
              icon: const Icon(Icons.supervisor_account),
              onPressed: () => setState(() => _currentIndex = 0),
              tooltip: 'Панель завуча',
            ),
          if (_userRole == 'teacher')
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () => setState(() => _currentIndex = 0),
              tooltip: 'Панель учителя',
            ),
          if (_userRole == 'parent')
            IconButton(
              icon: const Icon(Icons.family_restroom),
              onPressed: () => setState(() => _currentIndex = 0),
              tooltip: 'Панель родителя',
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    if (_userRole == 'admin') {
      return BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings), 
            label: 'Админ'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person), 
            label: 'Профиль'
          ),
        ],
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.teal,
      );
    } else if (_userRole == 'director') {
      return BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.school), 
            label: 'Управление'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat), 
            label: 'Чаты'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person), 
            label: 'Профиль'
          ),
        ],
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.red,
      );
    } else if (_userRole == 'vice_principal') {
      return BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.supervisor_account), 
            label: 'Завуч'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat), 
            label: 'Чаты'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person), 
            label: 'Профиль'
          ),
        ],
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.purple,
      );
    } else if (_userRole == 'teacher') {
      return BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person), 
            label: 'Учитель'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat), 
            label: 'Чаты'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule), 
            label: 'Расписание'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person), 
            label: 'Профиль'
          ),
        ],
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
      );
    } else if (_userRole == 'parent') {
      return BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule), 
            label: 'Чаты'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat), 
            label: 'Расписание'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grade), 
            label: 'Оценки'
          ),
                    BottomNavigationBarItem(
            icon: Icon(Icons.person), 
            label: 'ДЗ'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person), 
            label: 'Профиль'
          ),
        ],
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.orange,
      );
    } else {
      // Для учеников
      return BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Чаты'),
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Расписание'),
          BottomNavigationBarItem(icon: Icon(Icons.grade), label: 'Оценки'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'ДЗ'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профиль'),
        ],
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
      );
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }
}