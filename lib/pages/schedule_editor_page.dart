import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_app/services/subjects_service.dart';

class ScheduleEditorPage extends StatefulWidget {
  final String classId;
  final String className;
  final bool isVicePrincipal;

  const ScheduleEditorPage({
    super.key,
    required this.classId,
    required this.className,
    this.isVicePrincipal = false,
  });

  @override
  State<ScheduleEditorPage> createState() => _ScheduleEditorPageState();
}

class _ScheduleEditorPageState extends State<ScheduleEditorPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  
  final Map<String, List<Map<String, String>>> _scheduleData = {};
  bool _isLoading = true;
  String _selectedDay = 'monday';

  List<Map<String, dynamic>> _schoolSubjects = [];
  final Map<String, List<Map<String, dynamic>>> _subjectTeachers = {};

  // Контроллеры
  final Map<String, List<TextEditingController>> _subjectControllers = {};
  final Map<String, List<TextEditingController>> _roomControllers = {};

  final List<String> _days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];
  final List<String> _timeSlots = [
    '08:00-08:45', '09:00-09:45', '10:00-10:45',
    '11:00-11:45', '12:00-12:45', '13:00-13:45', '14:00-14:45'
  ];

  @override
 void initState() {
  super.initState();
  _initializeData();
  _loadSubjects().then((_) {
    _loadSchedule();
  });
}
  @override
  void dispose() {
    _clearAllControllers();
    super.dispose();
  }

  void _initializeData() {
    for (var day in _days) {
      _scheduleData[day] = [];
      _subjectControllers[day] = [];
      _roomControllers[day] = [];
      
      for (var time in _timeSlots) {
        _scheduleData[day]!.add({
          'time': time,
          'subject': '',
          'room': '',
        });
        
        _subjectControllers[day]!.add(TextEditingController());
        _roomControllers[day]!.add(TextEditingController());
      }
    }
  }

  void _clearAllControllers() {
    for (var day in _days) {
      for (var controller in _subjectControllers[day]!) {
        controller.dispose();
      }
      for (var controller in _roomControllers[day]!) {
        controller.dispose();
      }
    }
    _subjectControllers.clear();
    _roomControllers.clear();
  }

  Future<void> _loadSchedule() async {
    print('Загрузка расписания для класса ${widget.classId}');
    
    try {

      final scheduleDoc = await _firestore
          .collection('schedules')
          .doc(widget.classId)
          .get();

      if (scheduleDoc.exists) {
        print(' Найден документ с ID класса');
        _processScheduleData(scheduleDoc.data()!);
      } else {
        final scheduleQuery = await _firestore
            .collection('schedules')
            .where('classId', isEqualTo: widget.classId)
            .limit(1)
            .get();

        if (scheduleQuery.docs.isNotEmpty) {
          print(' Найден документ в запросе');
          _processScheduleData(scheduleQuery.docs.first.data());
        } else {
          print(' Расписание не найдено, используем пустое');
        }
      }
    } catch (e) {
      print(' Ошибка загрузки: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _processScheduleData(Map<String, dynamic> data) {
  print(' Обработка данных: $data');
  
  if (data['days'] != null) {
    final days = data['days'] as List<dynamic>;
    
    for (var dayData in days) {
      final day = dayData['day'] as String;
      final lessons = dayData['lessons'] as List<dynamic>;
      
      if (_scheduleData.containsKey(day)) {
        for (int i = 0; i < lessons.length && i < _timeSlots.length; i++) {
          final lesson = lessons[i] as Map<String, dynamic>;
          
          _scheduleData[day]![i] = {
            'time': _timeSlots[i],
            'subject': lesson['subject']?.toString() ?? '',
            'subjectId': lesson['subjectId']?.toString() ?? '',
            'teacher': lesson['teacher']?.toString() ?? '',
            'teacherId': lesson['teacherId']?.toString() ?? '',
            'room': lesson['room']?.toString() ?? '',
          };
          

          _subjectControllers[day]![i].text = lesson['subject']?.toString() ?? '';
          _roomControllers[day]![i].text = lesson['room']?.toString() ?? '';
        }
      }
    }
    
    print('Данные обработаны, загружены учителя');
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

  Widget _buildLessonCard(int lessonIndex) {
  final dayData = _scheduleData[_selectedDay]![lessonIndex];
  final subjectController = _subjectControllers[_selectedDay]![lessonIndex];
  final roomController = _roomControllers[_selectedDay]![lessonIndex];
  final teacherController = TextEditingController(); 

  Map<String, dynamic>? selectedSubject;
  String? selectedSubjectId;
  
  if (subjectController.text.isNotEmpty) {
    selectedSubject = _schoolSubjects.firstWhere(
      (subject) => subject['subjectName'] == subjectController.text,
      orElse: () => _schoolSubjects.isNotEmpty ? _schoolSubjects.first : {},
    );
    selectedSubjectId = selectedSubject['subjectId'];
  }

  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Время урока
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              dayData['time']!,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          DropdownButtonFormField<String>(
            initialValue: selectedSubjectId,
            decoration: const InputDecoration(
              labelText: 'Предмет',
              border: OutlineInputBorder(),
            ),
            items: _schoolSubjects.map((subject) {
              return DropdownMenuItem<String>(
                value: subject['subjectId'],
                child: Text(subject['subjectName']),
              );
            }).toList(),
            onChanged: widget.isVicePrincipal ? (String? newValue) {
    if (newValue != null) {
      final subject = _schoolSubjects.firstWhere(
        (s) => s['subjectId'] == newValue,
        orElse: () => {'subjectName': ''},
      );
      subjectController.text = subject['subjectName'];
      _scheduleData[_selectedDay]![lessonIndex]['subject'] = subject['subjectName'];
      _scheduleData[_selectedDay]![lessonIndex]['subjectId'] = newValue;
      
      final teachers = _subjectTeachers[newValue] ?? [];
      if (teachers.isNotEmpty) {
        _scheduleData[_selectedDay]![lessonIndex]['teacher'] = teachers.first['teacherName'];
        _scheduleData[_selectedDay]![lessonIndex]['teacherId'] = teachers.first['teacherId'];
      }
      
      setState(() {});
    }
  } : null,
          ),
          
          const SizedBox(height: 8),
          
          if (selectedSubjectId != null && 
              _subjectTeachers.containsKey(selectedSubjectId) &&
              _subjectTeachers[selectedSubjectId]!.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _scheduleData[_selectedDay]![lessonIndex]['teacherId'],
              decoration: const InputDecoration(
                labelText: 'Учитель',
                border: OutlineInputBorder(),
              ),
              items: _subjectTeachers[selectedSubjectId]!.map((teacher) {
                return DropdownMenuItem<String>(
                  value: teacher['teacherId'],
                  child: Text(teacher['teacherName']),
                );
              }).toList(),
              onChanged: widget.isVicePrincipal ? (String? newValue) {
    if (newValue != null) {
      final teacher = _subjectTeachers[selectedSubjectId]!.firstWhere(
        (t) => t['teacherId'] == newValue,
      );
      _scheduleData[_selectedDay]![lessonIndex]['teacher'] = teacher['teacherName'];
      _scheduleData[_selectedDay]![lessonIndex]['teacherId'] = newValue;
    }
  } : null,
            ),
          
          const SizedBox(height: 8),
          
          TextField(
            controller: roomController,
            decoration: const InputDecoration(
              labelText: 'Кабинет',
              hintText: '25',
              border: OutlineInputBorder(),
            ),
            enabled: widget.isVicePrincipal,
            onChanged: (value) {
              _scheduleData[_selectedDay]![lessonIndex]['room'] = value;
            },
          ),
        ],
      ),
    ),
  );
 }

  Future<void> _saveSchedule() async {
    if (_currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      final daysToSave = _days.map((day) {
       return {
         'day': day,
         'lessons': _scheduleData[day]!.map((lesson) {
           return {
             'time': lesson['time'],
            'subject': lesson['subject'],
            'subjectId': lesson['subjectId'],
            'teacher': lesson['teacher'],
            'teacherId': lesson['teacherId'],
             'room': lesson['room'],
        };
          }).toList(),
        };
       }).toList();

      print('Сохранение расписания...');
      print('Дней: ${daysToSave.length}');
      print('Данные первого дня: ${daysToSave.first}');

      await _firestore.collection('schedules').doc(widget.classId).set({
        'scheduleId': widget.classId,
        'classId': widget.classId,
        'className': widget.className,
        'isPermanent': true,
        'createdBy': _currentUser.uid,
        'createdByName': widget.isVicePrincipal ? 'Завуч' : 'Учитель',
        'days': daysToSave,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print(' Расписание сохранено!');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Расписание сохранено!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      
    } catch (e) {
      print(' Ошибка сохранения: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка сохранения: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearDay() {
    if (!widget.isVicePrincipal) return;
    
    for (int i = 0; i < _timeSlots.length; i++) {
      _scheduleData[_selectedDay]![i] = {
        'time': _timeSlots[i],
        'subject': '',
        'room': '',
      };
      _subjectControllers[_selectedDay]![i].clear();
      _roomControllers[_selectedDay]![i].clear();
    }
    
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Расписание - ${widget.className}'),
        backgroundColor: widget.isVicePrincipal ? Colors.purple : Colors.green,
        foregroundColor: Colors.white,
        actions: [
          if (widget.isVicePrincipal) ...[
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearDay,
              tooltip: 'Очистить день',
            ),
            IconButton(
              icon: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : const Icon(Icons.save),
              onPressed: _isLoading ? null : _saveSchedule,
              tooltip: 'Сохранить расписание',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Выбор дня недели
                Container(
                  height: 70,
                  color: Colors.grey[100],
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _days.length,
                    itemBuilder: (context, index) {
                      final day = _days[index];
                      final isSelected = day == _selectedDay;
                      final bgColor = widget.isVicePrincipal ? Colors.purple : Colors.green;
                      
                      return GestureDetector(
                        onTap: () => setState(() => _selectedDay = day),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          margin: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(minWidth: 65),
                          decoration: BoxDecoration(
                            color: isSelected ? bgColor : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: bgColor),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _getDayDisplayName(day).substring(0, 3),
                                style: TextStyle(
                                  color: isSelected ? Colors.white : bgColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'День ${index + 1}',
                                style: TextStyle(
                                  color: isSelected ? Colors.white : bgColor,
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

                // Информация
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.blue[50],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.isVicePrincipal ? Icons.edit : Icons.visibility,
                        size: 16,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.isVicePrincipal 
                          ? 'Редактирование - ${_getDayDisplayName(_selectedDay)}'
                          : 'Просмотр - ${_getDayDisplayName(_selectedDay)}',
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ],
                  ),
                ),

                // Расписание
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ListView.builder(
                      itemCount: _timeSlots.length,
                      itemBuilder: (context, index) {
                        return _buildLessonCard(index);
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

 Future<void> _loadSubjects() async {
  try {
    // Получаем schoolId из класса
    final classDoc = await _firestore.collection('classes').doc(widget.classId).get();
    final schoolId = classDoc.data()?['schoolId'];
    
    if (schoolId == null) return;

    // Используем SubjectsService
    final subjectsService = SubjectsService();
    _schoolSubjects = await subjectsService.getSubjectsForSchedule(schoolId);
    
    // Собираем учителей для каждого предмета
    for (final subject in _schoolSubjects) {
      final teachers = subject['teachers'] as List<Map<String, dynamic>>;
      _subjectTeachers[subject['subjectId']] = teachers;
    }
    
    print('Загружено предметов: ${_schoolSubjects.length}');
  } catch (e) {
    print(' Ошибка загрузки предметов: $e');
  }
 } 
}