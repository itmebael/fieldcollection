import 'package:flutter/material.dart';
import 'dart:ui';

import 'offline_receipt_storage_service.dart';

class OfflineStoragePage extends StatefulWidget {
  final String selectedCategory;

  const OfflineStoragePage({
    super.key,
    this.selectedCategory = 'Marine',
  });

  @override
  State<OfflineStoragePage> createState() => _OfflineStoragePageState();
}

class _OfflineStoragePageState extends State<OfflineStoragePage> {
  bool _loading = false;
  List<Map<String, dynamic>> _rows = [];

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
    _refresh();
    _syncSilently();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final data = await OfflineReceiptStorageService.loadQueue();
    if (!mounted) return;
    setState(() {
      _rows = data.reversed.toList();
      _loading = false;
    });
  }

  Future<void> _syncSilently() async {
    try {
      final uploaded = await OfflineReceiptStorageService.syncPending();
      if (!mounted) return;
      if (uploaded > 0) {
        await _refresh();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uploaded $uploaded queued receipt(s).')),
        );
      }
    } catch (_) {
      // Ignore silent sync errors.
    }
  }

  Future<void> _syncNow() async {
    setState(() => _loading = true);
    final uploaded = await OfflineReceiptStorageService.syncPending();
    final syncError = OfflineReceiptStorageService.lastSyncError;
    if (!mounted) return;
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          uploaded > 0
              ? 'Uploaded $uploaded queued receipt(s).'
              : (syncError == null || syncError.isEmpty)
                  ? 'No queued receipts uploaded. Check internet/database.'
                  : 'Upload failed: $syncError',
        ),
      ),
    );
  }

  String _fmt(dynamic value) {
    if (value == null) return '-';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return value.toString();
    return '${dt.month}/${dt.day}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  double _amount(Map<String, dynamic> row) =>
      (row['total_amount'] as num?)?.toDouble() ?? 0.0;

  @override
  Widget build(BuildContext context) {
    final themeColor = _themeColorForCategory(widget.selectedCategory);
    final textColor = themeColor.withValues(alpha: 0.95);
    final mutedTextColor = themeColor.withValues(alpha: 0.75);
    final total = _rows.fold<double>(0.0, (sum, r) => sum + _amount(r));
    return Scaffold(
      backgroundColor: themeColor.withValues(alpha: 0.08),
      appBar: AppBar(
        title: const Text('Offline Storage'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _loading ? null : _syncNow,
            icon: const Icon(Icons.cloud_upload),
            tooltip: 'Sync',
          ),
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 40) / 2,
                  child: _glassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Queued: ${_rows.length}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 40) / 2,
                  child: _glassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Total: P ${total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? const Center(
                        child: Text(
                          'No offline receipt logs.\nQueued items appear here when database upload fails.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final row = _rows[index];
                          return _glassCard(
                            child: ListTile(
                              leading: Icon(Icons.storage_rounded,
                                  color: themeColor),
                              title: Text(
                                row['serial_no']?.toString().isNotEmpty == true
                                    ? 'Serial ${row['serial_no']}'
                                    : 'Queued Receipt',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: textColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                'Category: ${row['category'] ?? '-'}\n'
                                'Payor: ${row['payor'] ?? '-'}\n'
                                'Queued: ${_fmt(row['queued_at'])}',
                                style: TextStyle(
                                  color: mutedTextColor,
                                  fontSize: 14,
                                  height: 1.35,
                                ),
                              ),
                              trailing: Text(
                                'P ${_amount(row).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: themeColor,
                                ),
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
