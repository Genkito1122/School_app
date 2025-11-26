import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScheduleViewPage extends StatefulWidget {
  const ScheduleViewPage({super.key});

  @override
  State<ScheduleViewPage> createState() => _ScheduleViewPageState();
}

class _ScheduleViewPageState extends State<ScheduleViewPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  
  List<Map<String, dynamic>> _schedule = [];
  bool _isLoading = true;
  String _selectedDay = 'monday';
  String? _classId;
  String? _className;
  String? _userRole;
  bool _isMounted = false;

  final List<String> _days = [
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday'
  ];

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _loadUserRole(); // Сначала загружаем роль
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  // Безопасный setState
  void _safeSetState(VoidCallback fn) {
    if (_isMounted) {
      setState(fn);
    }
  }

  // Сначала загружаем только роль для цвета
  Future<void> _loadUserRole() async {
    if (_currentUser == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      final userRole = userDoc.data()?['role'];
      
      _safeSetState(() {
        _userRole = userRole;
      });

      // После загрузки роли загружаем остальные данные
      await _loadUserData();
    } catch (e) {
      print('Ошибка загрузки роли пользователя: $e');
      _safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserData() async {
    if (_currentUser == null) return;

    try {
      // В зависимости от роли получаем classId
      String? classId;
      String? className;

      switch (_userRole) {
        case 'student':
          final studentDoc = await _firestore.collection('students').doc(_currentUser!.uid).get();
          if (studentDoc.exists) {
            classId = studentDoc.data()?['classId'];
            className = studentDoc.data()?['className'];
          }
          break;

        case 'parent':
          final parentDoc = await _firestore.collection('parents').doc(_currentUser!.uid).get();
          if (parentDoc.exists) {
            final childIds = List<String>.from(parentDoc.data()?['childIds'] ?? []);
            if (childIds.isNotEmpty) {
              final childDoc = await _firestore.collection('students').doc(childIds.first).get();
              if (childDoc.exists) {
                classId = childDoc.data()?['classId'];
                className = childDoc.data()?['className'];
              }
            }
          }
          break;

        case 'teacher':
        case 'director':
          final teacherDoc = await _firestore.collection('teachers').doc(_currentUser!.uid).get();
          if (teacherDoc.exists) {
            final classIds = List<String>.from(teacherDoc.data()?['classIds'] ?? []);
            if (classIds.isNotEmpty) {
              final classDoc = await _firestore.collection('classes').doc(classIds.first).get();
              if (classDoc.exists) {
                classId = classDoc.id;
                className = classDoc.data()?['name'];
              }
            }
          }
          break;
      }

      _safeSetState(() {
        _classId = classId;
        _className = className;
      });

      if (classId != null) {
        await _loadCurrentSchedule();
      } else {
        _safeSetState(() => _isLoading = false);
      }
    } catch (e) {
      print('Ошибка загрузки данных пользователя: $e');
      _safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _loadCurrentSchedule() async {
    try {
      final now = DateTime.now();
      final weekStart = DateTime(now.year, now.month, now.day - now.weekday + 1);
      
      final scheduleDoc = await _firestore
          .collection('schedules')
          .where('classId', isEqualTo: _classId)
          .where('weekStart', isEqualTo: Timestamp.fromDate(weekStart))
          .limit(1)
          .get();

      if (scheduleDoc.docs.isNotEmpty) {
        final data = scheduleDoc.docs.first.data();
        _safeSetState(() {
          _schedule = List<Map<String, dynamic>>.from(data['days'] ?? []);
        });
      }
    } catch (e) {
      print('Ошибка загрузки расписания: $e');
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  Color _getRoleColor() {
    // Если роль еще не загружена, используем нейтральный цвет
    if (_userRole == null) return Colors.grey;
    
    switch (_userRole) {
      case 'student': return Colors.blue;
      case 'teacher': return Colors.green;
      case 'parent': return Colors.orange;
      case 'director': return Colors.red;
      case 'admin': return Colors.teal;
      default: return Colors.grey;
    }
  }

  String _getDayDisplayName(String day) {
    switch (day) {
      case 'monday': return 'Понедельник';
      case 'tuesday': return 'Вторник';
      case 'wednesday': return 'Среда';
      case 'thursday': return 'Четверг';
      case 'friday': return 'Пятница';
      default: return day;
    }
  }

  Widget _buildLessonView(Map<String, dynamic> lesson) {
    final hasSubject = lesson['subject']?.isNotEmpty == true;
    final hasHomework = lesson['homework']?.isNotEmpty == true;
    final hasRoom = lesson['room']?.isNotEmpty == true;
    final hasNotes = lesson['notes']?.isNotEmpty == true;

    if (!hasSubject) {
      return const SizedBox.shrink();
    }

    final roleColor = _getRoleColor();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Время и предмет
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    lesson['time'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: roleColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lesson['subject'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Кабинет и учитель
            if (hasRoom || lesson['teacherName'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    if (hasRoom)
                      Row(
                        children: [
                          Icon(Icons.room, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Каб. ${lesson['room']}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    if (hasRoom && lesson['teacherName'] != null)
                      const SizedBox(width: 16),
                    if (lesson['teacherName'] != null)
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            lesson['teacherName'],
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            
            // Домашнее задание
            if (hasHomework)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.assignment, size: 16, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Домашнее задание:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lesson['homework'],
                            style: TextStyle(
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            
            // Заметки
            if (hasNotes)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lesson['notes'],
                        style: TextStyle(color: Colors.grey[700]),
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

  Widget _buildDaySelector() {
    if (_schedule.isEmpty) {
      return const SizedBox.shrink();
    }

    final roleColor = _getRoleColor();

    return Container(
      height: 70,
      color: Colors.grey[100],
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _schedule.length,
        itemBuilder: (context, index) {
          final day = _schedule[index];
          final isSelected = day['day'] == _selectedDay;
          
          return GestureDetector(
            onTap: () => _safeSetState(() => _selectedDay = day['day']),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 65),
              decoration: BoxDecoration(
                color: isSelected ? roleColor : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: roleColor),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getDayDisplayName(day['day']).substring(0, 3),
                    style: TextStyle(
                      color: isSelected ? Colors.white : roleColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    day['date']?.split('.').first ?? '',
                    style: TextStyle(
                      color: isSelected ? Colors.white : roleColor,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScheduleContent() {
    if (_schedule.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Расписание не заполнено',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Учитель еще не добавил расписание на эту неделю',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Находим текущий день
    Map<String, dynamic> currentDay;
    try {
      currentDay = _schedule.firstWhere((day) => day['day'] == _selectedDay);
    } catch (e) {
      currentDay = _schedule.first;
    }

    final hasLessons = currentDay['lessons']?.any((lesson) => 
        lesson['subject']?.isNotEmpty == true) == true;

    if (!hasLessons) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Нет уроков в ${_getDayDisplayName(_selectedDay).toLowerCase()}',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: currentDay['lessons'].length,
      itemBuilder: (context, index) {
        return _buildLessonView(currentDay['lessons'][index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = _getRoleColor();

    return Scaffold(
      appBar: AppBar(
        title: _isLoading 
            ? const Text('Загрузка...')
            : Text(_className != null 
                ? 'Расписание - $_className' 
                : 'Расписание'),
        backgroundColor: roleColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(roleColor)),
                  const SizedBox(height: 16),
                  Text(
                    'Загрузка расписания...',
                    style: TextStyle(color: roleColor),
                  ),
                ],
              ),
            )
          : _classId == null
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Не удалось загрузить расписание',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Проверьте, привязаны ли вы к классу',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildDaySelector(),
                    Expanded(child: _buildScheduleContent()),
                  ],
                ),
    );
  }
}