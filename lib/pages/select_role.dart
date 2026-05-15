import 'package:flutter/material.dart';
import 'package:school_app/services/code_service.dart';
import 'package:school_app/pages/profile_setup.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
      'value': 'vice_principal', // ДОБАВЛЯЕМ ЗАВУЧА
      'label': 'Завуч',
      'icon': Icons.supervisor_account,
      'needsCode': true,
      'codeType': 'vice_principal',
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
  Map<String, dynamic>? _vicePrincipalSchoolInfo; // ДЛЯ ЗАВУЧА
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

      setState(() => _isLoading = true);

      try {
        if (role['codeType'] == 'student') {
          final classInfo = await _codeService.verifyClassCode(code); 
          if (classInfo == null) {
           _showError('Неверный код класса');
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
          
        } else if (role['codeType'] == 'vice_principal') {
          // Проверка кода завуча
          final schoolInfo = await _codeService.verifyVicePrincipalCode(code);
          if (schoolInfo == null) {
            _showError('Неверный код завуча');
            return;
          }
          _vicePrincipalSchoolInfo = schoolInfo;
          
        } else if (role['codeType'] == 'admin') {
          final isValid = await _codeService.verifyAdminCode(code);
          
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
        setState(() => _isLoading = false);
      }
    } else {
      // Роли без кода - сразу переходим
      _proceedToProfile();
    }
  }

  void _proceedToProfile() {
    // Передаем соответствующую информацию в зависимости от роли
    Map<String, dynamic>? schoolInfo;
    if (selectedRole == 'teacher') {
      schoolInfo = _teacherSchoolInfo;
    } else if (selectedRole == 'vice_principal') {
      schoolInfo = _vicePrincipalSchoolInfo;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileSetupPage(
          uid: widget.uid,
          role: selectedRole!,
          teacherSchoolInfo: schoolInfo,
          studentClassInfo: _studentClassInfo,
          adminCode: _adminCode,
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // НОВЫЙ МЕТОД: Выход из аккаунта
  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выйти?'),
        content: const Text('Вы действительно хотите выйти? Весь прогресс будет потерян.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _auth.signOut();
              // Возвращаемся к авторизации
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
            child: const Text('Выйти', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выберите роль'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // НОВАЯ КНОПКА ВЫХОДА В AppBar
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Выйти',
          ),
        ],
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
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(role['icon'], color: Colors.blue),
                          title: Text(role['label']),
                          trailing: isSelected 
                              ? const Icon(Icons.check_circle, color: Colors.blue)
                              : null,
                          onTap: () => setState(() => selectedRole = role['value']),
                        ),
                        
                        // Поле для кода (если нужно)
                        if (isSelected && role['needsCode'] == true)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: TextField(
                              controller: _codeControllers[role['value']],
                              decoration: InputDecoration(
                                labelText: _getCodeLabel(role['codeType']),
                                hintText: _getCodeHint(role['codeType']),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Кнопка продолжить
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyAndProceed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Продолжить',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
            
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _logout,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Выйти',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Вспомогательные методы для текста кодов
  String _getCodeLabel(String codeType) {
    switch (codeType) {
      case 'student': return 'Код класса';
      case 'teacher': return 'Код учителя';
      case 'vice_principal': return 'Код завуча';
      case 'admin': return 'Код администратора';
      default: return 'Код';
    }
  }

  String _getCodeHint(String codeType) {
    switch (codeType) {
      case 'student': return 'Получите у классного руководителя';
      case 'teacher': return 'Получите у директора';
      case 'vice_principal': return 'Получите у директора';
      case 'admin': return 'Получите у администратора системы';
      default: return 'Введите код';
    }
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