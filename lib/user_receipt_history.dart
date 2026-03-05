import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/glass_theme_widgets.dart';
import 'reciept.dart';
import 'category_theme_color.dart';

enum HistoryFilter {
  all,
  today,
  yesterday,
  weekly,
  monthly,
  custom,
}

class UserReceiptHistoryPage extends StatefulWidget {
  final String selectedCategory;

  const UserReceiptHistoryPage({
    super.key,
    this.selectedCategory = 'Marine',
  });

  @override
  State<UserReceiptHistoryPage> createState() => _UserReceiptHistoryPageState();
}

class _UserReceiptHistoryPageState extends State<UserReceiptHistoryPage> {
  HistoryFilter _filter = HistoryFilter.all;
  DateTime? _customStart;
  DateTime? _customEnd;
  bool _isLoading = false;
  List<Map<String, dynamic>> _entries = [];
  final GlobalKey _filterMenuKey = GlobalKey();

  Color _themeColorForCategory(String category) {
    return categoryThemeColor(category);
  }

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final range = _resolveRange();
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        throw Exception('No authenticated user.');
      }
      final base = client
          .from('print_receipts')
          .select(
            'id, receipt_no, payor, payment_method, receipt_date, printed_at, total_amount',
          )
          .eq('owner_id', userId);
      final response = _filter == HistoryFilter.all
          ? await base.order('printed_at', ascending: false)
          : await base
              .gte('printed_at', range.$1.toIso8601String())
              .lte('printed_at', range.$2.toIso8601String())
              .order('printed_at', ascending: false);
      final headers = List<Map<String, dynamic>>.from(response);
      if (!mounted) return;
      final receiptIds = headers
          .map((e) => (e['id'] ?? '').toString())
          .where((e) => e.isNotEmpty)
          .toList();
      final itemsByReceipt = <String, List<Map<String, dynamic>>>{};
      if (receiptIds.isNotEmpty) {
        try {
          final itemRows = await Supabase.instance.client
              .from('print_receipt_items')
              .select(
                  'receipt_id, line_no, "Category", nature, "SubNature", "AcctNo", amount')
              .inFilter('receipt_id', receiptIds)
              .order('line_no');
          for (final raw in List<Map<String, dynamic>>.from(itemRows)) {
            final receiptId = (raw['receipt_id'] ?? '').toString();
            if (receiptId.isEmpty) continue;
            final nature = (raw['nature'] ?? '').toString().trim();
            final subNature = (raw['SubNature'] ?? '').toString().trim();
            final label = subNature.isEmpty ? nature : '$nature - $subNature';
            final amount = (raw['amount'] as num?)?.toDouble() ?? 0.0;
            final item = <String, dynamic>{
              'category': (raw['Category'] ?? '').toString().trim(),
              'nature': label,
              'nature_code': (raw['AcctNo'] ?? '').toString().trim(),
              'amount': amount,
              'price': amount,
            };
            itemsByReceipt.putIfAbsent(receiptId, () => []).add(item);
          }
        } catch (e) {
          debugPrint('History item load failed: $e');
        }
      }
      final normalizedCategory = widget.selectedCategory.trim().toLowerCase();
      final applyCategoryFilter =
          normalizedCategory.isNotEmpty && normalizedCategory != 'all';
      final rows = <Map<String, dynamic>>[];
      for (final header in headers) {
        final receiptId = (header['id'] ?? '').toString();
        final items = itemsByReceipt[receiptId] ?? <Map<String, dynamic>>[];
        String category = '';
        for (final item in items) {
          final c = (item['category'] ?? '').toString().trim();
          if (c.isNotEmpty) {
            category = c;
            break;
          }
        }
        if (category.isEmpty) {
          category = widget.selectedCategory.trim();
        }
        if (applyCategoryFilter &&
            category.isNotEmpty &&
            category.trim().toLowerCase() != normalizedCategory) {
          continue;
        }
        final row = <String, dynamic>{
          ...header,
          'serial_no': (header['receipt_no'] ?? '').toString(),
          'category': category,
          'marine_flow': null,
          'collection_items': items,
          'saved_at': header['printed_at'],
          'price': header['total_amount'],
          'nature_of_collection': _firstNatureFromItems(items),
        };
        rows.add(row);
      }
      setState(() {
        _entries = rows;
      });
    } catch (e) {
      debugPrint('History load failed: $e');
      if (!mounted) return;
      setState(() {
        _entries = [];
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  (DateTime, DateTime) _resolveRange() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1)).subtract(
          const Duration(milliseconds: 1),
        );

    switch (_filter) {
      case HistoryFilter.all:
        return (DateTime(2000, 1, 1), todayEnd);
      case HistoryFilter.today:
        return (todayStart, todayEnd);
      case HistoryFilter.yesterday:
        final start = todayStart.subtract(const Duration(days: 1));
        final end = todayStart.subtract(const Duration(milliseconds: 1));
        return (start, end);
      case HistoryFilter.weekly:
        final start = todayStart.subtract(const Duration(days: 6));
        return (start, todayEnd);
      case HistoryFilter.monthly:
        final start = DateTime(now.year, now.month, 1);
        return (start, todayEnd);
      case HistoryFilter.custom:
        final start = _customStart ?? todayStart;
        final endBase = _customEnd ?? start;
        final end = DateTime(
          endBase.year,
          endBase.month,
          endBase.day,
          23,
          59,
          59,
          999,
        );
        return (start, end);
    }
  }

  Future<void> _pickCustomRange() async {
    final initialStart = _customStart ?? DateTime.now();
    final start = await showDatePicker(
      context: context,
      initialDate: initialStart,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (start == null || !mounted) return;

    final initialEnd = _customEnd ?? start;
    final end = await showDatePicker(
      context: context,
      initialDate: initialEnd.isBefore(start) ? start : initialEnd,
      firstDate: start,
      lastDate: DateTime(2100),
    );
    if (end == null || !mounted) return;

    setState(() {
      _filter = HistoryFilter.custom;
      _customStart = DateTime(start.year, start.month, start.day);
      _customEnd = DateTime(end.year, end.month, end.day);
    });
    _loadEntries();
  }

  String _label(HistoryFilter filter) {
    switch (filter) {
      case HistoryFilter.all:
        return 'All';
      case HistoryFilter.today:
        return 'Today';
      case HistoryFilter.yesterday:
        return 'Yesterday';
      case HistoryFilter.weekly:
        return 'Weekly';
      case HistoryFilter.monthly:
        return 'Monthly';
      case HistoryFilter.custom:
        return 'Custom';
    }
  }

  Future<void> _openFilterMenu() async {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ctx = _filterMenuKey.currentContext;
      if (ctx == null) return;
      final RenderBox button = ctx.findRenderObject() as RenderBox;
      final RenderBox overlay =
          Overlay.of(context).context.findRenderObject() as RenderBox;
      final Rect rect = Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      );
      final selected = await showMenu<HistoryFilter>(
        context: context,
        position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
        items: [
          const PopupMenuItem(
            value: HistoryFilter.all,
            child: Text('All'),
          ),
          const PopupMenuItem(
            value: HistoryFilter.today,
            child: Text('Today'),
          ),
          const PopupMenuItem(
            value: HistoryFilter.yesterday,
            child: Text('Yesterday'),
          ),
          const PopupMenuItem(
            value: HistoryFilter.weekly,
            child: Text('Weekly'),
          ),
          const PopupMenuItem(
            value: HistoryFilter.monthly,
            child: Text('Monthly'),
          ),
          PopupMenuItem(
            value: HistoryFilter.custom,
            child: Text(
              _filter == HistoryFilter.custom &&
                      _customStart != null &&
                      _customEnd != null
                  ? 'Custom (${_customStart!.month}/${_customStart!.day} - ${_customEnd!.month}/${_customEnd!.day})'
                  : 'Custom',
            ),
          ),
        ],
      );
      if (!mounted || selected == null) return;
      if (selected == HistoryFilter.custom) {
        _pickCustomRange();
        return;
      }
      setState(() => _filter = selected);
      _loadEntries();
    });
  }

  String _formatDate(dynamic v) {
    if (v == null) return '-';
    final dt = v is DateTime ? v : DateTime.tryParse(v.toString());
    if (dt == null) return '-';
    return '${dt.month}/${dt.day}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String? _firstNatureFromItems(dynamic items) {
    if (items is! List || items.isEmpty) return null;
    final first = items.first;
    if (first is Map<String, dynamic>) {
      final nature = (first['nature'] ?? first['nature_of_collection'] ?? '')
          .toString()
          .trim();
      return nature.isEmpty ? null : nature;
    }
    return null;
  }

  double _resolveAmount(Map<String, dynamic> row) {
    final printTotal = (row['total_amount'] as num?)?.toDouble();
    if (printTotal != null) return printTotal;

    final direct = (row['price'] as num?)?.toDouble();
    if (direct != null) return direct;

    final items = row['collection_items'];
    if (items is List) {
      return items.fold<double>(0.0, (sum, item) {
        if (item is Map<String, dynamic>) {
          return sum + ((item['price'] as num?)?.toDouble() ?? 0.0);
        }
        return sum;
      });
    }
    return 0.0;
  }

  String _resolveNature(Map<String, dynamic> row) {
    final savedNature = (row['nature_of_collection'] ?? '').toString().trim();
    if (savedNature.isNotEmpty) return savedNature;

    final items = row['collection_items'];
    if (items is List && items.isNotEmpty) {
      final first = items.first;
      if (first is Map<String, dynamic>) {
        final nature = (first['nature'] ?? '').toString().trim();
        if (nature.isNotEmpty) return nature;
      }
    }
    return 'Receipt';
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _themeColorForCategory(widget.selectedCategory);
    final textColor = themeColor.withValues(alpha: 0.95);
    final mutedTextColor = themeColor.withValues(alpha: 0.75);
    final total = _entries.fold<double>(
      0.0,
      (sum, item) => sum + _resolveAmount(item),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Your Receipt History'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            key: _filterMenuKey,
            icon: const Icon(Icons.menu),
            onPressed: _openFilterMenu,
            tooltip: 'Filter',
          ),
        ],
      ),
      body: Stack(
        children: [
          const GlassScaffoldBackground(),
          Column(
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _glassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Entries: ${_entries.length}',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _glassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Total: P ${total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 17,
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
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _entries.isEmpty
                        ? const Center(
                            child: Text('No entries found for this filter.'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            itemCount: _entries.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = _entries[index];
                              final amount = _resolveAmount(item);
                              final serialNo =
                                  item['serial_no']?.toString().trim();
                              return _glassCard(
                                child: ListTile(
                                  leading: Icon(Icons.receipt_long,
                                      color: themeColor),
                                  title: Text(
                                    _resolveNature(item),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: textColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Category: ${item['category'] ?? '-'}\n'
                                    'Flow: ${item['marine_flow'] ?? '-'}\n'
                                    'Serial No: ${serialNo?.isNotEmpty == true ? serialNo : '-'}\n'
                                    'Date: ${_formatDate(item['saved_at'])}',
                                    style: TextStyle(
                                      color: mutedTextColor,
                                      fontSize: 14,
                                      height: 1.35,
                                    ),
                                  ),
                                  trailing: Text(
                                    'P ${amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: themeColor,
                                    ),
                                  ),
                                  isThreeLine: true,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ReceiptScreen(
                                          receiptData: item,
                                          readOnly: true,
                                          showSaveButton: false,
                                          showViewReceiptsButton: false,
                                          showPrintButton: false,
                                          useFullWidth: true,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
              ),
            ],
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
