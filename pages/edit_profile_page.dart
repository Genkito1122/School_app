import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String role;

  const EditProfilePage({super.key, required this.userData, required this.role});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  String? _currentPhotoUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Используем fullName и phone из твоей базы
    _nameController = TextEditingController(text: widget.userData['fullName'] ?? '');
    _phoneController = TextEditingController(text: widget.userData['phone'] ?? '');
    _currentPhotoUrl = widget.userData['photoUrl'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
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

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 40, // Сжимаем для быстрой загрузки
    );

    if (image == null) return;

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('avatars')
          .child('$uid.jpg');

      // Загружаем файл
      UploadTask uploadTask = storageRef.putFile(File(image.path));
      
      // Ждем завершения загрузки, чтобы избежать ошибки object-not-found
      TaskSnapshot snapshot = await uploadTask;
      
      // Получаем ссылку только после того, как файл реально появился в хранилище
      final downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _currentPhotoUrl = downloadUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Фото загружено')),
      );
    } catch (e) {
      print("Ошибка Storage: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при загрузке: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    try {
      if (uid != null) {
        // Обновляем данные в соответствующей ролевой коллекции
        await FirebaseFirestore.instance
            .collection(_getCollectionName(widget.role))
            .doc(uid)
            .update({
          'fullName': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'photoUrl': _currentPhotoUrl,
        });

        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать профиль'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _pickAndUploadImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 65,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: _currentPhotoUrl != null
                                  ? NetworkImage(_currentPhotoUrl!)
                                  : null,
                              child: _currentPhotoUrl == null
                                  ? const Icon(Icons.person, size: 65, color: Colors.grey)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add_a_photo, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'ФИО',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val!.isEmpty ? 'Введите ФИО' : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Телефон',
                        prefixIcon: Icon(Icons.phone_android),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Сохранить изменения', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}