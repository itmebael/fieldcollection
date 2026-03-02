import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  static const String _supabaseUrl = 'https://yywhqnuwynaozgitrdvw.supabase.co';
  static const String _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl5d2hxbnV3eW5hb3pnaXRyZHZ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3MDA3NzIsImV4cCI6MjA4NzI3Njc3Mn0.sCyQx6Sze7cSh6sn8kc1-tnlLIRzwfU11xnyHQIMeHY';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();

  String _selectedRole = 'staff';
  bool _emailConfirm = true;
  bool _isCreating = false;
  bool _isLoadingUsers = false;
  String? _uploadingAvatarUserId;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() => _isLoadingUsers = true);

    try {
      final data = await Supabase.instance.client
          .from('user_profiles')
          .select(
              'id, email, full_name, role, is_active, created_at, serial_start_no, serial_end_no, next_serial_no, signature_image_path, avatar_image_path')
          .order('created_at', ascending: false)
          .limit(20);

      if (!mounted) return;
      setState(() {
        _users = List<Map<String, dynamic>>.from(data);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _users = [];
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;

    setState(() => _isCreating = true);

    try {
      final adminClient = Supabase.instance.client;
      final adminUser = adminClient.auth.currentUser;
      if (adminUser == null) {
        throw Exception('You must be logged in as admin.');
      }

      final signupClient = SupabaseClient(
        _supabaseUrl,
        _supabaseAnonKey,
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.implicit,
        ),
      );
      final signUpResponse = await signupClient.auth.signUp(
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text.trim(),
        data: {
          'full_name': _fullNameController.text.trim(),
        },
      );

      final createdUser = signUpResponse.user;
      if (createdUser == null) {
        throw Exception('Failed to create auth user.');
      }

      await adminClient.from('user_profiles').update({
        'full_name': _fullNameController.text.trim(),
        'role': _selectedRole,
        'is_active': true,
        'created_by': adminUser.id,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', createdUser.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _emailConfirm
                ? 'User account created. Email confirmation depends on Supabase Auth settings.'
                : 'User account created.',
          ),
        ),
      );

      _emailController.clear();
      _passwordController.clear();
      _fullNameController.clear();
      await _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create user failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _showAssignSerialRangeDialog(Map<String, dynamic> user) async {
    final startCtrl = TextEditingController();
    final endCtrl = TextEditingController();

    final existingStart = user['serial_start_no'];
    final existingEnd = user['serial_end_no'];

    if (existingStart != null) startCtrl.text = existingStart.toString();
    if (existingEnd != null) endCtrl.text = existingEnd.toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Assign Serial Range'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (user['email'] ?? '').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: startCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Start Serial',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. 1',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: endCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'End Serial',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. 20',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Saving will reset the user next serial to start serial.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      startCtrl.dispose();
      endCtrl.dispose();
      return;
    }

    final startNo = int.tryParse(startCtrl.text.trim());
    final endNo = int.tryParse(endCtrl.text.trim());

    startCtrl.dispose();
    endCtrl.dispose();

    if (startNo == null || endNo == null || startNo < 1 || endNo < startNo) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid range. Start must be >= 1 and End >= Start.'),
        ),
      );
      return;
    }

    try {
      await Supabase.instance.client.rpc(
        'admin_set_user_serial_range',
        params: {
          'p_user_id': user['id'],
          'p_serial_start_no': startNo,
          'p_serial_end_no': endNo,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Serial range assigned.')),
      );
      await _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Assign range failed: $e')),
      );
    }
  }

  Future<void> _uploadStaffProfilePicture(Map<String, dynamic> user) async {
    final userId = (user['id'] ?? '').toString().trim();
    if (userId.isEmpty) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    if (!mounted) return;
    setState(() => _uploadingAvatarUserId = userId);

    try {
      final fileName = file.name;
      final ext = fileName.contains('.') ? fileName.split('.').last : 'png';
      final avatarPath =
          '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await Supabase.instance.client.storage.from('profile-pictures').uploadBinary(
            avatarPath,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      await Supabase.instance.client.from('user_profiles').update({
        'avatar_image_path': avatarPath,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated.')),
      );
      await _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingAvatarUserId = null);
      }
    }
  }

  Widget _buildRecentAccountCard(Map<String, dynamic> user) {
    final email = (user['email'] ?? '').toString().trim();
    final fullName = (user['full_name'] ?? '').toString().trim();
    final role = (user['role'] ?? 'staff').toString().trim();
    final active = (user['is_active'] ?? true) as bool;
    final serialStart = user['serial_start_no'];
    final serialEnd = user['serial_end_no'];
    final nextSerial = user['next_serial_no'];
    final hasRange = serialStart != null && serialEnd != null;
    final isStaff = role.toLowerCase() == 'staff';
    final userId = (user['id'] ?? '').toString();
    final isUploadingAvatar = _uploadingAvatarUserId == userId;

    String rangeText = 'No serial range assigned';
    if (hasRange) {
      rangeText = 'Range: $serialStart-$serialEnd | Next: ${nextSerial ?? '-'}';
    }
    final staffImageUrl = _staffImageUrl(user);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showAssignSerialRangeDialog(user),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDDE4EE)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                staffImageUrl,
                width: 46,
                height: 46,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 46,
                    height: 46,
                    color: const Color(0xFF14345C),
                    alignment: Alignment.center,
                    child: Text(
                      _initials(fullName.isEmpty ? email : fullName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName.isEmpty ? email : fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rangeText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Chip(
                  label: Text(active ? role.toUpperCase() : 'INACTIVE'),
                  backgroundColor:
                      active ? Colors.green.shade100 : Colors.red.shade100,
                ),
                IconButton(
                  tooltip: 'Assign serial range',
                  onPressed: () => _showAssignSerialRangeDialog(user),
                  icon: const Icon(Icons.pin),
                ),
                if (isStaff)
                  IconButton(
                    tooltip: 'Upload profile picture',
                    onPressed: isUploadingAvatar
                        ? null
                        : () => _uploadStaffProfilePicture(user),
                    icon: isUploadingAvatar
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_camera_outlined),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _staffImageUrl(Map<String, dynamic> user) {
    final avatarPath = (user['avatar_image_path'] ?? '').toString().trim();
    if (avatarPath.isNotEmpty) {
      return Supabase.instance.client.storage
          .from('profile-pictures')
          .getPublicUrl(avatarPath);
    }

    final signaturePath =
        (user['signature_image_path'] ?? '').toString().trim();
    if (signaturePath.isNotEmpty) {
      return Supabase.instance.client.storage
          .from('officer-signatures')
          .getPublicUrl(signaturePath);
    }

    final fullName = (user['full_name'] ?? '').toString().trim();
    final email = (user['email'] ?? '').toString().trim();
    final seed = fullName.isEmpty ? email : fullName;
    final encoded = Uri.encodeComponent(seed.isEmpty ? 'Staff User' : seed);
    return 'https://ui-avatars.com/api/?name=$encoded&size=128&background=14345C&color=ffffff&bold=true';
  }

  String _initials(String text) {
    final parts = text
        .split(' ')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Accounts'),
        backgroundColor: const Color(0xFF14345C),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 280,
                        child: TextFormField(
                          controller: _fullNameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter full name';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(
                        width: 280,
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return 'Enter email';
                            if (!text.contains('@')) return 'Enter valid email';
                            return null;
                          },
                        ),
                      ),
                      SizedBox(
                        width: 280,
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Temporary Password',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().length < 8) {
                              return 'Minimum 8 characters';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Role',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'staff',
                              child: Text('Staff'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Admin'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedRole = value);
                          },
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Email Confirmed'),
                          value: _emailConfirm,
                          onChanged: (value) {
                            setState(() => _emailConfirm = value);
                          },
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: ElevatedButton.icon(
                          onPressed: _isCreating ? null : _createUser,
                          icon: _isCreating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.person_add),
                          label:
                              Text(_isCreating ? 'Creating...' : 'Create User'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text(
                  'Recent Accounts',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _isLoadingUsers ? null : _loadUsers,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                elevation: 2,
                child: _isLoadingUsers
                    ? const Center(child: CircularProgressIndicator())
                    : _users.isEmpty
                        ? const Center(
                            child: Text('No users found or no access.'))
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              int crossAxisCount = 1;
                              if (width >= 1200) {
                                crossAxisCount = 3;
                              } else if (width >= 760) {
                                crossAxisCount = 2;
                              }

                              return GridView.builder(
                                padding: const EdgeInsets.all(12),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  childAspectRatio: 2.9,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                ),
                                itemCount: _users.length,
                                itemBuilder: (context, index) {
                                  return _buildRecentAccountCard(_users[index]);
                                },
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
