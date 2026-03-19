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
import 'package:school_app/pages/edit_profile_page.dart'; // Импорт нового экрана

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
  Map<String, dynamic>? _fullUserData; // Все данные из ролевой коллекции

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
    String collectionName = _getCollectionName(role);
    
    try {
      final profileDoc = await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(user!.uid)
          .get();

      if (profileDoc.exists) {
        setState(() {
          _fullUserData = profileDoc.data();
          _userName = _fullUserData?['fullName'] ?? 'Пользователь';
        });
      }
    } catch (e) {
      print('Ошибка загрузки имени: $e');
    }
  }

  String _getCollectionName(String role) {
    switch (role) {
      case 'student': return 'students';
      case 'teacher': return 'teachers';
      case 'vice_principal': return 'vice_principals';
      case 'parent': return 'parents';
      case 'director': return 'directors';
      case 'admin': return 'admins';
      default: return 'users';
    }
  }

  List<Widget> _buildScreens() {
    final List<Widget> roleScreens = [];
    
    if (_userRole == 'admin') {
      roleScreens.addAll([const AdminPanel()]);
    } else if (_userRole == 'director') {
      roleScreens.addAll([const DirectorPanel(), const ChatsPage()]);
    } else if (_userRole == 'vice_principal') {
      roleScreens.addAll([const VicePrincipalPanel(), const ChatsPage()]);
    } else if (_userRole == 'teacher') {
      roleScreens.addAll([const TeacherPanel(), const ChatsPage(), const ScheduleViewPage()]);
    } else if (_userRole == 'parent') {
      String? childId = _fullUserData?['childId'];
      roleScreens.addAll([const ChatsPage(), const ScheduleViewPage(), const StudentGradesPage(), const StudentHomeworkPage()]);
    } else {
      roleScreens.addAll([const ChatsPage(), const ScheduleViewPage(), const StudentGradesPage(), const StudentHomeworkPage()]);
    }
    
    roleScreens.add(_buildProfileScreen());
    return roleScreens;
  }

  Widget _buildProfileScreen() {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: _getRoleColor(_userRole),
                      child: Text(
                        _userName?.substring(0, 1) ?? 'П',
                        style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName ?? 'Загрузка...',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getRoleDisplayName(_userRole),
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          ),
                          Text(
                            user?.email ?? '',
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),
            Expanded(
              child: ListView(
                children: [
                  _buildProfileItem('Редактировать профиль', Icons.edit_note_outlined, () async {
                    if (_userRole != null && _fullUserData != null) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfilePage(
                            userData: _fullUserData!,
                            role: _userRole!,
                          ),
                        ),
                      );
                      _loadUserData(); 
                    }
                  }),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 0,
                    color: Colors.red[50],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: Icon(Icons.logout_rounded, color: Colors.red[700]),
                      title: Text('Выйти из аккаунта', style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w500)),
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
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: _getRoleColor(_userRole)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
        onTap: onTap,
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
    
    // Проверка индекса, чтобы избежать ошибок при смене ролей
    int safeIndex = _currentIndex >= screens.length ? 0 : _currentIndex;

    return Scaffold(
      appBar: AppBar(
        title: Text(_userName ?? 'Шкилла'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: _getRoleColor(_userRole),
        foregroundColor: Colors.white,
      ),
      body: screens[safeIndex],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    // Список элементов навигации в зависимости от роли
    List<BottomNavigationBarItem> items = [];
    Color activeColor = _getRoleColor(_userRole);

    if (_userRole == 'admin') {
      items = const [
        BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Админ'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профиль'),
      ];
    } else if (_userRole == 'director') {
      items = const [
        BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Управление'),
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Чаты'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профиль'),
      ];
    } else if (_userRole == 'vice_principal') {
      items = const [
        BottomNavigationBarItem(icon: Icon(Icons.supervisor_account), label: 'Завуч'),
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Чаты'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профиль'),
      ];
    } else if (_userRole == 'teacher') {
      items = const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Учитель'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_outlined), label: 'Чаты'),
        BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), label: 'Расписание'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Профиль'),
      ];
    } else if (_userRole == 'parent' || _userRole == 'student') {
      items = [
        const BottomNavigationBarItem(icon: Icon(Icons.chat_outlined), label: 'Чаты'),
        const BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), label: 'Расписание'),
        const BottomNavigationBarItem(icon: Icon(Icons.grade_outlined), label: 'Оценки'),
        const BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), label: 'ДЗ'),
        const BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Профиль'),
      ];
    } else {
      items = const [
        BottomNavigationBarItem(icon: Icon(Icons.help_outline), label: 'Загрузка'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профиль'),
      ];
    }

    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      items: items,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: activeColor,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }
}