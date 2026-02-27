import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OfflineReceiptStorageService {
  static const String _fileName = 'pending_receipt_print_logs.json';
  static String? _lastSyncError;

  static String? get lastSyncError => _lastSyncError;

  static Future<File> _storageFile() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  static Future<List<Map<String, dynamic>>> loadQueue() async {
    final file = await _storageFile();
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
        await Supabase.instance.client
            .from('receipt_print_logs')
            .insert(payload);
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
}
