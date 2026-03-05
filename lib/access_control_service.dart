import 'package:supabase_flutter/supabase_flutter.dart';

class AccessControlPolicy {
  const AccessControlPolicy({
    required this.allowAllCategories,
    required this.allowAllNatures,
    required this.allowManagePayor,
    required this.allowedCategoryKeys,
    required this.allowedNatureIds,
  });

  final bool allowAllCategories;
  final bool allowAllNatures;
  final bool allowManagePayor;
  final Set<String> allowedCategoryKeys;
  final Set<int> allowedNatureIds;

  factory AccessControlPolicy.fullAccess() {
    return const AccessControlPolicy(
      allowAllCategories: true,
      allowAllNatures: true,
      allowManagePayor: true,
      allowedCategoryKeys: <String>{},
      allowedNatureIds: <int>{},
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'allow_all_categories': allowAllCategories,
      'allow_all_natures': allowAllNatures,
      'allow_manage_payor': allowManagePayor,
      'allowed_category_keys': allowedCategoryKeys.toList()..sort(),
      'allowed_nature_ids': allowedNatureIds.toList()..sort(),
    };
  }

  factory AccessControlPolicy.fromJson(Map<String, dynamic> json) {
    final rawCategories = (json['allowed_category_keys'] as List?) ?? const [];
    final rawNatureIds = (json['allowed_nature_ids'] as List?) ?? const [];
    return AccessControlPolicy(
      allowAllCategories: json['allow_all_categories'] != false,
      allowAllNatures: json['allow_all_natures'] != false,
      allowManagePayor: json['allow_manage_payor'] != false,
      allowedCategoryKeys: rawCategories
          .map((e) =>
              AccessControlService.normalizeCategoryKey((e ?? '').toString()))
          .cast<String>()
          .where((e) => e.isNotEmpty)
          .toSet(),
      allowedNatureIds: rawNatureIds
          .map((e) => int.tryParse((e ?? '').toString()))
          .whereType<int>()
          .toSet(),
    );
  }
}

class AccessControlService {
  static const String _table = 'user_access_policies';

  static String normalizeCategoryKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Future<AccessControlPolicy> getPolicyForUser(String userId) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) return AccessControlPolicy.fullAccess();
    try {
      final client = Supabase.instance.client;
      final row = await client
          .from(_table)
          .select(
              'allow_all_categories, allow_all_natures, allow_manage_payor, allowed_category_keys, allowed_nature_ids')
          .eq('user_id', trimmedUserId)
          .maybeSingle();
      if (row == null) return AccessControlPolicy.fullAccess();
      return AccessControlPolicy.fromJson(Map<String, dynamic>.from(row));
    } catch (_) {
      return AccessControlPolicy.fullAccess();
    }
  }

  static Future<AccessControlPolicy> getCurrentUserPolicy() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    return getPolicyForUser(userId);
  }

  static Future<void> savePolicyForUser(
    String userId,
    AccessControlPolicy policy,
  ) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) return;
    final client = Supabase.instance.client;
    final payload = <String, dynamic>{
      'user_id': trimmedUserId,
      ...policy.toJson(),
      'updated_by': client.auth.currentUser?.id,
    };
    await client.from(_table).upsert(payload, onConflict: 'user_id');
  }

  static bool isCategoryAllowed(
    AccessControlPolicy policy,
    String category,
  ) {
    if (policy.allowAllCategories) return true;
    final key = normalizeCategoryKey(category);
    if (key.isEmpty) return false;
    return policy.allowedCategoryKeys.contains(key);
  }

  static bool isNatureAllowed(
    AccessControlPolicy policy, {
    required int? natureId,
    required String category,
  }) {
    if (!isCategoryAllowed(policy, category)) return false;
    if (policy.allowAllNatures) return true;
    if (natureId == null) return false;
    return policy.allowedNatureIds.contains(natureId);
  }
}
