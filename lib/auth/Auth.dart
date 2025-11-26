import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_app/pages/select_role.dart';
import 'package:school_app/main.dart';

class Auth extends StatefulWidget {
  const Auth({super.key});

  @override
  State<Auth> createState() => _AuthState();
}

class _AuthState extends State<Auth> {
  bool isLogin = true;
  bool _isLoading = false;

  final _loginController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _repeatPasswordController = TextEditingController();
  bool _obscureText = true;
  bool _obscureText2 = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _clearControllers() {
    _loginController.clear();
    _passwordController.clear();
    _repeatPasswordController.clear();
    _emailController.clear();
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final login = _loginController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final passwordRepeat = _repeatPasswordController.text.trim();

    if (isLogin) {
      if (login.isEmpty || password.isEmpty) {
        _showError('Заполните все поля');
        setState(() => _isLoading = false);
        return;
      }
    } 

    else {
      if (login.isEmpty || email.isEmpty || password.isEmpty || passwordRepeat.isEmpty) {
        _showError('Заполните все поля');
        setState(() => _isLoading = false);
        return;
      }

      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
      if (!emailRegex.hasMatch(email)) {
        _showError('Введите корректный email');
        setState(() => _isLoading = false);
        return;
      }

      if (password.length < 6) {
        _showError('Пароль должен быть минимум 6 символов');
        setState(() => _isLoading = false);
        return;
      }

      if (password != passwordRepeat) {
        _showError('Пароли не совпадают');
        setState(() => _isLoading = false);
        return;
      }
    }

    try {
      if (isLogin) {
        final userEmail = await _getEmailByLogin(login);
        if (userEmail == null) {
          _showError('Пользователь с таким логином не найден');
          return;
        }

        await _auth.signInWithEmailAndPassword(
          email: userEmail, 
          password: password
        );
        
        _showSuccess('Вход выполнен успешно!');

        await Future.delayed(const Duration(milliseconds: 1500));
         if (mounted) {
          Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthCheck()),
          );
        }
        
      } else {
        final isLoginTaken = await _isLoginTaken(login);
        if (isLoginTaken) {
          _showError('Этот логин уже занят');
          return;
        }

        final isEmailTaken = await _isEmailTaken(email);
        if (isEmailTaken) {
          _showError('Этот email уже используется');
          return;
        }

        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email, 
          password: password
        );
        
        final uid = userCredential.user!.uid;

        await _firestore.collection('users').doc(uid).set({
          'uid': uid,
          'username': login,
          'email': email,
          'role': null,
          'profileComplete': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        _showSuccess('Регистрация успешна!');
        _clearControllers();

        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SelectRolePage(uid: uid),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      _showError(_getAuthErrorMessage(e));
    } catch (e) {
      _showError('Произошла ошибка: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String?> _getEmailByLogin(String login) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: login)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data()['email'];
      }
      return null;
    } catch (e) {
      print('Ошибка при поиске пользователя: $e');
      return null;
    }
  }

  Future<bool> _isLoginTaken(String login) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: login)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Ошибка при проверке логина: $e');
      return true;
    }
  }

  Future<bool> _isEmailTaken(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Ошибка при проверке email: $e');
      return true;
    }
  }

  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Этот email уже используется';
      case 'invalid-email':
        return 'Неверный формат email';
      case 'weak-password':
        return 'Пароль слишком слабый';
      case 'user-not-found':
        return 'Пользователь не найден';
      case 'wrong-password':
        return 'Неверный пароль';
      case 'network-request-failed':
        return 'Проблемы с интернет-соединением';
      default:
        return e.message ?? 'Произошла ошибка при авторизации';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              isLogin = true;
                              _clearControllers(); 
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: isLogin ? Colors.blue : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "Вход",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isLogin ? Colors.white : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              isLogin = false;
                              _clearControllers(); 
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: !isLogin ? Colors.blue : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "Регистрация",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: !isLogin ? Colors.white : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                TextField(
                  controller: _loginController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_outline),
                    labelText: 'Логин',
                    border: OutlineInputBorder(),
                    hintText: 'Введите ваш логин',
                  ),
                ),
                const SizedBox(height: 16),

                if (!isLogin) ...[
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.email_outlined),
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      hintText: 'Введите ваш email',
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                ],

                TextField(
                  controller: _passwordController,
                  obscureText: _obscureText,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline),
                    labelText: 'Пароль',
                    border: const OutlineInputBorder(),
                    hintText: 'Введите ваш пароль',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureText = !_obscureText),
                    ),
                  ),
                ),

                if (!isLogin) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _repeatPasswordController,
                    obscureText: _obscureText2,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_reset),
                      labelText: 'Повторите пароль',
                      border: const OutlineInputBorder(),
                      hintText: 'Повторите ваш пароль',
                      suffixIcon: IconButton(
                        icon: Icon(_obscureText2 ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscureText2 = !_obscureText2),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 30),
                
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    disabledBackgroundColor: Colors.blue.withOpacity(0.5),
                    minimumSize: const Size(double.infinity, 50),
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
                      : Text(
                          isLogin ? 'Войти' : 'Зарегистрироваться',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loginController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _repeatPasswordController.dispose();
    super.dispose();
  }
}