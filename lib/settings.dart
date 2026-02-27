import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'language_service.dart';
import 'user_settings_service.dart';
import 'login.dart';
import 'session_service.dart';

ValueNotifier<String> appLanguage = ValueNotifier("English");

class SettingsPage extends StatefulWidget {
  final bool showUserLogout;
  final bool showAdminSerialSetting;
  final String selectedCategory;

  const SettingsPage({
    super.key,
    this.showUserLogout = false,
    this.showAdminSerialSetting = true,
    this.selectedCategory = 'All',
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String selectedLanguage = "English";
  final TextEditingController _officerNameCtrl = TextEditingController();
  final TextEditingController _serialNoCtrl = TextEditingController();
  final TextEditingController _assignStartCtrl = TextEditingController();
  final TextEditingController _assignEndCtrl = TextEditingController();
  final TextEditingController _assignNextCtrl = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isAssigningSerial = false;
  String? _signatureImagePath;
  String? _signatureImageUrl;
  String _userName = '';
  String _userEmail = '';
  String _userRole = '';
  int? _serialStartNo;
  int? _serialEndNo;
  int? _serialNextAssigned;
  List<Map<String, dynamic>> _assignableUsers = [];
  String? _selectedAssignUserId;
  String? _userAvatarUrl;
  Uint8List? _selectedAvatarBytes;
  String? _selectedAvatarFileName;
  Uint8List? _selectedSignatureBytes;
  String? _selectedSignatureFileName;
  final List<String> languages = [
    "English",
    "Filipino/Tagalog",
  ];

  String _defaultAvatarUrl(String name, String email) {
    final seed = name.trim().isNotEmpty ? name.trim() : email.trim();
    final encoded = Uri.encodeQueryComponent(seed.isEmpty ? 'User' : seed);
    return 'https://ui-avatars.com/api/?name=$encoded&size=160&background=1E3A5F&color=ffffff&bold=true';
  }

  Color _themeColorForCategory(String category) {
    final v = category.toLowerCase().trim();
    if (v == 'business permit fees' || v.contains('business permit')) {
      return const Color(0xFFFF9800);
    }
    if (v == 'inspection fees' || v.contains('inspection')) {
      return const Color(0xFF8E24AA);
    }
    if (v == 'other economic enterprises' || v.contains('other economic')) {
      return const Color(0xFFFFEB3B);
    }
    if (v == 'other service income' || v.contains('other service')) {
      return const Color(0xFF9E9E9E);
    }
    if (v == 'parking and terminal fees' || v.contains('parking and terminal')) {
      return const Color(0xFFEC407A);
    }
    if (v == 'amusement tax/' ||
        v == 'amusement tax' ||
        v.contains('amusement tax')) {
      return const Color(0xFF9ACD32);
    }
    if (v == 'slaughter' || v == 'slaugther' || v.contains('slaugh')) {
      return const Color(0xFFD32F2F);
    }
    if (v == 'rent' || v == 'renta' || v.contains('rent')) {
      return const Color(0xFF2E7D32);
    }
    if (v == 'marine' || v.contains('marine') || v.contains('fish')) {
      return const Color(0xFF2E7D32);
    }
    return const Color(0xFF1E3A5F);
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _officerNameCtrl.dispose();
    _serialNoCtrl.dispose();
    _assignStartCtrl.dispose();
    _assignEndCtrl.dispose();
    _assignNextCtrl.dispose();
    super.dispose();
  }

  bool get _isAdminSettings =>
      widget.showAdminSerialSetting && !widget.showUserLogout;

  Future<void> _loadSettings() async {
    try {
      final saved = await UserSettingsService.fetchSettings();
      final user = Supabase.instance.client.auth.currentUser;
      final userId = user?.id;
      final userEmail = (user?.email ?? '').trim();
      String fullName = '';
      String role = '';
      String? avatarPath;
      if (userId != null) {
        try {
          final profile = await Supabase.instance.client
              .from('user_profiles')
              .select(
                  'full_name, role, signature_image_path, avatar_image_path, serial_start_no, serial_end_no, next_serial_no')
              .eq('id', userId)
              .maybeSingle();
          if (profile != null) {
            fullName = (profile['full_name'] ?? '').toString().trim();
            role = (profile['role'] ?? '').toString().trim();
            avatarPath = (profile['avatar_image_path'] ?? '')
                .toString()
                .trim();
            if (avatarPath.isEmpty) {
              avatarPath = (profile['signature_image_path'] ?? '')
                  .toString()
                  .trim();
            }
            _serialStartNo =
                int.tryParse((profile['serial_start_no'] ?? '').toString());
            _serialEndNo =
                int.tryParse((profile['serial_end_no'] ?? '').toString());
            _serialNextAssigned =
                int.tryParse((profile['next_serial_no'] ?? '').toString());
          }
        } catch (_) {
          // Keep auth fallback values.
        }
      }
      if (!mounted) return;
      final fallbackName = fullName.isNotEmpty
          ? fullName
          : (user?.userMetadata?['full_name'] ?? '').toString().trim();
      final profileName = fallbackName.isNotEmpty ? fallbackName : 'User';
      final avatarUrl = (avatarPath != null && avatarPath.isNotEmpty)
          ? (avatarPath.contains('/avatar_')
              ? Supabase.instance.client.storage
                  .from('profile-pictures')
                  .getPublicUrl(avatarPath)
              : UserSettingsService.publicSignatureUrl(avatarPath))
          : null;
      if (saved != null) {
        final dbLanguage = (saved['language'] ?? 'English').toString();
        selectedLanguage = dbLanguage;
        appLanguage.value = dbLanguage;
        LanguageService.setLanguage(dbLanguage);
        final savedOfficer =
            (saved['collecting_officer_name'] ?? '').toString().trim();
        _officerNameCtrl.text = savedOfficer;
        final nextSerial = (saved['next_serial_no'] ?? 1).toString();
        _serialNoCtrl.text = nextSerial;
        _signatureImagePath = (saved['signature_image_path'] ?? '').toString();
        _signatureImageUrl =
            UserSettingsService.publicSignatureUrl(_signatureImagePath);
      }
      if (_officerNameCtrl.text.trim().isEmpty && fallbackName.isNotEmpty) {
        _officerNameCtrl.text = fallbackName;
      }
      _userName = profileName;
      _userEmail = userEmail;
      _userRole = role.isEmpty ? 'User' : role;
      _userAvatarUrl = avatarUrl ??
          _defaultAvatarUrl(
            profileName,
            userEmail,
          );
      if (_isAdminSettings) {
        await _loadAssignableUsers();
      }
    } catch (_) {
      // Keep defaults if loading fails.
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickSignatureImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _selectedSignatureBytes = file.bytes;
      _selectedSignatureFileName = file.name;
    });
  }

  Future<void> _pickProfileImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _selectedAvatarBytes = file.bytes;
      _selectedAvatarFileName = file.name;
    });
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null &&
          _selectedAvatarBytes != null &&
          _selectedAvatarFileName != null) {
        final fileName = _selectedAvatarFileName!;
        final ext = fileName.contains('.') ? fileName.split('.').last : 'png';
        final avatarPath =
            '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

        await Supabase.instance.client.storage
            .from('profile-pictures')
            .uploadBinary(
              avatarPath,
              _selectedAvatarBytes!,
              fileOptions: const FileOptions(upsert: true),
            );

        await Supabase.instance.client.from('user_profiles').update({
          'avatar_image_path': avatarPath,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);

        _userAvatarUrl = Supabase.instance.client.storage
            .from('profile-pictures')
            .getPublicUrl(avatarPath);
        _selectedAvatarBytes = null;
        _selectedAvatarFileName = null;
      }

      String? uploadedPath = _signatureImagePath;
      if (_selectedSignatureBytes != null &&
          _selectedSignatureFileName != null) {
        uploadedPath = await UserSettingsService.uploadSignature(
          bytes: _selectedSignatureBytes!,
          fileName: _selectedSignatureFileName!,
        );
      }

      await UserSettingsService.saveSettings(
        language: selectedLanguage,
        collectingOfficerName: _officerNameCtrl.text.trim(),
        signatureImagePath: uploadedPath,
        nextSerialNo: int.tryParse(_serialNoCtrl.text.trim()) ?? 1,
      );

      _signatureImagePath = uploadedPath;
      _signatureImageUrl = UserSettingsService.publicSignatureUrl(uploadedPath);
      _selectedSignatureBytes = null;
      _selectedSignatureFileName = null;
      appLanguage.value = selectedLanguage;
      LanguageService.setLanguage(selectedLanguage);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved.')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save settings: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _loadAssignableUsers() async {
    try {
      final data = await Supabase.instance.client
          .from('user_profiles')
          .select(
              'id, email, full_name, serial_start_no, serial_end_no, next_serial_no')
          .order('created_at', ascending: false);
      final rows = List<Map<String, dynamic>>.from(data);
      if (!mounted) return;
      setState(() {
        _assignableUsers = rows;
        if (rows.isNotEmpty) {
          _selectedAssignUserId ??= rows.first['id']?.toString();
          _applySelectedUserSerial();
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _assignableUsers = [];
        _selectedAssignUserId = null;
      });
    }
  }

  void _applySelectedUserSerial() {
    if (_selectedAssignUserId == null) return;
    final user = _assignableUsers.cast<Map<String, dynamic>?>().firstWhere(
          (e) => e?['id']?.toString() == _selectedAssignUserId,
          orElse: () => null,
        );
    if (user == null) {
      _assignStartCtrl.clear();
      _assignEndCtrl.clear();
      _assignNextCtrl.clear();
      return;
    }
    final start = user['serial_start_no']?.toString() ?? '';
    final end = user['serial_end_no']?.toString() ?? '';
    final next = user['next_serial_no']?.toString() ?? '';
    _assignStartCtrl.text = start;
    _assignEndCtrl.text = end;
    _assignNextCtrl.text = next;
  }

  Map<String, dynamic>? _selectedAssignableUser() {
    if (_selectedAssignUserId == null) return null;
    for (final user in _assignableUsers) {
      if ((user['id'] ?? '').toString() == _selectedAssignUserId) {
        return user;
      }
    }
    return null;
  }

  Future<void> _assignSerialRangeToUser() async {
    if (_selectedAssignUserId == null || _isAssigningSerial) return;
    final startNo = int.tryParse(_assignStartCtrl.text.trim());
    final endNo = int.tryParse(_assignEndCtrl.text.trim());
    final nextNo = int.tryParse(_assignNextCtrl.text.trim());

    if (startNo == null || endNo == null || startNo < 1 || endNo < startNo) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid serial range. Start must be >= 1 and End >= Start.'),
        ),
      );
      return;
    }

    if (nextNo != null && (nextNo < startNo || nextNo > endNo)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Next serial must be within assigned range.'),
        ),
      );
      return;
    }

    setState(() => _isAssigningSerial = true);
    try {
      await Supabase.instance.client.rpc(
        'admin_set_user_serial_range',
        params: {
          'p_user_id': _selectedAssignUserId,
          'p_serial_start_no': startNo,
          'p_serial_end_no': endNo,
        },
      );

      if (nextNo != null) {
        await Supabase.instance.client.from('user_profiles').update({
          'next_serial_no': nextNo,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', _selectedAssignUserId!);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Serial number assigned to user.')),
      );
      await _loadAssignableUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to assign serial: $e')),
      );
    } finally {
      if (mounted) setState(() => _isAssigningSerial = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _themeColorForCategory(widget.selectedCategory);
    final appBarTitleColor = Colors.white;
    final titleColor = Colors.black87;
    final bodyTextColor = themeColor.withValues(alpha: 0.82);
    final isAdminSettings = _isAdminSettings;
    final selectedAssignUser = _selectedAssignableUser();
    final selectedStart =
        int.tryParse((selectedAssignUser?['serial_start_no'] ?? '').toString());
    final selectedEnd =
        int.tryParse((selectedAssignUser?['serial_end_no'] ?? '').toString());
    final selectedNext =
        int.tryParse((selectedAssignUser?['next_serial_no'] ?? '').toString());
    final hasAssignedRange = selectedStart != null && selectedEnd != null;
    final assignmentStatus = hasAssignedRange ? 'Assigned' : 'Not Assigned';
    final assignmentColor = hasAssignedRange
        ? const Color(0xFF2E7D32)
        : const Color(0xFFB3261E);
    return Scaffold(
      backgroundColor: themeColor.withValues(alpha: 0.08),
      appBar: AppBar(
        backgroundColor: themeColor,
        elevation: 2,
        title: ValueListenableBuilder<String>(
          valueListenable: LanguageService.currentLanguage,
          builder: (context, language, child) {
            return Text(LanguageService.translate("Settings"),
                style: TextStyle(color: appBarTitleColor));
          },
        ),
        iconTheme: IconThemeData(color: appBarTitleColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTextStyle.merge(
              style: TextStyle(color: bodyTextColor),
              child: IconTheme.merge(
                data: IconThemeData(color: themeColor),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    30,
                    30,
                    30,
                    widget.showUserLogout ? 130 : 30,
                  ),
                  children: [
                    _glassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: themeColor.withValues(alpha: 0.16),
                              backgroundImage: _selectedAvatarBytes != null
                                  ? MemoryImage(_selectedAvatarBytes!)
                                  : (_userAvatarUrl != null
                                      ? NetworkImage(_userAvatarUrl!)
                                      : null),
                              child: (_selectedAvatarBytes == null &&
                                      _userAvatarUrl == null)
                                  ? Text(
                                      (_userName.isNotEmpty
                                              ? _userName[0]
                                              : 'U')
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: themeColor,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _userName,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: titleColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _userEmail.isEmpty ? '-' : _userEmail,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: bodyTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: themeColor.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _userRole.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: themeColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.confirmation_number_outlined,
                                        size: 16,
                                        color: themeColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _serialStartNo != null &&
                                                  _serialEndNo != null
                                              ? 'Assigned Serial No.: ${_serialStartNo!} - ${_serialEndNo!}'
                                              : (_serialNextAssigned != null
                                                  ? 'Assigned Serial No.: ${_serialNextAssigned!}'
                                                  : 'Assigned Serial No.: Not assigned'),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: bodyTextColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Edit picture',
                              onPressed: _pickProfileImage,
                              icon: Icon(
                                Icons.photo_camera_outlined,
                                color: themeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ValueListenableBuilder<String>(
                      valueListenable: LanguageService.currentLanguage,
                      builder: (context, language, child) {
                        return Text(
                          LanguageService.translate("System Preference"),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _glassCard(
                      child: ListTile(
                        leading: Icon(Icons.language, color: themeColor),
                        title: ValueListenableBuilder<String>(
                          valueListenable: LanguageService.currentLanguage,
                          builder: (context, language, child) {
                            return Text(
                              LanguageService.translate("Language Selection"),
                              style: TextStyle(color: titleColor),
                            );
                          },
                        ),
                        trailing: DropdownButton<String>(
                          value: selectedLanguage,
                          underline: const SizedBox(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedLanguage = newValue!;
                            });
                            LanguageService.setLanguage(newValue!);
                          },
                          items: languages.map((String lang) {
                            return DropdownMenuItem(
                                value: lang, child: Text(lang));
                          }).toList(),
                        ),
                      ),
                    ),
                    if (!isAdminSettings && widget.showAdminSerialSetting) ...[
                      const SizedBox(height: 16),
                      _glassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Next Receipt Serial No.',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _serialNoCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'Enter next serial number',
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'This number is used in receipts and increases after user print.',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (!isAdminSettings) ...[
                      const SizedBox(height: 16),
                      _glassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Collecting Officer Name',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _officerNameCtrl,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'Enter collecting officer name',
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Signature Image',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                height: 90,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: _selectedSignatureBytes != null
                                    ? Image.memory(
                                        _selectedSignatureBytes!,
                                        fit: BoxFit.contain,
                                      )
                                    : (_signatureImageUrl != null
                                        ? Image.network(
                                            _signatureImageUrl!,
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error,
                                                    stackTrace) =>
                                                const Text(
                                                    'Signature preview unavailable'),
                                          )
                                        : const Text('No signature uploaded')),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _pickSignatureImage,
                                    icon: const Icon(Icons.upload_file),
                                    label: const Text('Choose Signature'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: themeColor,
                                      side: BorderSide(
                                          color: themeColor.withValues(
                                              alpha: 0.45)),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: _isSaving ? null : _saveSettings,
                                    icon: const Icon(Icons.save),
                                    label: Text(_isSaving
                                        ? 'Saving...'
                                        : 'Save Settings'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: themeColor,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      _glassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.manage_accounts, color: themeColor),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Appoint Serial Number',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black12),
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: _selectedAssignUserId,
                                    hint: const Text('Select user'),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedAssignUserId = value;
                                        _applySelectedUserSerial();
                                      });
                                    },
                                    items: _assignableUsers.map((user) {
                                      final id =
                                          (user['id'] ?? '').toString().trim();
                                      final fullName = (user['full_name'] ?? '')
                                          .toString()
                                          .trim();
                                      final email = (user['email'] ?? '')
                                          .toString()
                                          .trim();
                                      final label = fullName.isNotEmpty
                                          ? '$fullName ($email)'
                                          : email;
                                      return DropdownMenuItem<String>(
                                        value: id,
                                        child: Text(
                                          label.isEmpty ? id : label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (selectedAssignUser != null)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: Colors.black12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Current Assignment',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: assignmentColor.withValues(
                                                  alpha: 0.14),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              assignmentStatus,
                                              style: TextStyle(
                                                color: assignmentColor,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        hasAssignedRange
                                            ? 'Range: $selectedStart - $selectedEnd'
                                            : 'Range: -',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        selectedNext != null
                                            ? 'Next Serial: $selectedNext'
                                            : 'Next Serial: -',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (selectedAssignUser != null)
                                const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _assignStartCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        labelText: 'Start Serial',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _assignEndCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        labelText: 'End Serial',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _assignNextCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: 'Next Serial (optional override)',
                                  hintText:
                                      'Leave empty to reset to start serial',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _isAssigningSerial
                                        ? null
                                        : _assignSerialRangeToUser,
                                    icon: _isAssigningSerial
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Icon(Icons.check_circle_outline),
                                    label: Text(_isAssigningSerial
                                        ? 'Assigning...'
                                        : 'Assign to User'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: themeColor,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _loadAssignableUsers,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Refresh Users'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveSettings,
                          icon: const Icon(Icons.save),
                          label:
                              Text(_isSaving ? 'Saving...' : 'Save Settings'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                    if (widget.showUserLogout) ...[
                      const SizedBox(height: 8),
                      _glassCard(
                        child: ListTile(
                          leading: const Icon(Icons.logout,
                              color: Color(0xFFB3261E)),
                          title: const Text(
                            'Log Out',
                            style: TextStyle(
                              color: Color(0xFFB3261E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () {
                            SessionService.clearSession().then((_) {
                              if (!context.mounted) return;
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (_) => const LoginPage()),
                                (route) => false,
                              );
                            });
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.65),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
              )
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
