import 'package:flutter/material.dart';
import 'package:school_app/services/code_service.dart';
import 'package:school_app/pages/profile_setup.dart';

class SelectRolePage extends StatefulWidget {
  final String uid;
  const SelectRolePage({super.key, required this.uid});

  @override
  State<SelectRolePage> createState() => _SelectRolePageState();
}

class _SelectRolePageState extends State<SelectRolePage> {
  String? selectedRole;
  bool _isLoading = false;
  final CodeService _codeService = CodeService();

  final List<Map<String, dynamic>> roles = [
    {
      'value': 'student',
      'label': 'Ученик',
      'icon': Icons.school,
      'needsCode': true,
      'codeType': 'student',
    },
    {
      'value': 'teacher', 
      'label': 'Учитель',
      'icon': Icons.person,
      'needsCode': true,
      'codeType': 'teacher',
    },
    {
      'value': 'parent',
      'label': 'Родитель', 
      'icon': Icons.family_restroom,
      'needsCode': false,
    },
    {
      'value': 'director',
      'label': 'Директор',
      'icon': Icons.admin_panel_settings,
      'needsCode': true,
      'codeType': 'admin',
    },
  ];

  // Для ролей с кодом
  final Map<String, TextEditingController> _codeControllers = {};
  Map<String, dynamic>? _teacherSchoolInfo;
  Map<String, dynamic>? _studentClassInfo;
  String? _adminCode;

  @override
  void initState() {
    super.initState();
    // Инициализируем контроллеры для кодов
    for (var role in roles) {
      if (role['needsCode'] == true) {
        _codeControllers[role['value']] = TextEditingController();
      }
    }
  }

  Future<void> _verifyAndProceed() async {
    if (selectedRole == null) {
      _showError('Выберите роль');
      return;
    }

    final role = roles.firstWhere((r) => r['value'] == selectedRole);
    
    if (role['needsCode'] == true) {
      final code = _codeControllers[selectedRole!]!.text.trim();
      
      if (code.isEmpty) {
        _showError('Введите код');
        return;
      }

      if (mounted) setState(() => _isLoading = true);

      try {
        if (role['codeType'] == 'student') {
          // Проверка кода ученика
          final classInfo = await _codeService.verifyStudentCode(code);
          if (classInfo == null) {
            _showError('Неверный код ученика');
            return;
          }
          _studentClassInfo = classInfo;
          
        } else if (role['codeType'] == 'teacher') {
          // Проверка кода учителя
          final schoolInfo = await _codeService.verifyTeacherCode(code);
          if (schoolInfo == null) {
            _showError('Неверный код учителя');
            return;
          }
          _teacherSchoolInfo = schoolInfo;
          
        } else if (role['codeType'] == 'admin') {
          final isValid = await _codeService.verifyAdminCode(code);
          print('✅ Результат проверки admin кода: $isValid');
          
          if (!isValid) {
            _showError('Неверный код администратора');
            return;
          }
          _adminCode = code;
        }
        
        // Если код верный - переходим к заполнению профиля
        _proceedToProfile();
        
      } catch (e) {
        _showError('Ошибка проверки кода: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      // Роли без кода - сразу переходим
      _proceedToProfile();
    }
  }

  void _proceedToProfile() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileSetupPage(
          uid: widget.uid,
          role: selectedRole!,
          teacherSchoolInfo: _teacherSchoolInfo,
          studentClassInfo: _studentClassInfo,
          adminCode: _adminCode,
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выберите роль'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Кто вы?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Выберите вашу роль в образовательном процессе',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            
            Expanded(
              child: ListView.builder(
                itemCount: roles.length,
                itemBuilder: (context, index) {
                  final role = roles[index];
                  final isSelected = selectedRole == role['value'];
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.white,
                    child: InkWell(
                      onTap: () {
                        if (mounted) {
                          setState(() {
                            selectedRole = role['value'];
                          });
                        }
                      },
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(role['icon'], color: Colors.blue),
                            title: Text(role['label']),
                            trailing: isSelected 
                                ? const Icon(Icons.check_circle, color: Colors.blue)
                                : null,
                          ),
                          
                          // Поле для кода (если нужно)
                          if (isSelected && role['needsCode'] == true)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: TextField(
                                controller: _codeControllers[role['value']],
                                decoration: InputDecoration(
                                  labelText: role['codeType'] == 'student' 
                                      ? 'Код ученика'
                                      : role['codeType'] == 'teacher'
                                          ? 'Код учителя' 
                                          : 'Код администратора',
                                  hintText: role['codeType'] == 'student'
                                      ? 'Получите у учителя'
                                      : role['codeType'] == 'teacher'
                                          ? 'Получите у директора'
                                          : 'Получите у администратора',
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                enabled: !_isLoading,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyAndProceed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Продолжить',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Очищаем контроллеры
    for (var controller in _codeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}