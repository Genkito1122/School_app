import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScheduleEditorPage extends StatefulWidget {
  final String classId;
  final String className;

  const ScheduleEditorPage({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<ScheduleEditorPage> createState() => _ScheduleEditorPageState();
}

class _ScheduleEditorPageState extends State<ScheduleEditorPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  
  List<Map<String, dynamic>> _schedule = [];
  bool _isLoading = true;
  String _selectedDay = 'monday';

  // Храним контроллеры для избежания инверсного текста
  final Map<String, Map<int, TextEditingController>> _subjectControllers = {};
  final Map<String, Map<int, TextEditingController>> _homeworkControllers = {};
  final Map<String, Map<int, TextEditingController>> _roomControllers = {};
  final Map<String, Map<int, TextEditingController>> _notesControllers = {};

  final List<String> _days = [
    'monday',
    'tuesday', 
    'wednesday',
    'thursday',
    'friday'
  ];

  final List<String> _timeSlots = [
    '08:00-08:45',
    '09:00-09:45',
    '10:00-10:45',
    '11:00-11:45',
    '12:00-12:45',
    '13:00-13:45',
    '14:00-14:45',
  ];

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  @override
  void dispose() {
    // Очищаем все контроллеры
    _clearAllControllers();
    super.dispose();
  }

  void _clearAllControllers() {
    for (var dayMap in _subjectControllers.values) {
      for (var controller in dayMap.values) {
        controller.dispose();
      }
    }
    for (var dayMap in _homeworkControllers.values) {
      for (var controller in dayMap.values) {
        controller.dispose();
      }
    }
    for (var dayMap in _roomControllers.values) {
      for (var controller in dayMap.values) {
        controller.dispose();
      }
    }
    for (var dayMap in _notesControllers.values) {
      for (var controller in dayMap.values) {
        controller.dispose();
      }
    }
    _subjectControllers.clear();
    _homeworkControllers.clear();
    _roomControllers.clear();
    _notesControllers.clear();
  }

  void _initializeControllers() {
    for (var day in _days) {
      _subjectControllers[day] = {};
      _homeworkControllers[day] = {};
      _roomControllers[day] = {};
      _notesControllers[day] = {};
      
      for (int i = 0; i < _timeSlots.length; i++) {
        _subjectControllers[day]![i] = TextEditingController();
        _homeworkControllers[day]![i] = TextEditingController();
        _roomControllers[day]![i] = TextEditingController();
        _notesControllers[day]![i] = TextEditingController();
      }
    }
  }

  void _updateControllersFromData() {
    for (int dayIndex = 0; dayIndex < _schedule.length; dayIndex++) {
      final day = _schedule[dayIndex];
      final dayName = day['day'];
      
      for (int lessonIndex = 0; lessonIndex < day['lessons'].length; lessonIndex++) {
        final lesson = day['lessons'][lessonIndex];
        
        _subjectControllers[dayName]?[lessonIndex]?.text = lesson['subject'] ?? '';
        _homeworkControllers[dayName]?[lessonIndex]?.text = lesson['homework'] ?? '';
        _roomControllers[dayName]?[lessonIndex]?.text = lesson['room'] ?? '';
        _notesControllers[dayName]?[lessonIndex]?.text = lesson['notes'] ?? '';
      }
    }
  }

  Future<void> _loadSchedule() async {
    try {
      final now = DateTime.now();
      final weekStart = DateTime(now.year, now.month, now.day - now.weekday + 1);
      
      final scheduleDoc = await _firestore
          .collection('schedules')
          .where('classId', isEqualTo: widget.classId)
          .where('weekStart', isEqualTo: Timestamp.fromDate(weekStart))
          .limit(1)
          .get();

      if (scheduleDoc.docs.isNotEmpty) {
        final data = scheduleDoc.docs.first.data();
        setState(() {
          _schedule = List<Map<String, dynamic>>.from(data['days'] ?? []);
        });
      } else {
        _initializeEmptySchedule();
      }
    } catch (e) {
      print('Ошибка загрузки расписания: $e');
      _initializeEmptySchedule();
    } finally {
      // Инициализируем контроллеры после загрузки данных
      _initializeControllers();
      _updateControllersFromData();
      setState(() => _isLoading = false);
    }
  }

  void _initializeEmptySchedule() {
    setState(() {
      _schedule = _days.map((day) => {
        'day': day,
        'date': _getDateForDay(day),
        'lessons': _timeSlots.map((time) => _createEmptyLesson(time)).toList(),
      }).toList();
    });
  }

  Map<String, dynamic> _createEmptyLesson(String time) {
    return {
      'time': time,
      'subject': '',
      'homework': '',
      'room': '',
      'notes': ''
    };
  }

  String _getDateForDay(String day) {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day - now.weekday + 1);
    
    final dayIndex = _days.indexOf(day);
    final date = weekStart.add(Duration(days: dayIndex));
    
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
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

  Widget _buildLessonCard(Map<String, dynamic> lesson, int lessonIndex) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Заголовок с временем
            Row(
              children: [
                Text(
                  lesson['time'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () => _clearLesson(lessonIndex),
                  tooltip: 'Очистить урок',
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Поле предмета
            TextField(
              controller: _subjectControllers[_selectedDay]?[lessonIndex],
              decoration: const InputDecoration(
                labelText: 'Предмет',
                hintText: 'Математика, Русский язык...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (value) => _updateLessonField(lessonIndex, 'subject', value),
            ),
            const SizedBox(height: 8),
            
            // Поле ДЗ
            TextField(
              controller: _homeworkControllers[_selectedDay]?[lessonIndex],
              decoration: const InputDecoration(
                labelText: 'Домашнее задание',
                hintText: 'стр. 25-26, упр. 5-8',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              maxLines: 2,
              onChanged: (value) => _updateLessonField(lessonIndex, 'homework', value),
            ),
            const SizedBox(height: 8),
            
            // ФИКС ПЕРЕПОЛНЕНИЯ: Кабинет и заметки в колонке
            Column(
              children: [
                // Кабинет
                TextField(
                  controller: _roomControllers[_selectedDay]?[lessonIndex],
                  decoration: const InputDecoration(
                    labelText: 'Кабинет',
                    hintText: '25',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (value) => _updateLessonField(lessonIndex, 'room', value),
                ),
                const SizedBox(height: 8),
                
                // Заметки
                TextField(
                  controller: _notesControllers[_selectedDay]?[lessonIndex],
                  decoration: const InputDecoration(
                    labelText: 'Заметки (необязательно)',
                    hintText: 'Контрольная, принести тетрадь...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  maxLines: 2,
                  onChanged: (value) => _updateLessonField(lessonIndex, 'notes', value),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateLessonField(int lessonIndex, String field, String value) {
    final dayIndex = _days.indexOf(_selectedDay);
    if (dayIndex < _schedule.length && lessonIndex < _schedule[dayIndex]['lessons'].length) {
      setState(() {
        _schedule[dayIndex]['lessons'][lessonIndex][field] = value;
      });
    }
  }

  void _clearLesson(int lessonIndex) {
    final dayIndex = _days.indexOf(_selectedDay);
    if (dayIndex < _schedule.length && lessonIndex < _schedule[dayIndex]['lessons'].length) {
      setState(() {
        _schedule[dayIndex]['lessons'][lessonIndex] = _createEmptyLesson(
          _schedule[dayIndex]['lessons'][lessonIndex]['time']
        );
        
        // Очищаем контроллеры
        _subjectControllers[_selectedDay]?[lessonIndex]?.clear();
        _homeworkControllers[_selectedDay]?[lessonIndex]?.clear();
        _roomControllers[_selectedDay]?[lessonIndex]?.clear();
        _notesControllers[_selectedDay]?[lessonIndex]?.clear();
      });
    }
  }

  Future<void> _saveSchedule() async {
  if (_currentUser == null) return;

  setState(() => _isLoading = true);

  try {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day - now.weekday + 1);
    final weekEnd = weekStart.add(const Duration(days: 6));

    final teacherDoc = await _firestore.collection('teachers').doc(_currentUser!.uid).get();
    final teacherName = teacherDoc.data()?['fullName'] ?? 'Учитель';

    // Добавляем информацию об учителе в каждый урок
    for (var day in _schedule) {
      for (var lesson in day['lessons']) {
        if (lesson['subject']?.isNotEmpty == true) {
          lesson['teacherId'] = _currentUser!.uid;
          lesson['teacherName'] = teacherName;
        }
      }
    }

    await _firestore.collection('schedules').doc('${widget.classId}_${weekStart.millisecondsSinceEpoch}').set({
      'scheduleId': '${widget.classId}_${weekStart.millisecondsSinceEpoch}',
      'classId': widget.classId,
      'className': widget.className,
      'schoolId': teacherDoc.data()?['schoolId'],
      'weekStart': Timestamp.fromDate(weekStart),
      'weekEnd': Timestamp.fromDate(weekEnd),
      
      // ✅ ДОБАВЛЕНЫ ЯВНЫЕ СВЯЗИ:
      'createdBy': _currentUser!.uid,
      'createdByRef': 'teachers/${_currentUser!.uid}',
      'createdByTeacherName': teacherName,
      
      'days': _schedule,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Расписание сохранено!'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ошибка сохранения: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() => _isLoading = false);
  }
 }

  @override
Widget build(BuildContext context) {
  if (_isLoading && _schedule.isEmpty) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  // ✅ ФИКС: Исправляем проблему с firstWhere
  Map<String, dynamic> currentDay;
  try {
    currentDay = _schedule.firstWhere(
      (day) => day['day'] == _selectedDay,
    );
  } catch (e) {
    // Если день не найден, используем первый день или создаем пустой
    currentDay = _schedule.isNotEmpty 
        ? _schedule.first 
        : {
            'day': 'monday',
            'lessons': _timeSlots.map((time) => _createEmptyLesson(time)).toList(),
          };
  }

    return Scaffold(
      appBar: AppBar(
        title: Text('Расписание - ${widget.className}'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveSchedule,
            tooltip: 'Сохранить расписание',
          ),
        ],
      ),
      body: Column(
        children: [
          // Выбор дня недели
          Container(
            height: 70,
            color: Colors.grey[100],
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _schedule.length,
              itemBuilder: (context, index) {
                final day = _schedule[index];
                final isSelected = day['day'] == _selectedDay;
                
                return GestureDetector(
                  onTap: () => setState(() => _selectedDay = day['day']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    margin: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 65),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.green : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _getDayDisplayName(day['day']).substring(0, 3),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          day['date']?.split('.').first ?? '',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.green,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Список уроков
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView.builder(
                itemCount: currentDay['lessons'].length,
                itemBuilder: (context, index) {
                  return _buildLessonCard(currentDay['lessons'][index], index);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}