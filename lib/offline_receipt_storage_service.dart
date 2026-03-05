import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OfflineReceiptStorageService {
  static const String _fileName = 'pending_print_receipts.json';
  static const String _legacyFileName = 'pending_receipt_print_logs.json';
  static String? _lastSyncError;

  static String? get lastSyncError => _lastSyncError;

  static Future<File> _storageFile() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  static Future<File> _legacyStorageFile() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}${Platform.pathSeparator}$_legacyFileName');
  }

  static Future<void> _migrateLegacyQueueIfNeeded(File targetFile) async {
    if (await targetFile.exists()) return;
    final legacyFile = await _legacyStorageFile();
    if (!await legacyFile.exists()) return;
    try {
      await legacyFile.copy(targetFile.path);
      await legacyFile.delete();
    } catch (_) {
      // Ignore migration errors and continue with best-effort loading.
    }
  }

  static Future<List<Map<String, dynamic>>> loadQueue() async {
    final file = await _storageFile();
    await _migrateLegacyQueueIfNeeded(file);
    if (!await file.exists()) return <Map<String, dynamic>>[];

    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return <Map<String, dynamic>>[];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {
      // Keep app running even if local queue is corrupted.
    }
    return <Map<String, dynamic>>[];
  }

  static Future<void> _saveQueue(List<Map<String, dynamic>> rows) async {
    final file = await _storageFile();
    await file.writeAsString(jsonEncode(rows), flush: true);
  }

  static Future<void> enqueuePrintLog(Map<String, dynamic> row) async {
    final queue = await loadQueue();
    queue.add({
      ...row,
      'queued_at': DateTime.now().toIso8601String(),
    });
    await _saveQueue(queue);
  }

  static Future<int> queueCount() async {
    final queue = await loadQueue();
    return queue.length;
  }

  static Future<int> syncPending() async {
    _lastSyncError = null;
    final queue = await loadQueue();
    if (queue.isEmpty) return 0;

    final List<Map<String, dynamic>> remaining = <Map<String, dynamic>>[];
    int uploaded = 0;
    for (final row in queue) {
      try {
        final payload = _normalizePrintLogPayload(row);
        await _upsertNormalizedPrintReceipt(payload);
        uploaded++;
      } catch (e) {
        _lastSyncError = e.toString();
        remaining.add(row);
      }
    }

    await _saveQueue(remaining);
    return uploaded;
  }

  static Map<String, dynamic> _normalizePrintLogPayload(
    Map<String, dynamic> row,
  ) {
    final map = Map<String, dynamic>.from(row);
    final printedAt = _asString(map['printed_at']) ??
        _asString(map['saved_at']) ??
        _asString(map['queued_at']) ??
        DateTime.now().toIso8601String();
    final total = _asNum(map['total_amount']) ??
        _asNum(map['price']) ??
        _asNum(map['collection_price']) ??
        0.0;

    return <String, dynamic>{
      'printed_at': printedAt,
      'category': _asString(map['category']),
      'marine_flow': _asString(map['marine_flow']),
      'serial_no': _asString(map['serial_no']),
      'receipt_date': _asString(map['receipt_date']) ?? _asString(map['date']),
      'payor': _asString(map['payor']),
      'officer': _asString(map['officer']),
      'total_amount': total,
      'collection_items': _asJsonList(map['collection_items']),
      'nature_code': _asString(map['nature_code']),
      'payment_method': _asString(map['payment_method']),
    };
  }

  static String? _asString(dynamic v) {
    final s = v?.toString().trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  static num? _asNum(dynamic v) {
    if (v is num) return v;
    if (v == null) return null;
    return num.tryParse(v.toString());
  }

  static List<dynamic> _asJsonList(dynamic v) {
    if (v is List) return v;
    if (v is String && v.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(v);
        if (decoded is List) return decoded;
      } catch (_) {
        return <dynamic>[];
      }
    }
    return <dynamic>[];
  }

  static Future<void> _upsertNormalizedPrintReceipt(
    Map<String, dynamic> payload,
  ) async {
    final client = Supabase.instance.client;
    final ownerId = client.auth.currentUser?.id;
    if (ownerId == null || ownerId.isEmpty) {
      throw Exception('No authenticated user. Cannot set owner_id.');
    }
    final printedAt = DateTime.tryParse(
          _asString(payload['printed_at']) ?? '',
        ) ??
        DateTime.now();
    final receiptNo = _asString(payload['serial_no']) ??
        '${printedAt.microsecondsSinceEpoch}';
    final payor = _asString(payload['payor']) ?? '-';
    final payment =
        _normalizedPaymentMethod(_asString(payload['payment_method']));
    final receiptDate =
        _receiptDateFromPayload(_asString(payload['receipt_date']), printedAt);
    final total = (_asNum(payload['total_amount']) ?? 0).toDouble();

    final upserted = await client.from('print_receipts').upsert(
      {
        'owner_id': ownerId,
        'receipt_no': receiptNo,
        'payor': payor,
        'payment_method': payment,
        'receipt_date': receiptDate.toIso8601String(),
        'printed_at': printedAt.toIso8601String(),
        'total_amount': total,
      },
      onConflict: 'receipt_no',
    ).select('id');

    String? receiptId;
    if (upserted.isNotEmpty) {
      receiptId = (upserted.first as Map)['id']?.toString();
    }
    if (receiptId == null || receiptId.isEmpty) {
      final existing = await client
          .from('print_receipts')
          .select('id')
          .eq('receipt_no', receiptNo)
          .maybeSingle();
      receiptId = existing?['id']?.toString();
    }
    if (receiptId == null || receiptId.isEmpty) return;

    final itemRows = _buildPrintItemRows(
      payload: payload,
      receiptId: receiptId,
    );
    await client
        .from('print_receipt_items')
        .delete()
        .eq('receipt_id', receiptId);
    if (itemRows.isNotEmpty) {
      await client.from('print_receipt_items').insert(itemRows);
    }
  }

  static List<Map<String, dynamic>> _buildPrintItemRows({
    required Map<String, dynamic> payload,
    required String receiptId,
  }) {
    final collectionItems = _asJsonList(payload['collection_items']);
    final defaultCategory = (_asString(payload['category']) ?? 'All').trim();
    final rows = <Map<String, dynamic>>[];
    int lineNo = 1;
    for (final raw in collectionItems) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final amount =
          (_asNum(item['price']) ?? _asNum(item['amount']) ?? 0).toDouble();
      if (amount <= 0) continue;

      final rawNature = (item['nature'] ?? '').toString();
      final split = _splitNatureAndSubNature(rawNature);
      final nature = (split['nature'] ?? '').trim();
      if (nature.isEmpty) continue;

      final category =
          (item['category'] ?? defaultCategory).toString().trim().isEmpty
              ? defaultCategory
              : (item['category'] ?? defaultCategory).toString().trim();
      final acctNo = ((item['account_code'] ?? '').toString().trim().isNotEmpty)
          ? (item['account_code'] ?? '').toString().trim()
          : (item['nature_code'] ?? '').toString().trim();
      final rawNatureId = item['nature_id'] ?? item['NatureID'];
      final natureId = rawNatureId is num
          ? rawNatureId.toInt()
          : int.tryParse(rawNatureId?.toString() ?? '');
      final rawSubNatureId = item['sub_nature_id'] ?? item['SubNatureID'];
      final subNatureId = rawSubNatureId is num
          ? rawSubNatureId.toInt()
          : int.tryParse(rawSubNatureId?.toString() ?? '');

      rows.add({
        'receipt_id': receiptId,
        'line_no': lineNo,
        'Category': category,
        'NatureID': natureId,
        'nature': nature,
        'SubNatureID': subNatureId,
        'SubNature': split['sub_nature'],
        'AcctNo': acctNo.isEmpty ? '-' : acctNo,
        'qty': 1,
        'amount': amount,
      });
      lineNo++;
    }
    return rows;
  }

  static Map<String, String?> _splitNatureAndSubNature(String rawNature) {
    final value = rawNature.trim();
    if (value.isEmpty) return {'nature': null, 'sub_nature': null};
    final sep = value.indexOf(' - ');
    if (sep <= 0 || sep >= value.length - 3) {
      return {'nature': value, 'sub_nature': null};
    }
    final nature = value.substring(0, sep).trim();
    final subNature = value.substring(sep + 3).trim();
    return {
      'nature': nature.isEmpty ? null : nature,
      'sub_nature': subNature.isEmpty ? null : subNature,
    };
  }

  static DateTime _receiptDateFromPayload(
    String? receiptDateText,
    DateTime fallback,
  ) {
    final text = (receiptDateText ?? '').trim();
    if (text.isEmpty) return fallback;
    final iso = DateTime.tryParse(text);
    if (iso != null) return iso;
    final parts = text.split('/');
    if (parts.length == 3) {
      final mm = int.tryParse(parts[0]);
      final dd = int.tryParse(parts[1]);
      final yy = int.tryParse(parts[2]);
      if (mm != null && dd != null && yy != null) {
        final year = yy < 100 ? 2000 + yy : yy;
        return DateTime(year, mm, dd);
      }
    }
    return fallback;
  }

  static String _normalizedPaymentMethod(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v == 'cash' || v == 'check' || v == 'money') return v;
    return 'cash';
  }
}
