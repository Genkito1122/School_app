import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_app/services/code_service.dart';
import 'package:school_app/pages/main_page.dart';
import 'package:school_app/services/chat_service.dart';

class ProfileSetupPage extends StatefulWidget {
  final String uid;
  final String role;
  final Map<String, dynamic>? teacherSchoolInfo;
  final Map<String, dynamic>? studentClassInfo;
  final String? adminCode;
  final String? usedTeacherCode;
  final String? usedStudentCode;
  
  const ProfileSetupPage({
    super.key,
    required this.uid,
    required this.role,
    this.teacherSchoolInfo,
    this.studentClassInfo,
    this.adminCode,
    this.usedTeacherCode,
    this.usedStudentCode,
  });

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _classController = TextEditingController();
  final _teacherNameController = TextEditingController();
  final _childEmailController = TextEditingController();
  final _schoolNameController = TextEditingController();
  final _schoolAddressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _adminCodeController = TextEditingController();
  final ChatService _chatService = ChatService();
  
  bool _isLoading = false;
  final CodeService _codeService = CodeService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    if (widget.adminCode != null) {
      _adminCodeController.text = widget.adminCode!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Заполните профиль'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildRoleHeader(),
              const SizedBox(height: 20),

              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'ФИО',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                  hintText: 'Иванов Иван Иванович',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите ФИО';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              ..._buildRoleSpecificFields(),

              const SizedBox(height: 30),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleHeader() {
    String title = '';
    String description = '';
    
    switch (widget.role) {
      case 'student':
        title = 'Данные ученика';
        description = widget.studentClassInfo != null 
            ? 'Класс: ${widget.studentClassInfo!['className']} | Школа: ${widget.studentClassInfo!['schoolName']}'
            : 'Заполните данные ученика';
        break;
      case 'teacher':
        title = 'Данные учителя';
        description = widget.teacherSchoolInfo != null 
            ? 'Школа: ${widget.teacherSchoolInfo!['schoolName']}'
            : 'Заполните данные учителя';
        break;
      case 'parent':
        title = 'Данные родителя';
        description = 'Привяжите аккаунт к ребёнку';
        break;
      case 'director':
        title = 'Данные директора';
        description = 'Создание новой школы';
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            _getRoleIcon(widget.role),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(description, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRoleSpecificFields() {
    switch (widget.role) {
      case 'student':
        return [
          if (widget.studentClassInfo != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Автоматическая привязка:',
                        style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('🏫 Школа: ${widget.studentClassInfo!['schoolName']}'),
                  Text('📚 Класс: ${widget.studentClassInfo!['className']}'),
                ],
              ),
            ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _birthDateController,
            decoration: const InputDecoration(
              labelText: 'Дата рождения',
              prefixIcon: Icon(Icons.cake),
              border: OutlineInputBorder(),
              hintText: 'дд.мм.гггг',
            ),
            onTap: () => _selectDate(context),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Введите дату рождения';
              }
              return null;
            },
          ),
        ];

      case 'teacher':
        return [
          if (widget.teacherSchoolInfo != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Школа: ${widget.teacherSchoolInfo!['schoolName']}',
                      style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Телефон',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
              hintText: '+7 (999) 123-45-67',
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Введите телефон';
              }
              return null;
            },
          ),
        ];

      case 'parent':
        return [
          TextFormField(
            controller: _childEmailController,
            decoration: const InputDecoration(
              labelText: 'Email ребёнка',
              prefixIcon: Icon(Icons.child_care),
              border: OutlineInputBorder(),
              hintText: 'email@example.com',
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Введите email ребёнка';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Ваш телефон',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Введите телефон';
              }
              return null;
            },
          ),
        ];

      case 'director':
        return [
          Text(
            'Для создания школы нужен код администратора',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 16),
          
          if (widget.adminCode == null)
            TextFormField(
              controller: _adminCodeController,
              decoration: const InputDecoration(
                labelText: 'Код администратора',
                prefixIcon: Icon(Icons.vpn_key),
                border: OutlineInputBorder(),
                hintText: 'Получите у администратора системы',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите код администратора';
                }
                return null;
              },
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Код администратора подтверждён',
                    style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 16),
          TextFormField(
            controller: _schoolNameController,
            decoration: const InputDecoration(
              labelText: 'Название школы',
              prefixIcon: Icon(Icons.school),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Введите название школы';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _schoolAddressController,
            decoration: const InputDecoration(
              labelText: 'Адрес школы',
              prefixIcon: Icon(Icons.location_on),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Введите адрес школы';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Ваш телефон',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Введите телефон';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Text(
            'После отправки заявки администратор свяжется с вами',
            style: TextStyle(color: Colors.blue[700], fontSize: 12),
          ),
        ];

      default:
        return [];
    }
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                widget.role == 'director' ? 'Отправить заявку' : 'Сохранить профиль',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      final userEmail = user?.email ?? '';

      switch (widget.role) {
        case 'student':
          await _firestore.collection('students').doc(widget.uid).set({
            'uid': widget.uid,
            'fullName': _fullNameController.text,
            'classId': widget.studentClassInfo!['classId'],
            'className': widget.studentClassInfo!['className'],
            'schoolId': widget.studentClassInfo!['schoolId'],
            'schoolName': widget.studentClassInfo!['schoolName'],
            'teacherId': widget.studentClassInfo!['teacherId'],
            'birthDate': _birthDateController.text,
            'email': userEmail,
            'parentIds': [],
            'createdAt': FieldValue.serverTimestamp(),
          });

          await _chatService.addStudentToClassChat(
            classId: widget.studentClassInfo!['classId'],
            studentId: widget.uid,
            studentName: _fullNameController.text,
          );

          if (widget.usedStudentCode != null) {
            await _codeService.useStudentCode(
              widget.studentClassInfo!['classId'],
              widget.usedStudentCode!
            );
          }
          break;

        case 'teacher':
          await _firestore.collection('teachers').doc(widget.uid).set({
            'uid': widget.uid,
            'fullName': _fullNameController.text,
            'schoolId': widget.teacherSchoolInfo!['schoolId'],
            'schoolName': widget.teacherSchoolInfo!['schoolName'],
            'phone': _phoneController.text,
            'email': userEmail,
            'classIds': [],
            'subjects': [],
            'createdAt': FieldValue.serverTimestamp(),
          });

          await _chatService.updateTeachersChatOnNewTeacher(
                widget.teacherSchoolInfo!['schoolId'],
                widget.uid,
                _fullNameController.text,
              );

          if (widget.usedTeacherCode != null) {
            await _codeService.useTeacherCode(
              widget.teacherSchoolInfo!['schoolId'], 
              widget.usedTeacherCode!
            );
          }
          break;

        case 'parent':
          // Ищем ребенка по email
          final childStudent = await _findStudentByEmail(_childEmailController.text.trim());
          if (childStudent == null) {
            _showError('Ученик с таким email не найден');
            setState(() => _isLoading = false);
            return;
          }

          await _firestore.collection('parents').doc(widget.uid).set({
            'uid': widget.uid,
            'fullName': _fullNameController.text,
            'childEmail': _childEmailController.text.trim(),
            'phone': _phoneController.text,
            'email': userEmail,
            'childIds': [childStudent['uid']],
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Обновляем запись ученика - добавляем parentId
          await _firestore.collection('students').doc(childStudent['uid']).update({
            'parentIds': FieldValue.arrayUnion([widget.uid]),
          });

          // Добавляем родителя в классный чат ребенка
          await _addParentToClassChat(
            parentId: widget.uid,
            parentName: _fullNameController.text,
            childClassId: childStudent['classId'],
          );

          print('✅ Родитель привязан к ребенку: ${childStudent['fullName']}');
          break;

        case 'director':
  final adminCode = _adminCodeController.text.trim().isNotEmpty 
      ? _adminCodeController.text.trim()
      : widget.adminCode;

  if (adminCode == null || adminCode.isEmpty) {
    _showError('Введите код администратора');
    setState(() => _isLoading = false);
    return;
  }

  final isValidAdminCode = await _codeService.verifyAdminCode(adminCode);
  if (!isValidAdminCode) {
    _showError('Неверный код администратора');
    setState(() => _isLoading = false);
    return;
  }

  await _codeService.createDirectorRequest(
    userId: widget.uid,
    fullName: _fullNameController.text,
    schoolName: _schoolNameController.text,
    schoolAddress: _schoolAddressController.text,
    email: userEmail,
    phone: _phoneController.text,
    adminCode: adminCode,
  );

  // ✅ ИСПОЛЬЗОВАТЬ КОД С ССЫЛКОЙ НА ДИРЕКТОРА
  await _codeService.useAdminCode(adminCode, widget.uid);
  
  _showSuccess('Заявка отправлена! Ожидайте подтверждения администратора.');
  await Future.delayed(const Duration(seconds: 2));
  
  await _auth.signOut();
  return;
      }

      await _firestore.collection('users').doc(widget.uid).update({
        'role': widget.role,
        'profileComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainPage()),
      );

    } catch (e) {
      _showError('Ошибка сохранения: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Вспомогательные методы
  Future<Map<String, dynamic>?> _findStudentByEmail(String email) async {
    try {
      final snapshot = await _firestore
          .collection('students')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final studentData = snapshot.docs.first.data();
        return {
          'uid': snapshot.docs.first.id,
          'fullName': studentData['fullName'],
          'className': studentData['className'],
          'classId': studentData['classId'],
          'schoolId': studentData['schoolId'],
        };
      }
      return null;
    } catch (e) {
      print('Ошибка поиска ученика: $e');
      return null;
    }
  }

  Future<void> _addParentToClassChat({
    required String parentId,
    required String parentName,
    required String childClassId,
  }) async {
    try {
      // Ищем классный чат
      final chatSnapshot = await _firestore
          .collection('chats')
          .where('classId', isEqualTo: childClassId)
          .where('type', isEqualTo: 'class')
          .limit(1)
          .get();

      if (chatSnapshot.docs.isNotEmpty) {
        final chatId = chatSnapshot.docs.first.id;
        
        await _firestore.collection('chats').doc(chatId).update({
          'participants': FieldValue.arrayUnion([parentId]),
          'participantNames.$parentId': parentName,
        });

        print('✅ Родитель добавлен в классный чат: $chatId');
      }
    } catch (e) {
      print('❌ Ошибка добавления родителя в чат: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _birthDateController.text = "${picked.day}.${picked.month}.${picked.year}";
    }
  }

  Icon _getRoleIcon(String role) {
    switch (role) {
      case 'student': return const Icon(Icons.school, size: 32, color: Colors.blue);
      case 'teacher': return const Icon(Icons.person, size: 32, color: Colors.green);
      case 'parent': return const Icon(Icons.family_restroom, size: 32, color: Colors.orange);
      case 'director': return const Icon(Icons.admin_panel_settings, size: 32, color: Colors.red);
      default: return const Icon(Icons.person, size: 32);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _classController.dispose();
    _teacherNameController.dispose();
    _childEmailController.dispose();
    _schoolNameController.dispose();
    _schoolAddressController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _adminCodeController.dispose();
    super.dispose();
  }
}