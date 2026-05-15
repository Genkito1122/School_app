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
  final _childEmailController = TextEditingController();
  
  String? _currentPhotoUrl;
  bool _isLoading = false;
  
  // Для родителя — список уже привязанных детей
  List<Map<String, dynamic>> _children = [];
  bool _isLoadingChildren = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userData['fullName'] ?? '');
    _phoneController = TextEditingController(text: widget.userData['phone'] ?? '');
    _currentPhotoUrl = widget.userData['photoUrl'];
    
    if (widget.role == 'parent') {
      _loadChildren();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _childEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadChildren() async {
    setState(() => _isLoadingChildren = true);
    
    try {
      final childIds = List<String>.from(widget.userData['childIds'] ?? []);
      List<Map<String, dynamic>> children = [];
      
      for (final childId in childIds) {
        final childDoc = await FirebaseFirestore.instance
            .collection('students')
            .doc(childId)
            .get();
        if (childDoc.exists) {
          children.add({
            'uid': childId,
            'fullName': childDoc.data()?['fullName'] ?? 'Неизвестно',
            'className': childDoc.data()?['className'] ?? '',
            'email': childDoc.data()?['email'] ?? '',
          });
        }
      }
      
      setState(() => _children = children);
    } catch (e) {
      print('❌ Ошибка загрузки детей: $e');
    } finally {
      setState(() => _isLoadingChildren = false);
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

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 40,
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

      UploadTask uploadTask = storageRef.putFile(File(image.path));
      TaskSnapshot snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() => _currentPhotoUrl = downloadUrl);

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


  Future<void> _addChild() async {
    final email = _childEmailController.text.trim();
    
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите email ребёнка')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {

      final studentSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (studentSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ученик с таким email не найден')),
        );
        setState(() => _isLoading = false);
        return;
      }

      final studentDoc = studentSnapshot.docs.first;
      final studentId = studentDoc.id;
      final studentData = studentDoc.data();


      if (_children.any((c) => c['uid'] == studentId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Этот ребёнок уже привязан')),
        );
        setState(() => _isLoading = false);
        return;
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;


      await FirebaseFirestore.instance
          .collection('parents')
          .doc(uid)
          .update({
        'childIds': FieldValue.arrayUnion([studentId]),
      });


      await FirebaseFirestore.instance
          .collection('students')
          .doc(studentId)
          .update({
        'parentIds': FieldValue.arrayUnion([uid]),
      });


      _children.add({
        'uid': studentId,
        'fullName': studentData['fullName'] ?? 'Неизвестно',
        'className': studentData['className'] ?? '',
        'email': studentData['email'] ?? '',
      });

      _childEmailController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ребёнок ${studentData['fullName']} привязан!')),
      );
      
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _removeChild(String childId, String childName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отвязать ребёнка?'),
        content: Text('Вы уверены, что хотите отвязать $childName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Отвязать', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;


      await FirebaseFirestore.instance
          .collection('parents')
          .doc(uid)
          .update({
        'childIds': FieldValue.arrayRemove([childId]),
      });


      await FirebaseFirestore.instance
          .collection('students')
          .doc(childId)
          .update({
        'parentIds': FieldValue.arrayRemove([uid]),
      });

      // Удаляем из локального списка
      _children.removeWhere((c) => c['uid'] == childId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$childName отвязан(а)')),
      );
      
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
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
        await FirebaseFirestore.instance
            .collection(_getCollectionName(widget.role))
            .doc(uid)
            .update({
          'fullName': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'photoUrl': _currentPhotoUrl,
        });

        if (mounted) Navigator.pop(context);
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
                    

                    if (widget.role == 'parent') ...[
                      const SizedBox(height: 30),
                      const Divider(),
                      const SizedBox(height: 10),
                      
                      const Text(
                        'Мои дети',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      

                      if (_isLoadingChildren)
                        const Center(child: CircularProgressIndicator())
                      else if (_children.isEmpty)
                        const Text('Нет привязанных детей', style: TextStyle(color: Colors.grey))
                      else
                        ..._children.map((child) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.child_care, color: Colors.blue),
                            title: Text(child['fullName']),
                            subtitle: Text(child['className'] ?? ''),
                            trailing: IconButton(
                              icon: const Icon(Icons.link_off, color: Colors.red),
                              onPressed: () => _removeChild(child['uid'], child['fullName']),
                              tooltip: 'Отвязать',
                            ),
                          ),
                        )),
                      
                      const SizedBox(height: 16),
                      

                      const Text(
                        'Привязать ещё одного ребёнка',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _childEmailController,
                              decoration: const InputDecoration(
                                hintText: 'Email ребёнка',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.email),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _addChild,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            child: const Text('Привязать'),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      const Text(
                        'Введите email ученика, чтобы привязать его к вашему аккаунту',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                    
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