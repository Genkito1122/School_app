import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScheduleViewPage extends StatefulWidget {
  final String? childId;
  final String? childName;
  final String? childClassId;
  final String? childClassName;
  
  const ScheduleViewPage({
    super.key,
    this.childId,
    this.childName,
    this.childClassId,
    this.childClassName,
  });

  @override
  State<ScheduleViewPage> createState() => _ScheduleViewPageState();
}

class _ScheduleViewPageState extends State<ScheduleViewPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  
  Map<String, dynamic>? _scheduleData;
  bool _isLoading = true;
  String _selectedDay = 'monday';
  String? _classId;
  String? _className;
  String? _userRole;
  String _errorMessage = '';
  
  // Для переключения между детьми
  List<Map<String, dynamic>> _children = [];
  String? _selectedChildId;
  String? _selectedChildName;
  String? _selectedChildClassId;
  String? _selectedChildClassName;
  bool _isParent = false;

  final List<String> _days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_currentUser == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Пользователь не авторизован';
      });
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      final userRole = userDoc.data()?['role'];
      setState(() => _userRole = userRole);

      if (userRole == 'student') {
        await _loadStudentSchedule(_currentUser!.uid);
      } else if (userRole == 'parent') {
        _isParent = true;
        await _loadParentData(_currentUser!.uid);
      } else if (userRole == 'teacher') {
        await _loadTeacherSchedule(_currentUser!.uid);
      }
    } catch (e) {
      print('❌ Ошибка: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ошибка загрузки: ${e.toString()}';
      });
    }
  }

  Future<void> _loadStudentSchedule(String studentId) async {
    final studentDoc = await _firestore.collection('students').doc(studentId).get();
    if (studentDoc.exists) {
      final data = studentDoc.data()!;
      setState(() {
        _classId = data['classId'];
        _className = data['className'];
      });
      await _loadSchedule();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Данные ученика не найдены';
      });
    }
  }

  Future<void> _loadTeacherSchedule(String teacherId) async {
    final teacherDoc = await _firestore.collection('teachers').doc(teacherId).get();
    if (teacherDoc.exists) {
      final classIds = List<String>.from(teacherDoc.data()?['classIds'] ?? []);
      if (classIds.isNotEmpty) {
        final classDoc = await _firestore.collection('classes').doc(classIds.first).get();
        if (classDoc.exists) {
          setState(() {
            _classId = classDoc.id;
            _className = classDoc.data()?['name'];
          });
          await _loadSchedule();
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Класс не найден';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Нет привязанных классов';
        });
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Данные учителя не найдены';
      });
    }
  }

  Future<void> _loadParentData(String parentId) async {
    final parentDoc = await _firestore.collection('parents').doc(parentId).get();
    if (parentDoc.exists) {
      final childIds = List<String>.from(parentDoc.data()?['childIds'] ?? []);
      
      if (childIds.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Нет привязанных детей';
        });
        return;
      }

      // Загружаем всех детей
      List<Map<String, dynamic>> childrenList = [];
      for (final childId in childIds) {
        final childDoc = await _firestore.collection('students').doc(childId).get();
        if (childDoc.exists) {
          childrenList.add({
            'uid': childId,
            'fullName': childDoc.data()?['fullName'] ?? 'Неизвестно',
            'classId': childDoc.data()?['classId'],
            'className': childDoc.data()?['className'],
          });
        }
      }

      // Выбираем переданного или первого
      String? activeId = widget.childId ?? (childrenList.isNotEmpty ? childrenList.first['uid'] : null);
      
      setState(() => _children = childrenList);
      
      if (activeId != null) {
        await _switchToChild(activeId, childrenList);
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _switchToChild(String childId, List<Map<String, dynamic>> childrenList) async {
    final child = childrenList.firstWhere(
      (c) => c['uid'] == childId,
      orElse: () => childrenList.first,
    );

    setState(() {
      _selectedChildId = child['uid'];
      _selectedChildName = child['fullName'];
      _selectedChildClassId = child['classId'];
      _selectedChildClassName = child['className'];
      _classId = child['classId'];
      _className = child['className'];
      _scheduleData = null;
    });

    await _loadSchedule();
  }

  Future<void> _switchChild(String newChildId) async {
    setState(() => _isLoading = true);
    await _switchToChild(newChildId, _children);
  }

  Widget _buildChildSelector() {
    if (!_isParent || _children.length <= 1) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.orange[50],
      child: Row(
        children: [
          const Text('Ребёнок:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: DropdownButton<String>(
                value: _selectedChildId,
                isExpanded: true,
                underline: const SizedBox(),
                items: _children.map((child) {
                  return DropdownMenuItem<String>(
                    value: child['uid'],
                    child: Text(
                      '${child['fullName']} (${child['className']})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null && newValue != _selectedChildId) {
                    _switchChild(newValue);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSchedule() async {
    if (_classId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'ID класса не определен';
      });
      return;
    }

    try {
      final scheduleDoc = await _firestore.collection('schedules').doc(_classId!).get();

      if (scheduleDoc.exists) {
        setState(() {
          _scheduleData = scheduleDoc.data();
          _errorMessage = '';
        });
      } else {
        final query = await _firestore
            .collection('schedules')
            .where('classId', isEqualTo: _classId)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          setState(() {
            _scheduleData = query.docs.first.data();
            _errorMessage = '';
          });
        } else {
          setState(() => _errorMessage = 'Расписание для класса "$_className" еще не создано');
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Ошибка загрузки расписания: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
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

  List<Map<String, dynamic>> _getLessonsForDay(String day) {
    if (_scheduleData == null || _scheduleData!['days'] == null) return [];
    
    try {
      final days = _scheduleData!['days'] as List<dynamic>;
      for (var dayData in days) {
        if (dayData['day'] == day) {
          final lessons = dayData['lessons'] as List<dynamic>? ?? [];
          return lessons.map((lesson) {
            if (lesson is Map<String, dynamic>) return lesson;
            return {'subject': '', 'room': '', 'time': '', 'teacher': ''};
          }).toList();
        }
      }
    } catch (e) {
      print('❌ Ошибка: $e');
    }
    return [];
  }

  Widget _buildLessonView(Map<String, dynamic> lesson) {
    final subject = lesson['subject']?.toString() ?? '';
    final room = lesson['room']?.toString() ?? '';
    final time = lesson['time']?.toString() ?? '';
    final teacher = lesson['teacher']?.toString() ?? '';
    
    if (subject.isEmpty) return const SizedBox.shrink();

    final roleColor = _getRoleColor(_userRole);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(time, style: TextStyle(fontWeight: FontWeight.bold, color: roleColor)),
            ),
            const SizedBox(height: 8),
            Text(subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            if (teacher.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.person, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(teacher, style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            if (room.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.room, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('Каб. $room', style: const TextStyle(color: Colors.grey)),
                ],
              ),
          ],
        ),
      ),
    );
  }

    @override
  Widget build(BuildContext context) {
    final roleColor = _getRoleColor(_userRole);
    final displayName = _isParent ? (_selectedChildName ?? 'Ребёнок') : (_className ?? 'Расписание');

    return Scaffold(
      appBar: AppBar(
        title: Text('Расписание - $displayName'),
        backgroundColor: roleColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadUserData();
            },
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildChildSelector(),
                Expanded(child: _buildContent()),
              ],
            ),
    );
  }

  Widget _buildContent() {
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.orange[700]),
            const SizedBox(height: 16),
            Text(_errorMessage, style: const TextStyle(fontSize: 16, color: Colors.orange), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadUserData, child: const Text('Повторить')),
          ],
        ),
      );
    }

    if (_classId == null || _scheduleData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.schedule, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Расписание не найдено', style: TextStyle(color: Colors.grey)),
            if (_className != null) Text('Класс: $_className', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadSchedule, child: const Text('Загрузить расписание')),
          ],
        ),
      );
    }

    final roleColor = _getRoleColor(_userRole);
    
    final lessons = _getLessonsForDay(_selectedDay);
    final hasLessons = lessons.any((l) => (l['subject']?.toString() ?? '').isNotEmpty);

    return Column(
      children: [
        Container(
          height: 70,
          color: Colors.grey[100],
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _days.length,
            itemBuilder: (context, index) {
              final day = _days[index];
              final isSelected = day == _selectedDay;
              final dayLessons = _getLessonsForDay(day);
              final dayHasLessons = dayLessons.any((l) => (l['subject']?.toString() ?? '').isNotEmpty);
              
              return GestureDetector(
                onTap: () => setState(() => _selectedDay = day),
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
                        _getDayDisplayName(day).substring(0, 3),
                        style: TextStyle(
                          color: isSelected ? Colors.white : roleColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (dayHasLessons)
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)))
                      else
                        Text('День ${index + 1}', style: TextStyle(color: isSelected ? Colors.white : roleColor, fontSize: 11)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          color: roleColor.withOpacity(0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today, size: 16, color: roleColor),
              const SizedBox(width: 8),
              Text(_getDayDisplayName(_selectedDay), style: TextStyle(color: roleColor, fontWeight: FontWeight.bold)),
              if (!hasLessons) const SizedBox(width: 8),
              if (!hasLessons) Text('(Нет уроков)', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
        Expanded(
          child: hasLessons
              ? ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: lessons.where((l) => (l['subject']?.toString() ?? '').isNotEmpty).length,
                  itemBuilder: (context, index) {
                    final filtered = lessons.where((l) => (l['subject']?.toString() ?? '').isNotEmpty).toList();
                    return _buildLessonView(filtered[index]);
                  },
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.schedule, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('Нет уроков в ${_getDayDisplayName(_selectedDay).toLowerCase()}',
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}