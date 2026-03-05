import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:pdf/pdf.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'receipt_view.dart';
import 'user_settings_service.dart';
import 'offline_receipt_storage_service.dart';
import 'access_control_service.dart';
import 'category_theme_color.dart';

class ReceiptScreen extends StatefulWidget {
  final String initialCategory;
  final String initialMarineFlow;
  final Map<String, dynamic>? receiptData;
  final bool readOnly;
  final VoidCallback? onSaveSuccess;
  final bool showSaveButton;
  final bool showViewReceiptsButton;
  final bool showPrintButton;
  final bool useFullWidth;
  final bool openManagePayorOnStart;

  const ReceiptScreen({
    super.key,
    this.initialCategory = '',
    this.initialMarineFlow = 'Incoming',
    this.receiptData,
    this.readOnly = false,
    this.onSaveSuccess,
    this.showSaveButton = true,
    this.showViewReceiptsButton = true,
    this.showPrintButton = false,
    this.useFullWidth = false,
    this.openManagePayorOnStart = false,
  });

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  static const double col0 = 140;
  static const double col = 120;
  static const double collectionRowHeight = 24;
  static const double headerRowHeight = 80;
  static const double topRowHeight = 28;
  static const double paymentHeaderRowHeight = 40;
  static const double paymentBlankRowHeight = 22;

  final TextEditingController serialCtrl = TextEditingController();
  final TextEditingController dateCtrl = TextEditingController();
  final TextEditingController agencyCtrl = TextEditingController();
  final TextEditingController fundCtrl = TextEditingController();
  final TextEditingController payorCtrl = TextEditingController();
  final TextEditingController officerCtrl = TextEditingController();

  final int rowCount = 9;
  final List<String?> natures = List<String?>.filled(9, null);
  final List<DateTime?> _natureStartDates = List<DateTime?>.filled(9, null);
  final List<int?> _rowNatureIds = List<int?>.filled(9, null);
  final List<int?> _rowSubNatureIds = List<int?>.filled(9, null);
  final List<TextEditingController> accountCtrls =
      List.generate(9, (_) => TextEditingController());
  final List<TextEditingController> amountCtrls =
      List.generate(9, (_) => TextEditingController());

  double total = 0.0;
  String words = '';
  String? paymentMethod;
  String selectedCategory = '';
  String selectedMarineFlow = 'Incoming';
  bool isSaving = false;
  bool _isPrinting = false;
  bool _hasPendingUnpersistedData = false;
  bool _isLoadingNatures = false;
  String? _naturesLoadError;
  List<Map<String, dynamic>> availableNatures = [];
  bool _isLoadingSubNatures = false;
  String? _subNatureLoadError;
  List<Map<String, dynamic>> _availableSubNatures = [];
  Map<String, dynamic>? _activeNatureForSubNature;
  List<String> _availableCategories = <String>[];
  static const String _penaltyNatureLabel = 'Penalty';
  static const String _amusementTaxNatureLabel = 'amusement tax/';
  static const String _fixedAgencyName = 'CTO CATBALOGAN';
  static const double _popupTextScaleBoost = 0.2;
  int _natureLoadVersion = 0;
  bool _isApplyingAutoAmounts = false;
  final ScrollController _verticalScrollController = ScrollController();
  String? _officerSignatureImagePath;
  String? _officerSignatureImageUrl;
  final GlobalKey _receiptCaptureKey = GlobalKey();
  static final Map<String, _CategoryDraft> _categoryDrafts =
      <String, _CategoryDraft>{};
  final GlobalKey _addButtonKey = GlobalKey();
  final GlobalKey _itemButtonKey = GlobalKey();
  String _natureQuickSearch = '';
  final List<_ManagedPayor> _managedPayors = <_ManagedPayor>[];
  final TextEditingController _payorSearchCtrl = TextEditingController();
  String _payorOverlaySearch = '';
  String _payorOverlayCategory = 'All';
  String _payorOverlayFrequency = 'All';
  String _payorOverlayNature = 'All';
  String _payorOverlaySubNature = 'All';
  bool _allowManagePayorAccess = true;
  bool _payorTablesAvailable = true;
  bool _payorExtendedColumnsAvailable = true;

  void _runAfterFrame(Future<void> Function() action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      action();
    });
  }

  Color _categoryThemeColor(String category) {
    return categoryThemeColor(category);
  }

  void _syncAllPayorSchedules() {
    final now = DateTime.now();
    for (final payor in _managedPayors) {
      payor.ensureScheduleUntil(now.add(const Duration(days: 45)));
    }
  }

  List<_ManagedPayor> _payorsForCurrentCategory() {
    final category = selectedCategory.trim().toLowerCase();
    if (category.isEmpty) return List<_ManagedPayor>.from(_managedPayors);
    return _managedPayors
        .where((p) => p.category.trim().toLowerCase() == category)
        .toList();
  }

  int get _dueTodayCount {
    final now = DateTime.now();
    return _managedPayors
        .where((p) => p.status(now) == _PayorDueStatus.dueToday)
        .length;
  }

  int get _overdueCount {
    final now = DateTime.now();
    return _managedPayors
        .where((p) => p.status(now) == _PayorDueStatus.overdue)
        .length;
  }

  Future<void> _recordPaymentForPayor(
    _ManagedPayor payor, {
    String method = 'cash',
  }) async {
    final now = DateTime.now();
    payor.ensureScheduleUntil(now.add(const Duration(days: 45)));
    final target = payor.firstUnpaidOccurrence();
    if (target == null) return;
    target.paidAt = now;
    target.status = 'paid';
    payor.paymentHistory.insert(
      0,
      _PayorPaymentHistory(
        paidAt: now,
        amount: target.amount,
        method: method,
        dueDate: target.dueDate,
        note: 'Recorded from receipt manager',
      ),
    );
    payor.ensureScheduleUntil(now.add(const Duration(days: 45)));
    await _savePaymentToDb(payor, target, method);
    await _saveManagedPayorToDb(payor);
    setState(() {
      payorCtrl.text = payor.fullName;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Payment recorded for ${payor.fullName}.',
        ),
      ),
    );
  }

  Future<void> _markPayorPaymentFromPrint() async {
    String normalizeName(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

    final payorName = payorCtrl.text.trim();
    if (payorName.isEmpty) return;
    final normalizedPayorName = normalizeName(payorName);
    final categoryKey = selectedCategory.trim().toLowerCase();

    if (_managedPayors.isEmpty) {
      try {
        await _loadManagedPayorsFromDb();
      } catch (_) {
        // best-effort refresh only
      }
    }

    final sameName = _managedPayors
        .where((p) => normalizeName(p.fullName) == normalizedPayorName)
        .toList();
    if (sameName.isEmpty) return;

    final sameCategory = sameName
        .where((p) => p.category.trim().toLowerCase() == categoryKey)
        .toList();
    final payor =
        (sameCategory.isNotEmpty ? sameCategory.first : sameName.first);

    payor.ensureScheduleUntil(DateTime.now().add(const Duration(days: 45)));
    final due = payor.firstUnpaidOccurrence();
    if (due == null) return;
    due.paidAt = DateTime.now();
    due.status = 'paid';
    payor.paymentHistory.insert(
      0,
      _PayorPaymentHistory(
        paidAt: DateTime.now(),
        amount: total > 0 ? total : due.amount,
        method: (paymentMethod ?? 'cash').trim().toLowerCase(),
        dueDate: due.dueDate,
        note: 'Auto-recorded from printed receipt',
      ),
    );
    payor.ensureScheduleUntil(DateTime.now().add(const Duration(days: 45)));
    await _savePaymentToDb(
      payor,
      due,
      (paymentMethod ?? 'cash').trim().toLowerCase(),
    );
    await _saveManagedPayorToDb(payor);
  }

  Future<void> _showPayorHistoryDialog(_ManagedPayor payor) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return _wrapPopupTextScale(
          context,
          AlertDialog(
            title: Text('Payment History - ${payor.fullName}'),
            content: SizedBox(
              width: 520,
              child: payor.paymentHistory.isEmpty
                  ? const Text('No payment history yet.')
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: payor.paymentHistory.length,
                      separatorBuilder: (_, __) => const Divider(height: 10),
                      itemBuilder: (context, index) {
                        final row = payor.paymentHistory[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            '${_formatDay(row.paidAt)} - PHP ${row.amount.toStringAsFixed(2)}',
                          ),
                          subtitle: Text(
                            'Due: ${_formatDay(row.dueDate)} | ${row.method.toUpperCase()}',
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  String _occurrenceStatusLabel(_PayorOccurrence occ) {
    if (occ.isPaid) return 'Paid';
    final status = occ.status.trim().toLowerCase();
    if (status == 'missed') return 'Missed';
    return 'Pending';
  }

  Color _occurrenceStatusColor(_PayorOccurrence occ) {
    if (occ.isPaid) return const Color(0xFF2E7D32);
    final status = occ.status.trim().toLowerCase();
    if (status == 'missed') return const Color(0xFFB3261E);
    return const Color(0xFFB26A00);
  }

  Future<void> _markOccurrencePaid(
    _ManagedPayor payor,
    _PayorOccurrence occ,
  ) async {
    final now = DateTime.now();
    final method = (paymentMethod ?? 'cash').trim().toLowerCase();
    occ.paidAt = now;
    occ.status = 'paid';
    payor.paymentHistory.insert(
      0,
      _PayorPaymentHistory(
        paidAt: now,
        amount: occ.amount,
        method: method,
        dueDate: occ.dueDate,
        note: 'Recorded from payor schedule',
      ),
    );
    await _savePaymentToDb(payor, occ, method);
    await _saveManagedPayorToDb(payor);
  }

  Future<void> _markOccurrenceMissed(
    _ManagedPayor payor,
    _PayorOccurrence occ,
  ) async {
    occ.paidAt = null;
    occ.status = 'missed';
    final scheduleId = payor.scheduleId;
    if (scheduleId == null || scheduleId.isEmpty) return;
    try {
      await Supabase.instance.client
          .from('payor_schedule_occurrences')
          .update({
            'paid_at': null,
            'status': 'missed',
          })
          .eq('schedule_id', scheduleId)
          .eq('due_date', _dateOnly(occ.dueDate).toIso8601String());
      await _saveManagedPayorToDb(payor);
    } catch (e) {
      debugPrint('Mark missed failed: $e');
    }
  }

  Future<void> _showPayorScheduleDialog(
    _ManagedPayor payor,
    StateSetter setModalState,
  ) async {
    payor.ensureScheduleUntil(DateTime.now().add(const Duration(days: 45)));
    await showDialog<void>(
      context: context,
      builder: (context) => _wrapPopupTextScale(
        context,
        StatefulBuilder(
          builder: (context, setDialogState) {
            final rows = List<_PayorOccurrence>.from(payor.occurrences)
              ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
            final totalAmount =
                rows.fold<double>(0.0, (sum, item) => sum + item.amount);
            final totalPaid = rows
                .where((e) => e.isPaid)
                .fold<double>(0.0, (sum, item) => sum + item.amount);
            final totalUnpaid = totalAmount - totalPaid;

            return AlertDialog(
              title: Text('Schedule - ${payor.fullName}'),
              content: SizedBox(
                width: 660,
                child: rows.isEmpty
                    ? const Text('No schedule entries found.')
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: rows.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 10),
                              itemBuilder: (context, index) {
                                final occ = rows[index];
                                final statusLabel = _occurrenceStatusLabel(occ);
                                final statusColor = _occurrenceStatusColor(occ);
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    '${_formatDay(occ.dueDate)} - PHP ${occ.amount.toStringAsFixed(2)}',
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(
                                              alpha: 0.14),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Wrap(
                                    spacing: 6,
                                    children: [
                                      OutlinedButton(
                                        onPressed: occ.isPaid
                                            ? null
                                            : () async {
                                                await _markOccurrencePaid(
                                                    payor, occ);
                                                setState(() {});
                                                setModalState(() {});
                                                setDialogState(() {});
                                              },
                                        child: const Text('Paid'),
                                      ),
                                      OutlinedButton(
                                        onPressed: occ.isPaid
                                            ? null
                                            : () async {
                                                await _markOccurrenceMissed(
                                                    payor, occ);
                                                setState(() {});
                                                setModalState(() {});
                                                setDialogState(() {});
                                              },
                                        child: const Text('Miss'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7FB),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFD9E2EF)),
                            ),
                            child: Text(
                              'Total: PHP ${totalAmount.toStringAsFixed(2)}   |   '
                              'Paid: PHP ${totalPaid.toStringAsFixed(2)}   |   '
                              'Unpaid: PHP ${totalUnpaid.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatDay(DateTime value) {
    final d = value.toLocal();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$mm/$dd/$yyyy';
  }

  Color _dueStatusColor(_PayorDueStatus status) {
    switch (status) {
      case _PayorDueStatus.dueToday:
        return const Color(0xFFB26A00);
      case _PayorDueStatus.overdue:
        return const Color(0xFFB3261E);
      case _PayorDueStatus.notDueYet:
        return const Color(0xFF2E7D32);
    }
  }

  String _dueStatusLabel(_PayorDueStatus status) {
    switch (status) {
      case _PayorDueStatus.dueToday:
        return 'Due Today';
      case _PayorDueStatus.overdue:
        return 'Overdue';
      case _PayorDueStatus.notDueYet:
        return 'Not Due Yet';
    }
  }

  Future<void> _loadManagePayorAccessPolicy() async {
    try {
      final policy = await AccessControlService.getCurrentUserPolicy();
      if (!mounted) return;
      setState(() {
        _allowManagePayorAccess = policy.allowManagePayor;
        if (!policy.allowManagePayor) {
          _managedPayors.clear();
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _allowManagePayorAccess = true;
      });
    }
  }

  _PayorFrequency _frequencyFromDb(String raw) {
    final v = raw.trim().toLowerCase();
    switch (v) {
      case 'one_time':
      case 'one-time':
        return _PayorFrequency.oneTime;
      case 'daily':
        return _PayorFrequency.daily;
      case 'weekly':
        return _PayorFrequency.weekly;
      case 'every_15_days':
      case 'every 15 days':
        return _PayorFrequency.every15Days;
      case 'custom_interval':
      case 'custom':
        return _PayorFrequency.customInterval;
      case 'monthly':
      default:
        return _PayorFrequency.monthly;
    }
  }

  String _frequencyToDb(_PayorFrequency frequency) {
    switch (frequency) {
      case _PayorFrequency.oneTime:
        return 'one_time';
      case _PayorFrequency.daily:
        return 'daily';
      case _PayorFrequency.weekly:
        return 'weekly';
      case _PayorFrequency.every15Days:
        return 'every_15_days';
      case _PayorFrequency.customInterval:
        return 'custom_interval';
      case _PayorFrequency.monthly:
        return 'monthly';
    }
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  double _computedPayorAmount({
    required double stallPrice,
    required _PayorFrequency frequency,
  }) {
    if (stallPrice <= 0) return 0.0;
    switch (frequency) {
      case _PayorFrequency.daily:
        return stallPrice / 30;
      case _PayorFrequency.weekly:
        return stallPrice / 4;
      case _PayorFrequency.every15Days:
        return stallPrice / 2;
      case _PayorFrequency.monthly:
      case _PayorFrequency.oneTime:
      case _PayorFrequency.customInterval:
        return stallPrice;
    }
  }

  bool _isMissingPayorExtendedColumnError(Object error) {
    if (error is! PostgrestException || error.code != '42703') return false;
    final msg = error.message.toLowerCase();
    return msg.contains('payors.building') ||
        msg.contains('payors.stall') ||
        msg.contains('payors.stall_price') ||
        msg.contains('payors.nature') ||
        msg.contains('payors.sub_nature');
  }

  Future<void> _loadManagedPayorsFromDb({bool allowRetry = true}) async {
    if (!_allowManagePayorAccess) return;
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      final payorSelect = _payorExtendedColumnsAvailable
          ? 'id, full_name, category, nature, sub_nature, building, stall, stall_price, contact, notes, created_at'
          : 'id, full_name, category, contact, notes, created_at';
      final payorRows = await client
          .from('payors')
          .select(payorSelect)
          .eq('owner_id', userId)
          .order('created_at', ascending: false);

      final payorList = List<Map<String, dynamic>>.from(payorRows);
      if (payorList.isEmpty) {
        if (!mounted) return;
        setState(() => _managedPayors.clear());
        return;
      }

      final payorIds = payorList
          .map((e) => e['id']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();

      final scheduleRows = await client
          .from('payor_schedules')
          .select(
            'id, payor_id, frequency, custom_interval_days, start_date, default_amount, is_paused, next_due_date',
          )
          .inFilter('payor_id', payorIds);
      final scheduleList = List<Map<String, dynamic>>.from(scheduleRows);
      final scheduleByPayor = <String, Map<String, dynamic>>{};
      for (final row in scheduleList) {
        final payorId = (row['payor_id'] ?? '').toString();
        if (payorId.isNotEmpty && !scheduleByPayor.containsKey(payorId)) {
          scheduleByPayor[payorId] = row;
        }
      }

      final scheduleIds = scheduleList
          .map((e) => e['id']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();

      final occurrenceBySchedule = <String, List<Map<String, dynamic>>>{};
      final paymentsBySchedule = <String, List<Map<String, dynamic>>>{};
      if (scheduleIds.isNotEmpty) {
        final occRows = await client
            .from('payor_schedule_occurrences')
            .select('schedule_id, due_date, amount, paid_at, status')
            .inFilter('schedule_id', scheduleIds)
            .order('due_date');
        for (final row in List<Map<String, dynamic>>.from(occRows)) {
          final sid = (row['schedule_id'] ?? '').toString();
          if (sid.isEmpty) continue;
          occurrenceBySchedule.putIfAbsent(sid, () => []).add(row);
        }

        final paymentRows = await client
            .from('payor_payments')
            .select('schedule_id, due_date, paid_at, amount, method, note')
            .inFilter('schedule_id', scheduleIds)
            .order('paid_at', ascending: false);
        for (final row in List<Map<String, dynamic>>.from(paymentRows)) {
          final sid = (row['schedule_id'] ?? '').toString();
          if (sid.isEmpty) continue;
          paymentsBySchedule.putIfAbsent(sid, () => []).add(row);
        }
      }

      final loaded = <_ManagedPayor>[];
      for (final p in payorList) {
        final id = (p['id'] ?? '').toString();
        if (id.isEmpty) continue;
        final schedule = scheduleByPayor[id];
        final scheduleId =
            schedule == null ? null : (schedule['id'] ?? '').toString();
        final freq =
            _frequencyFromDb((schedule?['frequency'] ?? '').toString());
        final customDays = int.tryParse(
              (schedule?['custom_interval_days'] ?? '').toString(),
            ) ??
            30;
        final startDate = DateTime.tryParse(
              (schedule?['start_date'] ?? '').toString(),
            ) ??
            DateTime.now();
        final amount = double.tryParse(
              (schedule?['default_amount'] ?? '').toString(),
            ) ??
            0.0;
        final isPaused = (schedule?['is_paused'] ?? false) == true;
        final occRows = scheduleId == null
            ? const <Map<String, dynamic>>[]
            : (occurrenceBySchedule[scheduleId] ??
                const <Map<String, dynamic>>[]);
        final paymentRows = scheduleId == null
            ? const <Map<String, dynamic>>[]
            : (paymentsBySchedule[scheduleId] ??
                const <Map<String, dynamic>>[]);

        final occurrences = occRows
            .map((row) {
              final due = DateTime.tryParse((row['due_date'] ?? '').toString());
              if (due == null) return null;
              final amt =
                  double.tryParse((row['amount'] ?? '').toString()) ?? amount;
              final paidAt =
                  DateTime.tryParse((row['paid_at'] ?? '').toString());
              final status = (row['status'] ?? '').toString().trim();
              return _PayorOccurrence(
                dueDate: _dateOnly(due),
                amount: amt,
                paidAt: paidAt,
                status: status.isEmpty
                    ? (paidAt == null ? 'expected' : 'paid')
                    : status.toLowerCase(),
              );
            })
            .whereType<_PayorOccurrence>()
            .toList();
        final history = paymentRows
            .map((row) {
              final paidAt =
                  DateTime.tryParse((row['paid_at'] ?? '').toString());
              final due = DateTime.tryParse((row['due_date'] ?? '').toString());
              if (paidAt == null || due == null) return null;
              return _PayorPaymentHistory(
                paidAt: paidAt,
                amount:
                    double.tryParse((row['amount'] ?? '').toString()) ?? 0.0,
                method: (row['method'] ?? 'cash').toString(),
                dueDate: _dateOnly(due),
                note: (row['note'] ?? '').toString(),
              );
            })
            .whereType<_PayorPaymentHistory>()
            .toList();

        final createdAt =
            DateTime.tryParse((p['created_at'] ?? '').toString()) ??
                DateTime.now();
        final managed = _ManagedPayor(
          id: id,
          scheduleId: scheduleId,
          fullName: (p['full_name'] ?? '').toString(),
          category: (p['category'] ?? '').toString(),
          nature: _payorExtendedColumnsAvailable
              ? (p['nature'] ?? '').toString()
              : '',
          subNature: _payorExtendedColumnsAvailable
              ? (p['sub_nature'] ?? '').toString()
              : '',
          building: _payorExtendedColumnsAvailable
              ? (p['building'] ?? '').toString()
              : '',
          stall: _payorExtendedColumnsAvailable
              ? (p['stall'] ?? '').toString()
              : '',
          stallPrice: _payorExtendedColumnsAvailable
              ? (double.tryParse((p['stall_price'] ?? '').toString()) ?? amount)
              : amount,
          contact: (p['contact'] ?? '').toString(),
          notes: (p['notes'] ?? '').toString(),
          frequency: freq,
          customIntervalDays: customDays,
          startDate: _dateOnly(startDate),
          defaultAmount: amount,
          createdAt: createdAt,
          isPaused: isPaused,
          occurrences: occurrences,
          paymentHistory: history,
        );
        managed
            .ensureScheduleUntil(DateTime.now().add(const Duration(days: 45)));
        loaded.add(managed);
      }

      if (!mounted) return;
      setState(() {
        _payorTablesAvailable = true;
        _managedPayors
          ..clear()
          ..addAll(loaded);
      });
    } catch (e) {
      if (_isMissingPayorExtendedColumnError(e)) {
        _payorExtendedColumnsAvailable = false;
        if (allowRetry) {
          await _loadManagedPayorsFromDb(allowRetry: false);
          return;
        }
      }
      if (e is PostgrestException && e.code == 'PGRST205') {
        if (!mounted) return;
        setState(() => _payorTablesAvailable = false);
        debugPrint(
          'Payor DB unavailable: required payor tables are missing.',
        );
        return;
      }
      debugPrint('Payor DB load skipped/failed: $e');
    }
  }

  Future<void> _saveManagedPayorToDb(
    _ManagedPayor payor, {
    bool allowRetry = true,
  }) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null || !_uuidRegex.hasMatch(userId)) {
      debugPrint('Payor DB save skipped: invalid auth user id.');
      return;
    }

    try {
      String payorId = _uuidRegex.hasMatch(payor.id) ? payor.id : '';
      final payorPayload = <String, dynamic>{
        'owner_id': userId,
        'full_name': payor.fullName,
        'category': payor.category,
        'contact': payor.contact.isEmpty ? null : payor.contact,
        'notes': payor.notes.isEmpty ? null : payor.notes,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (_payorExtendedColumnsAvailable) {
        payorPayload['nature'] = payor.nature.isEmpty ? null : payor.nature;
        payorPayload['sub_nature'] =
            payor.subNature.isEmpty ? null : payor.subNature;
        payorPayload['building'] =
            payor.building.isEmpty ? null : payor.building;
        payorPayload['stall'] = payor.stall.isEmpty ? null : payor.stall;
        payorPayload['stall_price'] = payor.stallPrice;
      }
      Map<String, dynamic>? existing;
      if (payorId.isNotEmpty) {
        existing = await client
            .from('payors')
            .select('id')
            .eq('id', payorId)
            .maybeSingle();
      }
      if (existing == null) {
        final inserted = await client
            .from('payors')
            .insert(payorPayload)
            .select('id')
            .single();
        payorId = (inserted['id'] ?? '').toString();
      } else {
        await client.from('payors').update(payorPayload).eq('id', payorId);
      }
      if (payorId.isEmpty) return;
      payor.id = payorId;

      final schedulePayload = <String, dynamic>{
        'payor_id': payorId,
        'frequency': _frequencyToDb(payor.frequency),
        'custom_interval_days': payor.customIntervalDays,
        'start_date': _dateOnly(payor.startDate).toIso8601String(),
        'default_amount': payor.defaultAmount,
        'is_paused': payor.isPaused,
        'next_due_date': payor.nextDueDate?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      var scheduleId = payor.scheduleId ?? '';
      if (scheduleId.isNotEmpty && !_uuidRegex.hasMatch(scheduleId)) {
        scheduleId = '';
      }
      if (scheduleId.isEmpty) {
        final inserted = await client
            .from('payor_schedules')
            .insert(schedulePayload)
            .select('id')
            .single();
        scheduleId = (inserted['id'] ?? '').toString();
      } else {
        await client
            .from('payor_schedules')
            .update(schedulePayload)
            .eq('id', scheduleId);
      }
      payor.scheduleId = scheduleId;
      if (scheduleId.isEmpty) return;

      payor.ensureScheduleUntil(DateTime.now().add(const Duration(days: 45)));
      final existingOccRows = await client
          .from('payor_schedule_occurrences')
          .select('id, due_date, status')
          .eq('schedule_id', scheduleId);
      final occByDate = <String, String>{};
      for (final row in List<Map<String, dynamic>>.from(existingOccRows)) {
        final due = DateTime.tryParse((row['due_date'] ?? '').toString());
        final id = (row['id'] ?? '').toString();
        if (due == null || id.isEmpty) continue;
        occByDate[_dateOnly(due).toIso8601String()] = id;
      }

      for (final occ in payor.occurrences) {
        final key = _dateOnly(occ.dueDate).toIso8601String();
        final payload = <String, dynamic>{
          'schedule_id': scheduleId,
          'due_date': key,
          'amount': occ.amount,
          'paid_at': occ.paidAt?.toIso8601String(),
          'status': occ.paidAt == null
              ? (occ.status.trim().isEmpty ? 'expected' : occ.status)
              : 'paid',
        };
        final occId = occByDate[key];
        if (occId == null) {
          await client.from('payor_schedule_occurrences').insert(payload);
        } else {
          await client
              .from('payor_schedule_occurrences')
              .update(payload)
              .eq('id', occId);
        }
      }
    } catch (e) {
      if (_isMissingPayorExtendedColumnError(e)) {
        _payorExtendedColumnsAvailable = false;
        if (allowRetry) {
          await _saveManagedPayorToDb(payor, allowRetry: false);
          return;
        }
      }
      debugPrint('Payor DB save failed: $e');
    }
  }

  Future<void> _deleteManagedPayorFromDb(_ManagedPayor payor) async {
    if (!_uuidRegex.hasMatch(payor.id)) return;
    try {
      await Supabase.instance.client.from('payors').delete().eq('id', payor.id);
    } catch (e) {
      debugPrint('Payor DB delete failed: $e');
    }
  }

  Future<void> _savePaymentToDb(
    _ManagedPayor payor,
    _PayorOccurrence occurrence,
    String method,
  ) async {
    final scheduleId = payor.scheduleId;
    if (scheduleId == null || scheduleId.isEmpty) return;
    try {
      final now = DateTime.now();
      await Supabase.instance.client.from('payor_payments').insert({
        'schedule_id': scheduleId,
        'due_date': _dateOnly(occurrence.dueDate).toIso8601String(),
        'paid_at': now.toIso8601String(),
        'amount': occurrence.amount,
        'method': method,
        'note': 'Recorded from receipt manager',
        'receipt_serial_no': serialCtrl.text.trim(),
      });
      await Supabase.instance.client
          .from('payor_schedule_occurrences')
          .update({
            'paid_at': now.toIso8601String(),
            'status': 'paid',
          })
          .eq('schedule_id', scheduleId)
          .eq('due_date', _dateOnly(occurrence.dueDate).toIso8601String());
    } catch (e) {
      debugPrint('Payor payment DB save failed: $e');
    }
  }

  List<_ManagedPayor> _filteredPayors() {
    _syncAllPayorSchedules();
    final q = _payorOverlaySearch.trim().toLowerCase();
    return _managedPayors.where((p) {
      if (q.isNotEmpty && !p.fullName.toLowerCase().contains(q)) return false;
      if (_payorOverlayCategory != 'All' &&
          p.category != _payorOverlayCategory) {
        return false;
      }
      if (_payorOverlayFrequency != 'All' &&
          p.frequency.label != _payorOverlayFrequency) {
        return false;
      }
      if (_payorOverlayNature != 'All' &&
          p.nature.trim().toLowerCase() !=
              _payorOverlayNature.trim().toLowerCase()) {
        return false;
      }
      if (_payorOverlaySubNature != 'All' &&
          p.subNature.trim().toLowerCase() !=
              _payorOverlaySubNature.trim().toLowerCase()) {
        return false;
      }
      return true;
    }).toList();
  }

  List<String> get _payorNatureOptions {
    final set = <String>{'All'};
    for (final p in _managedPayors) {
      final value = p.nature.trim();
      if (value.isNotEmpty) {
        set.add(value);
      }
    }
    final list = set.toList();
    final base = list.where((e) => e != 'All').toList()..sort();
    return ['All', ...base];
  }

  List<String> get _payorSubNatureOptions {
    final set = <String>{'All'};
    final selectedNature = _payorOverlayNature.trim().toLowerCase();
    for (final p in _managedPayors) {
      if (selectedNature != 'all' &&
          p.nature.trim().toLowerCase() != selectedNature) {
        continue;
      }
      final value = p.subNature.trim();
      if (value.isNotEmpty) {
        set.add(value);
      }
    }
    final list = set.toList();
    final base = list.where((e) => e != 'All').toList()..sort();
    return ['All', ...base];
  }

  Future<void> _openManagePayorOverlay() async {
    if (!_allowManagePayorAccess) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Manage Payor is disabled for your account.'),
        ),
      );
      return;
    }
    if (!_payorTablesAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Manage Payor is not ready: missing payor tables in Supabase.',
          ),
        ),
      );
      return;
    }
    _syncAllPayorSchedules();
    _payorOverlaySearch = '';
    _payorSearchCtrl.text = '';
    _payorOverlayCategory = 'All';
    _payorOverlayFrequency = 'All';
    _payorOverlayNature = 'All';
    _payorOverlaySubNature = 'All';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final rows = _filteredPayors();
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.86,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(22)),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 560;
                      final filterWidth = isCompact
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 8) / 2;
                      return Column(
                        children: [
                          if (isCompact) ...[
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Manage Payor',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text('Due Today: $_dueTodayCount'),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEBEE),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text('Overdue: $_overdueCount'),
                                ),
                              ],
                            ),
                          ] else ...[
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Manage Payor',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text('Due Today: $_dueTodayCount'),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEBEE),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text('Overdue: $_overdueCount'),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          if (isCompact) ...[
                            TextField(
                              controller: _payorSearchCtrl,
                              onChanged: (v) => setModalState(() {
                                _payorOverlaySearch = v;
                              }),
                              decoration: const InputDecoration(
                                labelText: 'Search payor',
                                isDense: true,
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () async {
                                  await _showUpsertPayorDialog(setModalState);
                                },
                                icon: const Icon(Icons.person_add_alt_1),
                                label: const Text('Add New Payor'),
                              ),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _payorSearchCtrl,
                                    onChanged: (v) => setModalState(() {
                                      _payorOverlaySearch = v;
                                    }),
                                    decoration: const InputDecoration(
                                      labelText: 'Search payor',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.search),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.icon(
                                  onPressed: () async {
                                    await _showUpsertPayorDialog(setModalState);
                                  },
                                  icon: const Icon(Icons.person_add_alt_1),
                                  label: const Text('Add New Payor'),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          if (isCompact) ...[
                            _overlayFilterDropdown(
                              width: constraints.maxWidth,
                              value: _payorOverlayCategory,
                              label: 'Category',
                              items: <String>[
                                'All',
                                ...{
                                  ..._availableCategories,
                                  ..._managedPayors.map((p) => p.category),
                                }.where((e) => e.trim().isNotEmpty),
                              ],
                              onChanged: (v) => setModalState(() {
                                _payorOverlayCategory = v ?? 'All';
                              }),
                            ),
                            const SizedBox(height: 8),
                            _overlayFilterDropdown(
                              width: constraints.maxWidth,
                              value: _payorOverlayFrequency,
                              label: 'Frequency',
                              items: const <String>[
                                'All',
                                'One-time',
                                'Daily',
                                'Weekly',
                                'Every 15 days',
                                'Monthly',
                                'Custom interval',
                              ],
                              onChanged: (v) => setModalState(() {
                                _payorOverlayFrequency = v ?? 'All';
                              }),
                            ),
                            const SizedBox(height: 8),
                            _overlayFilterDropdown(
                              width: constraints.maxWidth,
                              value: _payorOverlayNature,
                              label: 'Nature',
                              items: _payorNatureOptions,
                              onChanged: (v) => setModalState(() {
                                _payorOverlayNature = v ?? 'All';
                                _payorOverlaySubNature = 'All';
                              }),
                            ),
                            const SizedBox(height: 8),
                            _overlayFilterDropdown(
                              width: constraints.maxWidth,
                              value: _payorOverlaySubNature,
                              label: 'SubNature',
                              items: _payorSubNatureOptions,
                              onChanged: (v) => setModalState(() {
                                _payorOverlaySubNature = v ?? 'All';
                              }),
                            ),
                          ] else ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _overlayFilterDropdown(
                                  width: filterWidth,
                                  value: _payorOverlayCategory,
                                  label: 'Category',
                                  items: <String>[
                                    'All',
                                    ...{
                                      ..._availableCategories,
                                      ..._managedPayors.map((p) => p.category),
                                    }.where((e) => e.trim().isNotEmpty),
                                  ],
                                  onChanged: (v) => setModalState(() {
                                    _payorOverlayCategory = v ?? 'All';
                                  }),
                                ),
                                _overlayFilterDropdown(
                                  width: filterWidth,
                                  value: _payorOverlayFrequency,
                                  label: 'Frequency',
                                  items: const <String>[
                                    'All',
                                    'One-time',
                                    'Daily',
                                    'Weekly',
                                    'Every 15 days',
                                    'Monthly',
                                    'Custom interval',
                                  ],
                                  onChanged: (v) => setModalState(() {
                                    _payorOverlayFrequency = v ?? 'All';
                                  }),
                                ),
                                _overlayFilterDropdown(
                                  width: filterWidth,
                                  value: _payorOverlayNature,
                                  label: 'Nature',
                                  items: _payorNatureOptions,
                                  onChanged: (v) => setModalState(() {
                                    _payorOverlayNature = v ?? 'All';
                                    _payorOverlaySubNature = 'All';
                                  }),
                                ),
                                _overlayFilterDropdown(
                                  width: filterWidth,
                                  value: _payorOverlaySubNature,
                                  label: 'SubNature',
                                  items: _payorSubNatureOptions,
                                  onChanged: (v) => setModalState(() {
                                    _payorOverlaySubNature = v ?? 'All';
                                  }),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          Expanded(
                            child: rows.isEmpty
                                ? const Center(
                                    child: Text('No payor records found.'))
                                : ListView.separated(
                                    controller: scrollController,
                                    itemCount: rows.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 10),
                                    itemBuilder: (context, index) {
                                      final payor = rows[index];
                                      final now = DateTime.now();
                                      final status = payor.status(now);
                                      final statusColor =
                                          _dueStatusColor(status);
                                      final statusLabel =
                                          _dueStatusLabel(status);
                                      final nextDue = payor.nextDueDate;
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          payor.fullName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${payor.category} | ${payor.frequency.label} | '
                                          'Nature: ${payor.nature.isEmpty ? '-' : payor.nature} | '
                                          'Sub: ${payor.subNature.isEmpty ? '-' : payor.subNature} | '
                                          'Next Due: ${nextDue == null ? '-' : _formatDay(nextDue)}',
                                        ),
                                        trailing: Wrap(
                                          spacing: 6,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(
                                                    alpha: 0.14),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                statusLabel,
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            PopupMenuButton<String>(
                                              onSelected: (value) {
                                                _runAfterFrame(() async {
                                                  if (value == 'history') {
                                                    await _showPayorHistoryDialog(
                                                        payor);
                                                  } else if (value ==
                                                      'record') {
                                                    await _recordPaymentForPayor(
                                                        payor);
                                                    setModalState(() {});
                                                  } else if (value == 'edit') {
                                                    await _showUpsertPayorDialog(
                                                      setModalState,
                                                      existing: payor,
                                                    );
                                                  } else if (value == 'pause') {
                                                    setState(() {
                                                      payor.isPaused =
                                                          !payor.isPaused;
                                                    });
                                                    await _saveManagedPayorToDb(
                                                      payor,
                                                    );
                                                    setModalState(() {});
                                                  } else if (value ==
                                                      'delete') {
                                                    if (payor.paymentHistory
                                                        .isNotEmpty) {
                                                      if (!mounted) return;
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Cannot delete payor with payment history.',
                                                          ),
                                                        ),
                                                      );
                                                      return;
                                                    }
                                                    setState(() {
                                                      _managedPayors
                                                          .remove(payor);
                                                    });
                                                    await _deleteManagedPayorFromDb(
                                                      payor,
                                                    );
                                                    setModalState(() {});
                                                  }
                                                });
                                              },
                                              itemBuilder: (_) => [
                                                const PopupMenuItem(
                                                  value: 'history',
                                                  child: Text(
                                                      'View payment history'),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'record',
                                                  child: Text(
                                                      'Record payment now'),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'edit',
                                                  child: Text('Edit schedule'),
                                                ),
                                                PopupMenuItem(
                                                  value: 'pause',
                                                  child: Text(
                                                    payor.isPaused
                                                        ? 'Resume schedule'
                                                        : 'Pause schedule',
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text('Delete payor'),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        onTap: () {
                                          setState(() {
                                            payorCtrl.text = payor.fullName;
                                          });
                                          _runAfterFrame(() async {
                                            await _showPayorScheduleDialog(
                                              payor,
                                              setModalState,
                                            );
                                          });
                                        },
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _overlayFilterDropdown({
    required double width,
    required String value,
    required String label,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        isDense: true,
        isExpanded: true,
        value: items.contains(value) ? value : items.first,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: items
            .map(
              (e) => DropdownMenuItem<String>(
                value: e,
                child: Text(
                  e,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _showUpsertPayorDialog(
    StateSetter setModalState, {
    _ManagedPayor? existing,
  }) async {
    final nameCtrl = TextEditingController(text: existing?.fullName ?? '');
    final natureCtrl = TextEditingController(text: existing?.nature ?? '');
    final subNatureCtrl =
        TextEditingController(text: existing?.subNature ?? '');
    final contactCtrl = TextEditingController(text: existing?.contact ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final buildingCtrl = TextEditingController(text: existing?.building ?? '');
    final stallCtrl = TextEditingController(text: existing?.stall ?? '');
    final stallPriceCtrl = TextEditingController(
      text: (existing?.stallPrice ?? 0).toStringAsFixed(2),
    );
    final amountCtrl = TextEditingController(
      text: (existing?.defaultAmount ?? 0).toStringAsFixed(2),
    );
    String category = existing?.category ??
        (selectedCategory.trim().isEmpty
            ? (_availableCategories.isEmpty
                ? 'General'
                : _availableCategories.first)
            : selectedCategory);
    _PayorFrequency frequency = existing?.frequency ?? _PayorFrequency.monthly;
    DateTime startDate = existing?.startDate ?? DateTime.now();
    int customDays = existing?.customIntervalDays ?? 30;
    void refreshComputedAmount([StateSetter? stateSetter]) {
      final stallPrice = double.tryParse(stallPriceCtrl.text.trim()) ?? 0.0;
      final computed = _computedPayorAmount(
        stallPrice: stallPrice,
        frequency: frequency,
      );
      amountCtrl.text = computed.toStringAsFixed(2);
      stateSetter?.call(() {});
    }

    if (existing == null) {
      refreshComputedAmount();
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return _wrapPopupTextScale(
          context,
          StatefulBuilder(
            builder: (context, setDialogState) {
              final screenWidth = MediaQuery.of(context).size.width;
              final dialogWidth =
                  screenWidth < 600 ? screenWidth * 0.92 : 540.0;
              return AlertDialog(
                title: Text(existing == null ? 'Add New Payor' : 'Edit Payor'),
                content: SizedBox(
                  width: dialogWidth,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Payor Full Name *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: natureCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nature',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: subNatureCtrl,
                          decoration: const InputDecoration(
                            labelText: 'SubNature',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: category,
                          decoration: const InputDecoration(
                            labelText: 'Category *',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            ...{
                              category,
                              ..._availableCategories,
                            }.where((e) => e.trim().isNotEmpty)
                          ]
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    e,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          selectedItemBuilder: (context) {
                            final options = <String>[
                              ...{
                                category,
                                ..._availableCategories,
                              }.where((e) => e.trim().isNotEmpty),
                            ];
                            return options
                                .map(
                                  (e) => Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      e,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList();
                          },
                          onChanged: (v) {
                            if (v == null) return;
                            setDialogState(() => category = v);
                          },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<_PayorFrequency>(
                          isExpanded: true,
                          value: frequency,
                          decoration: const InputDecoration(
                            labelText: 'Frequency *',
                            border: OutlineInputBorder(),
                          ),
                          items: _PayorFrequency.values
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    e.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          selectedItemBuilder: (context) {
                            return _PayorFrequency.values
                                .map(
                                  (e) => Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      e.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList();
                          },
                          onChanged: (v) {
                            if (v == null) return;
                            setDialogState(() {
                              frequency = v;
                              refreshComputedAmount();
                            });
                          },
                        ),
                        if (frequency == _PayorFrequency.customInterval) ...[
                          const SizedBox(height: 8),
                          TextField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Custom interval (days)',
                              border: OutlineInputBorder(),
                            ),
                            controller: TextEditingController(
                                text: customDays.toString()),
                            onChanged: (v) {
                              final parsed = int.tryParse(v.trim());
                              if (parsed != null && parsed > 0) {
                                customDays = parsed;
                              }
                            },
                          ),
                        ],
                        const SizedBox(height: 8),
                        TextField(
                          controller: buildingCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Building *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: stallCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Stall *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: stallPriceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Stall Price *',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) =>
                              refreshComputedAmount(setDialogState),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: amountCtrl,
                          readOnly: true,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Start Date'),
                          subtitle: Text(_formatDay(startDate)),
                          trailing: const Icon(Icons.calendar_month),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: startDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked == null) return;
                            setDialogState(() => startDate = picked);
                          },
                        ),
                        TextField(
                          controller: contactCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Contact (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: notesCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Notes (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (saved != true) return;
    final name = nameCtrl.text.trim();
    final nature = natureCtrl.text.trim();
    final subNature = subNatureCtrl.text.trim();
    final building = buildingCtrl.text.trim();
    final stall = stallCtrl.text.trim();
    final stallPrice = double.tryParse(stallPriceCtrl.text.trim()) ?? 0.0;
    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
    if (name.isEmpty ||
        category.trim().isEmpty ||
        building.isEmpty ||
        stall.isEmpty ||
        stallPrice <= 0 ||
        amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payor name, category, building, stall, stall price, and amount are required.',
          ),
        ),
      );
      return;
    }

    final candidate = _ManagedPayor(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      scheduleId: existing?.scheduleId,
      fullName: name,
      category: category,
      nature: nature,
      subNature: subNature,
      building: building,
      stall: stall,
      stallPrice: stallPrice,
      contact: contactCtrl.text.trim(),
      notes: notesCtrl.text.trim(),
      frequency: frequency,
      customIntervalDays: customDays,
      startDate: startDate,
      defaultAmount: amount,
      createdAt: existing?.createdAt ?? DateTime.now(),
      isPaused: existing?.isPaused ?? false,
      occurrences: existing?.occurrences ?? <_PayorOccurrence>[],
      paymentHistory: existing?.paymentHistory ?? <_PayorPaymentHistory>[],
    );
    candidate.ensureScheduleUntil(DateTime.now().add(const Duration(days: 45)));

    final overlap = _managedPayors.any((p) {
      if (existing != null && p.id == existing.id) return false;
      if (p.fullName.trim().toLowerCase() != name.toLowerCase()) return false;
      if (p.category.trim().toLowerCase() != category.toLowerCase()) {
        return false;
      }
      final a = p.startDate;
      final b = startDate;
      final diff = a.difference(b).inDays.abs();
      return diff <= 31;
    });
    if (overlap) {
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Possible duplicate schedule'),
              content: const Text(
                'A similar schedule exists for this payor/category. Continue anyway?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('No'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Yes'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
    }

    setState(() {
      if (existing == null) {
        _managedPayors.add(candidate);
      } else {
        final idx = _managedPayors.indexWhere((p) => p.id == existing.id);
        if (idx >= 0) _managedPayors[idx] = candidate;
      }
      payorCtrl.text = candidate.fullName;
    });
    await _saveManagedPayorToDb(candidate);
    await _loadManagedPayorsFromDb();
    setModalState(() {});
  }

  @override
  void initState() {
    super.initState();
    selectedCategory = widget.initialCategory;
    selectedMarineFlow = widget.initialMarineFlow;
    agencyCtrl.text = _fixedAgencyName;
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final yy = (now.year % 100).toString().padLeft(2, '0');
    dateCtrl.text = '$mm/$dd/$yy';
    for (final ctrl in amountCtrls) {
      ctrl.addListener(_recalculate);
    }
    if (widget.receiptData != null) {
      _applyReceiptData(widget.receiptData!);
    }
    if (widget.receiptData == null && selectedCategory.trim().isNotEmpty) {
      _restoreDraftForCategory(selectedCategory);
    }
    if (!widget.readOnly) {
      _ensurePenaltyNature();
    }
    _loadUserSettings();
    _loadAvailableCategories();
    _loadManagePayorAccessPolicy();
    if (!widget.readOnly) {
      _loadAvailableNatures();
    }
    _loadManagedPayorsFromDb();
    _syncAllPayorSchedules();
    if (widget.openManagePayorOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openManagePayorOverlay();
      });
    }
  }

  @override
  void didUpdateWidget(covariant ReceiptScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.receiptData != widget.receiptData &&
        widget.receiptData != null) {
      _applyReceiptData(widget.receiptData!);
    }

    if (oldWidget.receiptData != widget.receiptData ||
        oldWidget.readOnly != widget.readOnly) {
      _loadUserSettings();
    }
  }

  void _applyReceiptData(Map<String, dynamic> receipt) {
    selectedCategory = receipt['category'] ?? selectedCategory;
    selectedMarineFlow = receipt['marine_flow'] ?? selectedMarineFlow;

    final savedAt = receipt['saved_at'];
    if (savedAt != null) {
      final date =
          savedAt is DateTime ? savedAt : DateTime.tryParse(savedAt.toString());
      if (date != null) {
        final mm = date.month.toString().padLeft(2, '0');
        final dd = date.day.toString().padLeft(2, '0');
        final yy = (date.year % 100).toString().padLeft(2, '0');
        dateCtrl.text = '$mm/$dd/$yy';
      }
    }

    serialCtrl.text = receipt['serial_no']?.toString() ?? '';
    agencyCtrl.text = _fixedAgencyName;
    fundCtrl.text = receipt['fund']?.toString() ?? '';
    payorCtrl.text = receipt['payor']?.toString() ?? '';
    officerCtrl.text = receipt['officer']?.toString() ?? '';
    paymentMethod = receipt['payment_method']?.toString();
    _officerSignatureImagePath = receipt['officer_signature_path']?.toString();
    _officerSignatureImageUrl =
        UserSettingsService.publicSignatureUrl(_officerSignatureImagePath);

    for (int i = 0; i < rowCount; i++) {
      natures[i] = null;
      _natureStartDates[i] = null;
      _rowNatureIds[i] = null;
      _rowSubNatureIds[i] = null;
      accountCtrls[i].clear();
      amountCtrls[i].clear();
    }

    final items = receipt['collection_items'];
    if (items is List && items.isNotEmpty) {
      for (int i = 0; i < items.length && i < rowCount; i++) {
        final item = items[i];
        if (item is Map) {
          final nature = item['nature'] ?? item['nature_of_collection'];
          final amount =
              item['price'] ?? item['amount'] ?? item['collection_price'];
          natures[i] = nature?.toString();
          _natureStartDates[i] = _parseStartDate(item['start_date']);
          final rawNatureId = item['NatureID'] ?? item['nature_id'];
          _rowNatureIds[i] = rawNatureId is num
              ? rawNatureId.toInt()
              : int.tryParse(rawNatureId?.toString() ?? '');
          final rawSubNatureId = item['SubNatureID'] ?? item['sub_nature_id'];
          _rowSubNatureIds[i] = rawSubNatureId is num
              ? rawSubNatureId.toInt()
              : int.tryParse(rawSubNatureId?.toString() ?? '');
          accountCtrls[i].text = item['account_code']?.toString() ?? '';
          amountCtrls[i].text = amount != null ? amount.toString() : '';
        }
      }
    } else {
      final fallbackNature =
          (receipt['nature_of_collection'] ?? receipt['nature'])?.toString();
      final fallbackAmount = receipt['price'] ??
          receipt['collection_price'] ??
          receipt['total_amount'];
      if (fallbackNature != null && fallbackNature.trim().isNotEmpty) {
        natures[0] = fallbackNature.trim();
        _natureStartDates[0] = _parseStartDate(receipt['permit_start_date']);
        final rawNatureId = receipt['NatureID'] ?? receipt['nature_id'];
        _rowNatureIds[0] = rawNatureId is num
            ? rawNatureId.toInt()
            : int.tryParse(rawNatureId?.toString() ?? '');
        final rawSubNatureId =
            receipt['SubNatureID'] ?? receipt['sub_nature_id'];
        _rowSubNatureIds[0] = rawSubNatureId is num
            ? rawSubNatureId.toInt()
            : int.tryParse(rawSubNatureId?.toString() ?? '');
        amountCtrls[0].text =
            fallbackAmount != null ? fallbackAmount.toString() : '';
      }
    }
    if (!widget.readOnly) {
      _ensurePenaltyNature();
    }
    _recalculate();
  }

  int get _penaltyRowIndex => rowCount - 1;

  bool _isPenaltyRow(int index) => index == _penaltyRowIndex;

  String _categoryDraftKey(String category) => category.trim().toLowerCase();

  void _saveDraftForCurrentCategory({bool markUnsaved = true}) {
    final key = _categoryDraftKey(selectedCategory);
    if (key.isEmpty) return;
    _categoryDrafts[key] = _CategoryDraft(
      natures: List<String?>.from(natures),
      natureStartDates:
          _natureStartDates.map((d) => d?.toIso8601String()).toList(),
      accountCodes: accountCtrls.map((c) => c.text).toList(),
      amounts: amountCtrls.map((c) => c.text).toList(),
      marineFlow: selectedMarineFlow,
    );
    if (markUnsaved) {
      _hasPendingUnpersistedData = true;
    }
  }

  void _restoreDraftForCategory(String category) {
    final key = _categoryDraftKey(category);
    final draft = _categoryDrafts[key];
    if (draft == null) {
      // Keep current inputs when switching to a category with no saved draft.
      return;
    }

    for (int i = 0; i < rowCount; i++) {
      natures[i] = i < draft.natures.length ? draft.natures[i] : null;
      _natureStartDates[i] = i < draft.natureStartDates.length
          ? _parseStartDate(draft.natureStartDates[i])
          : null;
      _rowNatureIds[i] = null;
      _rowSubNatureIds[i] = null;
      accountCtrls[i].text =
          i < draft.accountCodes.length ? draft.accountCodes[i] : '';
      amountCtrls[i].text = i < draft.amounts.length ? draft.amounts[i] : '';
    }
    if (draft.marineFlow.isNotEmpty) {
      selectedMarineFlow = draft.marineFlow;
    }
    _ensurePenaltyNature();
    _recalculate();
  }

  void _ensurePenaltyNature() {
    if (_penaltyRowIndex < 0 || _penaltyRowIndex >= natures.length) return;
    final current = (natures[_penaltyRowIndex] ?? '').trim();
    if (current.isEmpty) {
      natures[_penaltyRowIndex] = _penaltyNatureLabel;
    }
  }

  Future<void> _loadUserSettings() async {
    try {
      final saved = await UserSettingsService.fetchSettings();
      final serialStatus = await UserSettingsService.fetchMySerialStatus();
      if (!mounted) return;
      final defaultOfficer =
          (saved?['collecting_officer_name'] ?? '').toString();
      final signaturePath = (saved?['signature_image_path'] ?? '').toString();
      final rangeNextSerial =
          int.tryParse((serialStatus?['next_serial_no'] ?? '').toString());
      final rangeEndSerial =
          int.tryParse((serialStatus?['serial_end_no'] ?? '').toString());
      final savedNextSerial =
          int.tryParse((saved?['next_serial_no'] ?? '').toString()) ?? 1;
      final currentShown = int.tryParse(serialCtrl.text.trim()) ?? 0;
      final nextSerialNo = [
        rangeNextSerial ?? 0,
        savedNextSerial,
        currentShown,
      ].reduce((a, b) => a > b ? a : b);
      final rangeBlocked = rangeNextSerial != null &&
          rangeEndSerial != null &&
          rangeNextSerial > rangeEndSerial;
      setState(() {
        serialCtrl.text = nextSerialNo.toString();
        final currentPath = (_officerSignatureImagePath ?? '').trim();
        if ((currentPath.isEmpty || _officerSignatureImageUrl == null) &&
            signaturePath.isNotEmpty) {
          _officerSignatureImagePath = signaturePath;
          _officerSignatureImageUrl =
              UserSettingsService.publicSignatureUrl(signaturePath);
        }
      });
      if (rangeBlocked && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your assigned serial range is exhausted. Contact admin for a new range.',
            ),
          ),
        );
      }
    } catch (_) {
      // Ignore settings load failures on receipt rendering.
    }
  }

  Future<void> _loadAvailableNatures() async {
    final requestVersion = ++_natureLoadVersion;
    if (mounted) {
      setState(() {
        _isLoadingNatures = true;
        _naturesLoadError = null;
        _natureQuickSearch = '';
      });
    }
    try {
      final normalizedRows = await _fetchAvailableNaturesNow();
      if (!mounted || requestVersion != _natureLoadVersion) return;
      setState(() {
        availableNatures = normalizedRows;
        _isLoadingNatures = false;
      });
    } catch (e) {
      print('Error loading natures: $e');
      if (!mounted || requestVersion != _natureLoadVersion) return;
      setState(() {
        availableNatures = [];
        _isLoadingNatures = false;
        _naturesLoadError = e.toString();
      });
    }
  }

  String _normalizeCategoryKey(String value) {
    return value.trim().toLowerCase();
  }

  Future<void> _loadAvailableCategories() async {
    try {
      final client = Supabase.instance.client;
      final policy = await AccessControlService.getCurrentUserPolicy();
      final npRows = await client
          .from('NatureParticular')
          .select('Category, NATURECATID')
          .order('SEQ');
      final natureRows = List<Map<String, dynamic>>.from(npRows);

      final seen = <String>{};
      final categories = <String>[];

      void addCategory(dynamic raw) {
        final value = (raw ?? '').toString().trim();
        if (value.isEmpty) return;
        final lower = value.toLowerCase();
        if (lower == 'null') return;
        if (RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) return;
        final key = _normalizeCategoryKey(value);
        if (!AccessControlService.isCategoryAllowed(policy, value)) return;
        if (seen.add(key)) {
          categories.add(value);
        }
      }

      for (final row in natureRows) {
        addCategory(row['Category']);
      }

      if (categories.isNotEmpty) {
        categories.sort();
      }

      if (!mounted) return;
      final hadNoSelectedCategory = selectedCategory.trim().isEmpty;
      setState(() {
        _availableCategories = categories;
        if (selectedCategory.trim().isEmpty && categories.isNotEmpty) {
          selectedCategory = categories.first;
        } else if (selectedCategory.trim().isNotEmpty &&
            !categories.any((c) =>
                _normalizeCategoryKey(c) ==
                _normalizeCategoryKey(selectedCategory))) {
          selectedCategory = categories.isNotEmpty ? categories.first : '';
        }
      });
      if (hadNoSelectedCategory && categories.isNotEmpty) {
        _loadAvailableNatures();
      }
    } catch (e) {
      debugPrint('Failed to load categories from NatureParticular: $e');
      if (!mounted) return;
      setState(() {
        _availableCategories = <String>[];
      });
    }
  }

  String? _resolvedCategoryValue() {
    if (_availableCategories.isEmpty) return null;
    final selectedKey = _normalizeCategoryKey(selectedCategory);
    for (final category in _availableCategories) {
      if (_normalizeCategoryKey(category) == selectedKey) {
        return category;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _fetchAvailableNaturesNow() async {
    if (selectedCategory.trim().isEmpty) {
      return <Map<String, dynamic>>[];
    }
    final client = Supabase.instance.client;
    final policy = await AccessControlService.getCurrentUserPolicy();
    if (!AccessControlService.isCategoryAllowed(policy, selectedCategory)) {
      return <Map<String, dynamic>>[];
    }
    try {
      final npData = await client
          .from('NatureParticular')
          .select('NATUREID, Nature, AccntCode, Category, NATURECATID, SEQ')
          .order('SEQ');
      final selectedKey = _normalizeCategoryKey(selectedCategory);

      final normalizedRows = List<Map<String, dynamic>>.from(npData)
          .where((row) {
            final categoryKey =
                _normalizeCategoryKey((row['Category'] ?? '').toString());
            final catIdKey =
                _normalizeCategoryKey((row['NATURECATID'] ?? '').toString());
            return categoryKey == selectedKey || catIdKey == selectedKey;
          })
          .where((row) {
            final rowCategory =
                (row['Category'] ?? row['NATURECATID'] ?? '').toString().trim();
            final rawNatureId = row['NATUREID'];
            final natureId = rawNatureId is num
                ? rawNatureId.toInt()
                : int.tryParse(rawNatureId?.toString() ?? '');
            return AccessControlService.isNatureAllowed(
              policy,
              natureId: natureId,
              category: rowCategory,
            );
          })
          .map((row) {
            return <String, dynamic>{
              'nature_of_collection': row['Nature'],
              'amount': null,
              'nature_code': row['AccntCode'],
              'nature_id': row['NATUREID'],
            };
          })
          .where((row) =>
              (row['nature_of_collection'] ?? '').toString().trim().isNotEmpty)
          .toList();

      if (normalizedRows.isNotEmpty) return normalizedRows;
      return <Map<String, dynamic>>[];
    } catch (e) {
      debugPrint('Failed to fetch natures from NatureParticular: $e');
      return <Map<String, dynamic>>[];
    }
  }

  @override
  void dispose() {
    if (!widget.readOnly && _hasPendingUnpersistedData) {
      _categoryDrafts.clear();
    }
    _natureLoadVersion++;
    _verticalScrollController.dispose();
    _payorSearchCtrl.dispose();
    serialCtrl.dispose();
    dateCtrl.dispose();
    agencyCtrl.dispose();
    fundCtrl.dispose();
    payorCtrl.dispose();
    officerCtrl.dispose();
    for (final c in accountCtrls) {
      c.dispose();
    }
    for (final c in amountCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<bool> _showQuantityPopup(int index, double amount) async {
    final quantityController = TextEditingController(text: '1');
    String operation = 'times';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return _wrapPopupTextScale(
          context,
          AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: const Text('Enter Quantity'),
            content: StatefulBuilder(
              builder: (context, setDialogState) {
                final quantity =
                    double.tryParse(quantityController.text.trim()) ?? 1.0;
                final preview = quantity > 0
                    ? (operation == 'divide'
                        ? amount / quantity
                        : amount * quantity)
                    : 0.0;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        hintText: 'Enter quantity',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Option',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4A5568),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Times'),
                          selected: operation == 'times',
                          onSelected: (_) {
                            setDialogState(() => operation = 'times');
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Divide'),
                          selected: operation == 'divide',
                          onSelected: (_) {
                            setDialogState(() => operation = 'divide');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F7FB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        quantity <= 0
                            ? 'Result: enter quantity greater than 0'
                            : 'Result: ${preview.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final quantity =
                      double.tryParse(quantityController.text.trim()) ?? 1.0;
                  if (quantity <= 0) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Quantity must be greater than 0.'),
                      ),
                    );
                    return;
                  }
                  final totalAmount = operation == 'divide'
                      ? amount / quantity
                      : amount * quantity;
                  amountCtrls[index].text = totalAmount.toStringAsFixed(2);
                  _recalculate();
                  Navigator.of(context).pop(true);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
    return confirmed == true;
  }

  Widget _wrapPopupTextScale(BuildContext context, Widget child) {
    final media = MediaQuery.of(context);
    final baseScale = media.textScaler.scale(1.0);
    final boostedScale = (baseScale + _popupTextScaleBoost).clamp(1.0, 3.0);
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(boostedScale)),
      child: child,
    );
  }

  void _recalculate() {
    if (_isApplyingAutoAmounts) return;

    bool isAmusementNature(String? value) {
      final v = (value ?? '').trim().toLowerCase();
      return v == _amusementTaxNatureLabel || v.contains('amusement tax');
    }

    final amusementIndexes = <int>[];
    double subtotalWithoutAmusement = 0.0;
    for (int i = 0; i < amountCtrls.length; i++) {
      final amount = double.tryParse(amountCtrls[i].text.trim()) ?? 0.0;
      if (isAmusementNature(natures[i])) {
        amusementIndexes.add(i);
      } else {
        subtotalWithoutAmusement += amount;
      }
    }

    if (amusementIndexes.isNotEmpty) {
      final amusementAmount =
          ((subtotalWithoutAmusement * 0.10) * 100).round() / 100;
      _isApplyingAutoAmounts = true;
      try {
        for (int i = 0; i < amusementIndexes.length; i++) {
          final idx = amusementIndexes[i];
          final target = i == 0 ? amusementAmount : 0.0;
          final text = target == 0.0 ? '' : target.toStringAsFixed(2);
          if (amountCtrls[idx].text.trim() != text) {
            amountCtrls[idx].text = text;
          }
        }
      } finally {
        _isApplyingAutoAmounts = false;
      }
    }

    double t = 0.0;
    for (final c in amountCtrls) {
      final v = double.tryParse(c.text) ?? 0.0;
      t += v;
    }
    total = (t * 100).truncate() / 100;
    words = _numberToWords(total);
    setState(() {});
  }

  String _numberToWords(double amount) {
    if (amount <= 0) return '';
    final units = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine'
    ];
    final teens = [
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen'
    ];
    final tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety'
    ];

    final parts = amount.toStringAsFixed(2).split('.');
    int num = int.parse(parts[0]);
    String w = '';

    if (num >= 1000) {
      w += '${units[(num ~/ 1000).clamp(0, 9)]} Thousand ';
      num %= 1000;
    }
    if (num >= 100) {
      w += '${units[(num ~/ 100).clamp(0, 9)]} Hundred ';
      num %= 100;
    }
    if (num >= 20) {
      w += '${tens[(num ~/ 10).clamp(0, 9)]} ';
      num %= 10;
    } else if (num >= 10) {
      w += '${teens[num - 10]} ';
      num = 0;
    }
    if (num > 0) {
      w += '${units[num]} ';
    }
    w += 'Pesos';

    final cents = int.tryParse(parts[1]) ?? 0;
    if (cents > 0) {
      w += ' and ${cents.toString().padLeft(2, '0')}/100 Only';
    } else {
      w += ' Only';
    }

    return w;
  }

  Widget _cell({
    required double width,
    double? height,
    EdgeInsets padding = const EdgeInsets.all(3),
    bool thick = false,
    bool doubleBottom = false,
    bool noBottom = false,
    bool noTop = false,
    Alignment alignment = Alignment.centerLeft,
    Widget? child,
  }) {
    final BorderSide side1 =
        BorderSide(color: Colors.black, width: thick ? 2 : 1);
    const BorderSide side2 = BorderSide(color: Colors.black, width: 1);

    return Container(
      width: width,
      height: height,
      padding: padding,
      alignment: alignment,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: side1,
          right: side1,
          top: noTop ? BorderSide.none : side1,
          bottom: noBottom ? BorderSide.none : (doubleBottom ? side2 : side1),
        ),
      ),
      child: child,
    );
  }

  Widget _headerCell(String text) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          height: 1.3,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _natureDropdown(int i, double height) {
    if (widget.readOnly) {
      final displayText = _displayNatureTextForRow(i);
      final isDateRow = _isStartDateDisplayRow(i);
      return SizedBox(
        height: height,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            displayText,
            style: TextStyle(
              fontSize: 11,
              color: isDateRow ? Colors.black54 : Colors.black,
              fontStyle: isDateRow ? FontStyle.italic : FontStyle.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    if (_isPenaltyRow(i)) {
      natures[i] = _penaltyNatureLabel;
      return SizedBox(
        height: height,
        child: const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _penaltyNatureLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    if (_isStartDateDisplayRow(i)) {
      return SizedBox(
        height: height,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _displayNatureTextForRow(i),
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black54,
              fontStyle: FontStyle.italic,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    return InkWell(
      onTap: () => _handleNatureSelection(i),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(
              child: Text(
                natures[i] ?? 'Search nature...',
                style: TextStyle(
                  fontSize: 11,
                  color: natures[i] == null ? Colors.black54 : Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.search, size: 14),
          ],
        ),
      ),
    );
  }

  Future<void> _handleNatureSelection(int i) async {
    if (widget.readOnly || _isStartDateDisplayRow(i)) return;
    final selected = await _showNatureSearchDialog();
    if (selected == null) return;
    await _applySelectedNatureToRow(i, selected);
  }

  Future<bool> _applySelectedNatureToRow(
    int i,
    Map<String, dynamic> selected,
  ) async {
    final previousNature = natures[i];
    final previousStartDate = _natureStartDates[i];
    final previousNatureId = _rowNatureIds[i];
    final previousSubNatureId = _rowSubNatureIds[i];
    final previousAccountCode = accountCtrls[i].text;
    final previousAmountText = amountCtrls[i].text;

    void rollback() {
      setState(() {
        natures[i] = previousNature;
        _natureStartDates[i] = previousStartDate;
        _rowNatureIds[i] = previousNatureId;
        _rowSubNatureIds[i] = previousSubNatureId;
        accountCtrls[i].text = previousAccountCode;
        amountCtrls[i].text = previousAmountText;
      });
      _saveDraftForCurrentCategory();
      _recalculate();
    }

    final selectedName = selected['nature_of_collection']?.toString();
    if (selectedName == null || selectedName.isEmpty) {
      setState(() {
        natures[i] = null;
        _natureStartDates[i] = null;
        _rowNatureIds[i] = null;
        _rowSubNatureIds[i] = null;
      });
      amountCtrls[i].clear();
      _saveDraftForCurrentCategory();
      _recalculate();
      return false;
    }

    String resolvedNatureName = selectedName;
    String resolvedCode = (selected['nature_code'] ?? '').toString().trim();
    int? resolvedSubNatureId;
    final inlineSubName = (selected['sub_nature'] ?? '').toString().trim();
    final inlineSubAcct = (selected['sub_acct_no'] ?? '').toString().trim();
    final inlineSubNatureIdRaw = selected['sub_nature_id'];
    final inlineSubNatureId = inlineSubNatureIdRaw is num
        ? inlineSubNatureIdRaw.toInt()
        : int.tryParse(inlineSubNatureIdRaw?.toString() ?? '');
    final rawNatureId = selected['nature_id'];
    final natureId = rawNatureId is num
        ? rawNatureId.toInt()
        : int.tryParse(rawNatureId?.toString() ?? '');

    if (inlineSubName.isNotEmpty) {
      resolvedNatureName = '$selectedName - $inlineSubName';
      resolvedSubNatureId = inlineSubNatureId;
      if (inlineSubAcct.isNotEmpty) {
        resolvedCode = inlineSubAcct;
      }
    } else if (natureId != null) {
      final subNature = await _showSubNatureDialog(natureId);
      if (subNature == null) {
        // User cancelled subnature picker or no subnature available.
        return false;
      }
      final subName = (subNature['SubNature'] ?? '').toString().trim();
      if (subName.isNotEmpty) {
        resolvedNatureName = '$selectedName - $subName';
        final rawSubId = subNature['SubNatureID'];
        resolvedSubNatureId = rawSubId is num
            ? rawSubId.toInt()
            : int.tryParse(rawSubId?.toString() ?? '');
        final subAcct = (subNature['AcctNo'] ?? '').toString().trim();
        if (subAcct.isNotEmpty) {
          resolvedCode = subAcct;
        }
      }
    }

    setState(() {
      natures[i] = resolvedNatureName;
      _rowNatureIds[i] = natureId;
      _rowSubNatureIds[i] = resolvedSubNatureId;
      if (resolvedCode.isNotEmpty) {
        accountCtrls[i].text = resolvedCode;
      }
      if (!_requiresStartDateForBusinessPermit()) {
        _natureStartDates[i] = null;
      }
    });

    if (_requiresStartDateForBusinessPermit()) {
      final picked = await _showBusinessPermitStartDatePopup(
        initialDate: _natureStartDates[i] ?? DateTime.now(),
      );
      if (picked == null) {
        rollback();
        return false;
      }
      if (mounted) {
        setState(() {
          _natureStartDates[i] = picked;
        });
      }
    }

    _saveDraftForCurrentCategory();
    double amount = (selected['amount'] as num?)?.toDouble() ?? 0.0;
    if (amount <= 0) {
      final manualAmount = await _showAmountPopup();
      if (manualAmount == null) {
        rollback();
        return false;
      }
      amount = manualAmount;
    }

    final applied = _usesPeriodPricing()
        ? await _showPeriodPopup(i, amount)
        : await _showQuantityPopup(i, amount);
    if (!applied) {
      rollback();
      return false;
    }
    _saveDraftForCurrentCategory();
    _recalculate();
    return true;
  }

  Future<Map<String, dynamic>?> _showSubNatureDialog(int natureId) async {
    List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
    try {
      rows = await _fetchSubNaturesForNature(natureId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load subnature: $e')),
        );
      }
      return null;
    }

    if (rows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No subnature found for this nature.')),
        );
      }
      return null;
    }

    final selected = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) {
        return _wrapPopupTextScale(
          context,
          AlertDialog(
            title: const Text('Select Subnature'),
            content: SizedBox(
              width: 460,
              height: 360,
              child: ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 10),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final label = (row['SubNature'] ?? '').toString().trim();
                  final acct = (row['AcctNo'] ?? '').toString().trim();
                  return ListTile(
                    dense: true,
                    title: Text(label.isEmpty ? '-' : label),
                    subtitle: acct.isEmpty ? null : Text('Acct: $acct'),
                    onTap: () => Navigator.pop(context, row),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );

    return selected;
  }

  Future<List<Map<String, dynamic>>> _fetchSubNaturesForNature(
    int natureId,
  ) async {
    final client = Supabase.instance.client;
    final exact = await client
        .from('SubNature')
        .select('SubNatureID, SubNature, AcctNo, NatureID')
        .eq('NatureID', natureId)
        .order('SubNature');
    if (exact.isNotEmpty) {
      return List<Map<String, dynamic>>.from(exact);
    }

    final asText = await client
        .from('SubNature')
        .select('SubNatureID, SubNature, AcctNo, NatureID')
        .eq('NatureID', natureId.toString())
        .order('SubNature');
    if (asText.isNotEmpty) {
      return List<Map<String, dynamic>>.from(asText);
    }

    final allRows = await client
        .from('SubNature')
        .select('SubNatureID, SubNature, AcctNo, NatureID')
        .order('SubNature');
    final rows = List<Map<String, dynamic>>.from(allRows).where((row) {
      final raw = row['NatureID'];
      if (raw == null) return false;
      if (raw is num) return raw.toInt() == natureId;
      final text = raw.toString().trim();
      if (text == natureId.toString()) return true;
      final parsedInt = int.tryParse(text);
      if (parsedInt != null) return parsedInt == natureId;
      final parsedDouble = double.tryParse(text);
      if (parsedDouble != null) return parsedDouble.toInt() == natureId;
      return false;
    }).toList();
    return rows;
  }

  bool _requiresStartDateForBusinessPermit() {
    final v = selectedCategory.toLowerCase().trim();
    return v == 'business permit fees' || v.contains('business permit');
  }

  DateTime? _parseStartDate(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  String _formatStartDateDisplay(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    return 'Start Date: $mm/$dd/$yyyy';
  }

  String? _natureLine2(int index) {
    final date = _natureStartDates[index];
    if (date == null) return null;
    return _formatStartDateDisplay(date);
  }

  bool _isStartDateDisplayRow(int index) {
    if (index <= 0 || index >= rowCount) return false;
    if ((natures[index] ?? '').trim().isNotEmpty) return false;
    return _natureLine2(index - 1) != null;
  }

  String _displayNatureTextForRow(int index) {
    final value = (natures[index] ?? '').trim();
    if (value.isNotEmpty) return value;
    if (_isStartDateDisplayRow(index)) {
      return _natureLine2(index - 1) ?? '';
    }
    return '';
  }

  Future<DateTime?> _showBusinessPermitStartDatePopup({
    required DateTime initialDate,
  }) async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 10, 1, 1);
    final lastDate = DateTime(now.year + 20, 12, 31);
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select Start Date',
      fieldLabelText: 'Start Date',
      builder: (context, child) {
        return _wrapPopupTextScale(
          context,
          child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  bool _usesPeriodPricing() {
    final category = selectedCategory.toLowerCase().trim();
    return category == 'rent' ||
        category == 'market operation' ||
        category == 'market operations' ||
        (category.contains('market') && category.contains('operation'));
  }

  Future<bool> _showPeriodPopup(int index, double monthlyAmount) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return _wrapPopupTextScale(
          context,
          SimpleDialog(
            title: const Text('Select Period'),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop('1day'),
                child: const Text('1 day'),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop('1week'),
                child: const Text('1 week'),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop('15days'),
                child: const Text('15 days'),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop('month'),
                child: const Text('Whole month'),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null) return false;

    double computed = monthlyAmount;
    switch (selected) {
      case '1day':
        computed = monthlyAmount / 30;
        break;
      case '1week':
        computed = monthlyAmount / 4;
        break;
      case '15days':
        computed = monthlyAmount / 2;
        break;
      case 'month':
      default:
        computed = monthlyAmount;
        break;
    }

    amountCtrls[index].text = computed.toStringAsFixed(2);
    _recalculate();
    return true;
  }

  Future<Map<String, dynamic>?> _showNatureSearchDialog() async {
    final searchCtrl = TextEditingController();
    String query = '';
    List<Map<String, dynamic>> dialogNatures = List<Map<String, dynamic>>.from(
      availableNatures,
    );

    if (dialogNatures.isEmpty) {
      try {
        dialogNatures = await _fetchAvailableNaturesNow();
        if (mounted) {
          setState(() {
            availableNatures = dialogNatures;
          });
        }
      } catch (_) {
        dialogNatures = <Map<String, dynamic>>[];
      }
    }

    final selected = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) {
        return _wrapPopupTextScale(
          context,
          StatefulBuilder(
            builder: (context, setDialogState) {
              final filtered = dialogNatures.where((nature) {
                final label = (nature['nature_of_collection'] ?? '')
                    .toString()
                    .toLowerCase();
                return label.contains(query.toLowerCase());
              }).toList();

              return AlertDialog(
                title: const Text('Find Nature of Collection'),
                content: SizedBox(
                  width: 480,
                  height: 420,
                  child: Column(
                    children: [
                      TextField(
                        controller: searchCtrl,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Search...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) {
                          setDialogState(() {
                            query = v;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  'No nature entries found for this category.',
                                ),
                              )
                            : ListView.builder(
                                itemCount: filtered.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    return ListTile(
                                      leading: const Icon(Icons.clear),
                                      title: const Text('Clear selection'),
                                      onTap: () => Navigator.pop(
                                        context,
                                        <String, dynamic>{
                                          'nature_of_collection': null,
                                        },
                                      ),
                                    );
                                  }
                                  final nature = filtered[index - 1];
                                  final label =
                                      (nature['nature_of_collection'] ?? '')
                                          .toString();
                                  final amount =
                                      (nature['amount'] as num?)?.toDouble() ??
                                          0.0;
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      label,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    trailing: Text(amount.toStringAsFixed(2)),
                                    onTap: () => Navigator.pop(context, nature),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Cancel'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    searchCtrl.dispose();
    return selected;
  }

  Widget _amountField(TextEditingController c) {
    return TextField(
      controller: c,
      readOnly: widget.readOnly,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => _saveDraftForCurrentCategory(),
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 21.9),
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
      ),
    );
  }

  List<Map<String, dynamic>> _buildCollectionItems() {
    final List<Map<String, dynamic>> items = [];
    for (int i = 0; i < rowCount; i++) {
      final amount = double.tryParse(amountCtrls[i].text.trim()) ?? 0;
      final accountCode = accountCtrls[i].text.trim();
      final nature = _isPenaltyRow(i) ? _penaltyNatureLabel : natures[i];
      if (_isPenaltyRow(i) && amount <= 0) {
        continue;
      }
      if (amount <= 0 &&
          accountCode.isEmpty &&
          (nature == null || nature.isEmpty)) {
        continue;
      }
      String? resolvedNatureCode;
      if (accountCode.isNotEmpty) {
        resolvedNatureCode = accountCode;
      } else {
        final selectedNature = (nature ?? '').trim().toLowerCase();
        if (selectedNature.isNotEmpty) {
          for (final row in availableNatures) {
            final label = (row['nature_of_collection'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
            if (label != selectedNature) continue;
            final code = (row['nature_code'] ?? '').toString().trim();
            if (code.isNotEmpty) {
              resolvedNatureCode = code;
              break;
            }
          }
        }
      }
      items.add({
        'category': selectedCategory,
        'nature': nature,
        'nature_line2': _natureLine2(i),
        'nature_id': _rowNatureIds[i],
        'sub_nature_id': _rowSubNatureIds[i],
        'start_date': _natureStartDates[i]?.toIso8601String(),
        'account_code': accountCode,
        'nature_code': resolvedNatureCode,
        'price': amount,
      });
    }
    return items;
  }

  Map<String, String?> _splitNatureAndSubNature(String rawNature) {
    final value = rawNature.trim();
    if (value.isEmpty) {
      return <String, String?>{
        'nature': null,
        'sub_nature': null,
      };
    }
    final separatorIndex = value.indexOf(' - ');
    if (separatorIndex <= 0 || separatorIndex >= value.length - 3) {
      return <String, String?>{
        'nature': value,
        'sub_nature': null,
      };
    }
    final nature = value.substring(0, separatorIndex).trim();
    final subNature = value.substring(separatorIndex + 3).trim();
    return <String, String?>{
      'nature': nature.isEmpty ? null : nature,
      'sub_nature': subNature.isEmpty ? null : subNature,
    };
  }

  String _normalizedPaymentMethod(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value == 'cash' || value == 'check' || value == 'money') {
      return value;
    }
    return 'cash';
  }

  DateTime _receiptDateForDb(DateTime fallbackNow) {
    final raw = dateCtrl.text.trim();
    final parts = raw.split('/');
    if (parts.length == 3) {
      final mm = int.tryParse(parts[0]);
      final dd = int.tryParse(parts[1]);
      final yy = int.tryParse(parts[2]);
      if (mm != null && dd != null && yy != null) {
        final year = yy < 100 ? 2000 + yy : yy;
        final parsed = DateTime.tryParse(
          DateTime(year, mm, dd).toIso8601String(),
        );
        if (parsed != null) return parsed;
      }
    }
    return fallbackNow;
  }

  Future<void> _insertNormalizedPrintReceipt({
    required String serialForLog,
    required DateTime now,
    required List<Map<String, dynamic>> items,
  }) async {
    final client = Supabase.instance.client;
    final ownerId = client.auth.currentUser?.id;
    if (ownerId == null || ownerId.isEmpty) {
      throw Exception('No authenticated user. Cannot set owner_id.');
    }
    final receiptDate = _receiptDateForDb(now);
    final payor = payorCtrl.text.trim().isEmpty ? '-' : payorCtrl.text.trim();
    final payment = _normalizedPaymentMethod(paymentMethod);

    final receiptRows = await client.from('print_receipts').upsert(
      {
        'owner_id': ownerId,
        'receipt_no': serialForLog,
        'payor': payor,
        'payment_method': payment,
        'receipt_date': receiptDate.toIso8601String(),
        'printed_at': now.toIso8601String(),
        'total_amount': total,
      },
      onConflict: 'receipt_no',
    ).select('id');

    final receiptId =
        receiptRows.isNotEmpty ? receiptRows.first['id']?.toString() : null;
    if (receiptId == null || receiptId.isEmpty) {
      throw Exception('Failed to create print_receipts header.');
    }

    final itemRows = <Map<String, dynamic>>[];
    int lineNo = 1;
    for (final item in items) {
      final amount = (item['price'] as num?)?.toDouble() ?? 0.0;
      if (amount <= 0) continue;
      final rawNature = (item['nature'] ?? '').toString();
      final split = _splitNatureAndSubNature(rawNature);
      final resolvedNature = (split['nature'] ?? '').trim();
      if (resolvedNature.isEmpty) continue;
      final rowCategory =
          (item['category'] ?? selectedCategory).toString().trim();
      final rawNatureId = item['nature_id'] ?? item['NatureID'];
      final natureId = rawNatureId is num
          ? rawNatureId.toInt()
          : int.tryParse(rawNatureId?.toString() ?? '');
      final rawSubNatureId = item['sub_nature_id'] ?? item['SubNatureID'];
      final subNatureId = rawSubNatureId is num
          ? rawSubNatureId.toInt()
          : int.tryParse(rawSubNatureId?.toString() ?? '');
      final acctNo = ((item['account_code'] ?? '').toString().trim().isNotEmpty)
          ? (item['account_code'] ?? '').toString().trim()
          : (item['nature_code'] ?? '').toString().trim();

      itemRows.add({
        'receipt_id': receiptId,
        'line_no': lineNo,
        'Category': rowCategory.isEmpty ? selectedCategory : rowCategory,
        'NatureID': natureId,
        'nature': resolvedNature,
        'SubNatureID': subNatureId,
        'SubNature': split['sub_nature'],
        'AcctNo': acctNo.isEmpty ? '-' : acctNo,
        'qty': 1,
        'amount': amount,
      });
      lineNo++;
    }

    if (itemRows.isNotEmpty) {
      await client.from('print_receipt_items').insert(itemRows);
    }
  }

  Future<void> _saveReceipt() async {
    if (isSaving) return;
    final items = _buildCollectionItems();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Maglagay ng kahit isang item ng koleksyon bago mag-save.'),
          backgroundColor: Color(0xFFB3261E),
        ),
      );
      return;
    }

    setState(() => isSaving = true);
    try {
      final now = DateTime.now();
      final safeCategory = selectedCategory.toLowerCase().replaceAll(' ', '_');
      final safeFlow = selectedCategory == 'Marine'
          ? selectedMarineFlow.toLowerCase()
          : 'none';
      final timestamp =
          now.toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
      final fileName = selectedCategory == 'Marine'
          ? 'receipt_${safeCategory}_${safeFlow}_$timestamp.json'
          : 'receipt_${safeCategory}_$timestamp.json';

      final firstNature = (items.first['nature'] ?? '').toString();
      final htmlContent = '''
<h2>Official Receipt</h2>
<p><strong>Category:</strong> $selectedCategory</p>
<p><strong>Marine Flow:</strong> ${selectedCategory == 'Marine' ? selectedMarineFlow : '-'}</p>
<p><strong>Total:</strong> ${total.toStringAsFixed(2)}</p>
<p><strong>Date:</strong> ${dateCtrl.text}</p>
<p><strong>Payor:</strong> ${payorCtrl.text.trim()}</p>
''';

      await Supabase.instance.client.from('receipts').insert({
        'category': selectedCategory,
        'marine_flow': selectedCategory == 'Marine' ? selectedMarineFlow : null,
        'file_name': fileName,
        'html_content': htmlContent,
        'saved_at': now.toIso8601String(),
        'nature_of_collection': firstNature.isEmpty ? null : firstNature,
        'price': total,
        'collection_items': items,
        'officer_signature_path': _officerSignatureImagePath,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nai-save ang resibo sa public.receipts.'),
          backgroundColor: Color(0xFF1E3A5F),
        ),
      );
      _hasPendingUnpersistedData = false;

      // Call the success callback if provided
      if (widget.onSaveSuccess != null) {
        widget.onSaveSuccess!();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hindi na-save ang resibo: $e'),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  Future<void> _showPrintConfirmation() async {
    if (_isPrinting) return;
    final previewItems = _buildCollectionItems().where((e) {
      final amount = (e['price'] as num?)?.toDouble() ?? 0.0;
      return amount > 0;
    }).toList();
    if (previewItems.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item before printing.')),
      );
      return;
    }
    if ((paymentMethod ?? '').trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a payment method first.')),
      );
      return;
    }

    final shouldPrint = await showDialog<bool>(
      context: context,
      builder: (context) {
        return _wrapPopupTextScale(
          context,
          AlertDialog(
            title: const Text('Provisional Receipt Summary'),
            content: SizedBox(
              width: 300,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 460),
                child: SingleChildScrollView(
                  child: Center(
                    child: SizedBox(
                      width: 220,
                      child: _buildThermalSummaryPreview(previewItems),
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.print),
                label: const Text('Print'),
              ),
            ],
          ),
        );
      },
    );

    if (shouldPrint != true || !mounted) return;
    await _printReceipt();
  }

  Widget _buildThermalSummaryPreview(List<Map<String, dynamic>> items) {
    final serial =
        serialCtrl.text.trim().isEmpty ? '-' : serialCtrl.text.trim();
    final date = dateCtrl.text.trim().isEmpty ? '-' : dateCtrl.text.trim();
    final payor = payorCtrl.text.trim();
    final isCash = paymentMethod == 'cash';
    final isCheck = paymentMethod == 'check';
    final isMoneyOrder = paymentMethod == 'money';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(10),
      child: DefaultTextStyle(
        style: const TextStyle(
          fontSize: 11,
          color: Colors.black,
          fontFamily: 'Courier',
          height: 1.25,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: SizedBox(
                height: 36,
                child: _LogoAsset(path: 'assets/logo.png'),
              ),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text(
                'CTO CATBALOGAN',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Center(
              child: Text(
                'PROVISIONAL RECEIPT',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Text('No: $serial'),
            Text('Date: $date'),
            if (payor.isNotEmpty) Text('Payor: $payor'),
            const SizedBox(height: 2),
            const Text('Payment:'),
            Row(
              children: [
                _paymentCheckIcon(isCash),
                const SizedBox(width: 4),
                const Text('Cash'),
                const SizedBox(width: 10),
                _paymentCheckIcon(isCheck),
                const SizedBox(width: 4),
                const Text('Check'),
              ],
            ),
            Row(
              children: [
                _paymentCheckIcon(isMoneyOrder),
                const SizedBox(width: 4),
                const Text('Money Order'),
              ],
            ),
            const Divider(height: 14),
            ...items.map((row) {
              final nature = (row['nature'] ?? '').toString().trim();
              final amount = (row['price'] as num?)?.toDouble() ?? 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(nature.isEmpty ? '-' : nature)),
                    const SizedBox(width: 8),
                    Text(amount.toStringAsFixed(2)),
                  ],
                ),
              );
            }),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('-'),
              ),
            const Divider(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  total.toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printReceipt() async {
    if (_isPrinting) return;
    if ((paymentMethod ?? '').trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a payment method first.')),
        );
      }
      return;
    }
    setState(() => _isPrinting = true);
    try {
      final items = _buildCollectionItems();
      final now = DateTime.now();
      final fallbackCurrentSerial = int.tryParse(serialCtrl.text.trim()) ?? 1;

      int? assignedSerial;
      try {
        assignedSerial = await UserSettingsService.consumeMySerialNo();
      } catch (e) {
        final errorText = e.toString().toLowerCase();
        final isSerialRangeError = errorText.contains('serial range') ||
            errorText.contains('no serial range assigned');
        if (isSerialRangeError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Cannot print: $e')),
            );
          }
          return;
        }
      }

      final currentSerial = assignedSerial ?? fallbackCurrentSerial;
      final serialForLog = currentSerial.toString();
      if (serialCtrl.text.trim() != serialForLog) {
        serialCtrl.text = serialForLog;
      }

      final pdf = pw.Document();
      pw.MemoryImage? thermalLogo;
      try {
        final logoData = await rootBundle.load('assets/logo.png');
        thermalLogo = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (_) {
        thermalLogo = null;
      }
      final itemRows = items.where((e) {
        final amount = (e['price'] as num?)?.toDouble() ?? 0.0;
        return amount > 0;
      }).toList();

      // Compact thermal roll sizing for 58mm printer paper.
      final pageHeightMm =
          (70 + (itemRows.length * 6.5)).clamp(90, 220).toDouble();
      final thermalFormat = PdfPageFormat(
        58 * PdfPageFormat.mm,
        pageHeightMm * PdfPageFormat.mm,
        marginLeft: 1.2 * PdfPageFormat.mm,
        marginRight: 1.2 * PdfPageFormat.mm,
        marginTop: 1.2 * PdfPageFormat.mm,
        marginBottom: 1.2 * PdfPageFormat.mm,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: thermalFormat,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (thermalLogo != null)
                  pw.Center(
                    child: pw.SizedBox(
                      height: 16,
                      child: pw.Image(thermalLogo, fit: pw.BoxFit.contain),
                    ),
                  ),
                if (thermalLogo != null) pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    'CTO CATBALOGAN',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'PROVISIONAL RECEIPT',
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text('No: $serialForLog',
                    style: const pw.TextStyle(fontSize: 7)),
                pw.Text('Date: ${dateCtrl.text.trim()}',
                    style: const pw.TextStyle(fontSize: 7)),
                if (payorCtrl.text.trim().isNotEmpty)
                  pw.Text('Payor: ${payorCtrl.text.trim()}',
                      style: const pw.TextStyle(fontSize: 7)),
                pw.SizedBox(height: 1),
                pw.Text(
                  'Payment:',
                  style: const pw.TextStyle(fontSize: 7),
                ),
                pw.Text(
                  '${paymentMethod == 'cash' ? '[x]' : '[ ]'} Cash  '
                  '${paymentMethod == 'check' ? '[x]' : '[ ]'} Check',
                  style: const pw.TextStyle(fontSize: 7),
                ),
                pw.Text(
                  '${paymentMethod == 'money' ? '[x]' : '[ ]'} Money Order',
                  style: const pw.TextStyle(fontSize: 7),
                ),
                pw.Divider(thickness: 0.6),
                ...itemRows.map((row) {
                  final nature = (row['nature'] ?? '').toString().trim();
                  final amount = (row['price'] as num?)?.toDouble() ?? 0.0;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            nature.isEmpty ? '-' : nature,
                            style: const pw.TextStyle(fontSize: 7),
                          ),
                        ),
                        pw.SizedBox(width: 4),
                        pw.Text(
                          amount.toStringAsFixed(2),
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                      ],
                    ),
                  );
                }),
                pw.Divider(thickness: 0.6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      total.toStringAsFixed(2),
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Center(
                  child: pw.Text(
                    'Thank you',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ),
              ],
            );
          },
        ),
      );

      try {
        await Printing.layoutPdf(onLayout: (format) async => pdf.save());
      } on MissingPluginException {
        final bytes = await pdf.save();
        final tempDir = Directory.systemTemp;
        final filePath =
            '${tempDir.path}\\receipt_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File(filePath);
        await file.writeAsBytes(bytes, flush: true);

        if (Platform.isWindows) {
          await Process.start(
            'cmd',
            ['/c', 'start', '', filePath],
            runInShell: true,
          );
        } else {
          rethrow;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Print plugin unavailable. Opened PDF for manual print: $filePath',
              ),
            ),
          );
        }
      }

      final natureCodes = <String>{};
      for (final item in items) {
        final code = (item['nature_code'] ?? '').toString().trim();
        if (code.isNotEmpty) {
          natureCodes.add(code);
        }
      }
      final combinedNatureCodes =
          natureCodes.isEmpty ? null : natureCodes.join(',');

      final printLogPayload = <String, dynamic>{
        'printed_at': now.toIso8601String(),
        'category': selectedCategory,
        'marine_flow': selectedCategory == 'Marine' ? selectedMarineFlow : null,
        'serial_no': serialForLog,
        'receipt_date': dateCtrl.text.trim(),
        'payor': payorCtrl.text.trim().isEmpty ? null : payorCtrl.text.trim(),
        'total_amount': total,
        'collection_items': items,
        'nature_code': combinedNatureCodes,
        'payment_method': paymentMethod,
      };

      String? syncWarning;
      try {
        await _insertNormalizedPrintReceipt(
          serialForLog: serialForLog,
          now: now,
          items: items,
        );
        // Also flush any old queued logs when connection is available.
        await OfflineReceiptStorageService.syncPending();
      } catch (e) {
        syncWarning = e.toString();
        debugPrint('Print receipt DB sync failed, queued offline: $e');
        await OfflineReceiptStorageService.enqueuePrintLog(printLogPayload);
      }

      await _markPayorPaymentFromPrint();

      int nextSerialNo = currentSerial + 1;
      final serialStatus = await UserSettingsService.fetchMySerialStatus();
      final rangeNext = int.tryParse(
        (serialStatus?['next_serial_no'] ?? '').toString(),
      );
      if (rangeNext != null) {
        nextSerialNo = rangeNext > nextSerialNo ? rangeNext : nextSerialNo;
      }
      await UserSettingsService.setNextSerialNo(nextSerialNo);

      if (!mounted) return;
      setState(() {
        serialCtrl.text = nextSerialNo.toString();
      });
      _hasPendingUnpersistedData = false;
      _resetReceiptForNewEntry();
      final message = syncWarning == null
          ? 'Receipt printed and saved to database.'
          : 'Receipt printed. Saved offline queue (DB sync failed: $syncWarning)';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print/process failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  void _resetReceiptForNewEntry() {
    if (!mounted) return;
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final yy = (now.year % 100).toString().padLeft(2, '0');

    setState(() {
      _categoryDrafts.clear();
      dateCtrl.text = '$mm/$dd/$yy';
      agencyCtrl.text = _fixedAgencyName;
      fundCtrl.clear();
      payorCtrl.clear();
      paymentMethod = null;

      for (int i = 0; i < rowCount; i++) {
        natures[i] = null;
        _natureStartDates[i] = null;
        _rowNatureIds[i] = null;
        _rowSubNatureIds[i] = null;
        accountCtrls[i].clear();
        amountCtrls[i].clear();
      }
      _ensurePenaltyNature();
      total = 0.0;
      words = '';
    });

    // Re-apply defaults such as officer/signature from settings.
    _loadUserSettings();
  }

  Future<Uint8List> _captureReceiptPngBytes() async {
    final boundary = _receiptCaptureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('Receipt preview is not ready yet.');
    }
    final image = await boundary.toImage(pixelRatio: 2.5);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to capture receipt image.');
    }
    return byteData.buffer.asUint8List();
  }

  Widget _paymentCheckIcon(bool checked) {
    return Icon(
      checked ? Icons.check_box : Icons.check_box_outline_blank,
      size: 14,
      color: Colors.black,
    );
  }

  Widget _buildReceiptControls() {
    if (widget.readOnly) {
      return const SizedBox.shrink();
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: col0 + col * 3 + 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 1),
          color: const Color(0xFFF7F9FC),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final categoryFontSize = constraints.maxWidth < 420 ? 13.0 : 14.0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_availableCategories.isNotEmpty &&
                    _resolvedCategoryValue() == null &&
                    selectedCategory.trim().isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Previous category is no longer available. Please select a category.',
                      style: TextStyle(color: Color(0xFFB3261E), fontSize: 12),
                    ),
                  ),
                Row(
                  children: [
                    const Text(
                      'Category',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PopupMenuButton<String>(
                        tooltip: 'Select category',
                        enabled: _availableCategories.isNotEmpty,
                        onSelected: (value) {
                          _saveDraftForCurrentCategory();
                          setState(() {
                            selectedCategory = value;
                            _activeNatureForSubNature = null;
                            _availableSubNatures = <Map<String, dynamic>>[];
                            _subNatureLoadError = null;
                          });
                          _restoreDraftForCategory(value);
                          _loadAvailableNatures();
                        },
                        itemBuilder: (context) => _availableCategories
                            .map(
                              (category) => PopupMenuItem<String>(
                                value: category,
                                child: Text(
                                  category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF9EA7B5)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (_resolvedCategoryValue() ?? selectedCategory)
                                          .trim()
                                          .isEmpty
                                      ? 'Select category'
                                      : (_resolvedCategoryValue() ??
                                          selectedCategory),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: categoryFontSize,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_drop_down,
                                color: _availableCategories.isEmpty
                                    ? Colors.grey
                                    : Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_dueTodayCount > 0 || _overdueCount > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFD),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD8E1EF)),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Payment Alerts',
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_dueTodayCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text('Due Today: $_dueTodayCount'),
                          ),
                        if (_overdueCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text('Overdue: $_overdueCount'),
                          ),
                      ],
                    ),
                  ),
                ],
                if (widget.showViewReceiptsButton ||
                    widget.showSaveButton ||
                    widget.showPrintButton) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (widget.showViewReceiptsButton)
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ReceiptViewScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.list),
                          label: const Text('Tingnan ang mga Resibo'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1E3A5F),
                            side: const BorderSide(color: Color(0xFF1E3A5F)),
                          ),
                        ),
                      if (widget.showSaveButton)
                        FilledButton.icon(
                          onPressed: isSaving ? null : _saveReceipt,
                          icon: isSaving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save),
                          label: Text(isSaving
                              ? 'Nagse-save...'
                              : 'I-save sa mga resibo'),
                        ),
                      if (widget.showPrintButton)
                        OutlinedButton.icon(
                          key: _itemButtonKey,
                          onPressed: _showCartItemsDialog,
                          icon: const Icon(Icons.inventory_2_outlined),
                          label: Text('Item (${_cartRowIndexes().length})'),
                        ),
                      if (widget.showPrintButton)
                        OutlinedButton.icon(
                          onPressed: _showPrintConfirmation,
                          icon: const Icon(Icons.print),
                          label: const Text('View Summary'),
                        ),
                    ],
                  ),
                ],
                if (selectedCategory == 'Marine') ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Incoming'),
                        selected: selectedMarineFlow == 'Incoming',
                        onSelected: (_) {
                          setState(() {
                            selectedMarineFlow = 'Incoming';
                            _activeNatureForSubNature = null;
                            _availableSubNatures = <Map<String, dynamic>>[];
                            _subNatureLoadError = null;
                          });
                          _loadAvailableNatures();
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Outgoing'),
                        selected: selectedMarineFlow == 'Outgoing',
                        onSelected: (_) {
                          setState(() {
                            selectedMarineFlow = 'Outgoing';
                            _activeNatureForSubNature = null;
                            _availableSubNatures = <Map<String, dynamic>>[];
                            _subNatureLoadError = null;
                          });
                          _loadAvailableNatures();
                        },
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<double?> _showAmountPopup() async {
    final amountController = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (BuildContext context) {
        return _wrapPopupTextScale(
          context,
          AlertDialog(
            title: const Text('Enter Amount'),
            content: TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: '0.00',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final amount = double.tryParse(amountController.text.trim());
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Please enter a valid amount greater than 0'),
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).pop(amount);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }

  bool get _isSimpleUserEntryMode =>
      !widget.readOnly &&
      widget.showPrintButton &&
      !widget.showSaveButton &&
      !widget.showViewReceiptsButton;

  Future<void> _pickReceiptDate() async {
    DateTime initial = DateTime.now();
    final parts = dateCtrl.text.trim().split('/');
    if (parts.length == 3) {
      final mm = int.tryParse(parts[0]);
      final dd = int.tryParse(parts[1]);
      final yy = int.tryParse(parts[2]);
      if (mm != null && dd != null && yy != null) {
        final yyyy = yy < 100 ? 2000 + yy : yy;
        initial = DateTime(yyyy, mm, dd);
      }
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return _wrapPopupTextScale(
          context,
          child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      final mm = picked.month.toString().padLeft(2, '0');
      final dd = picked.day.toString().padLeft(2, '0');
      final yy = (picked.year % 100).toString().padLeft(2, '0');
      dateCtrl.text = '$mm/$dd/$yy';
    });
  }

  List<int> _cartRowIndexes() {
    final rows = <int>[];
    for (int i = 0; i < rowCount - 1; i++) {
      final hasNature = (natures[i] ?? '').trim().isNotEmpty;
      final hasAmount = amountCtrls[i].text.trim().isNotEmpty;
      if (hasNature || hasAmount) {
        rows.add(i);
      }
    }
    return rows;
  }

  int? _nextCartSlot() {
    for (int i = 0; i < rowCount - 1; i++) {
      if (_isStartDateDisplayRow(i)) {
        continue;
      }
      final hasNature = (natures[i] ?? '').trim().isNotEmpty;
      final hasAmount = amountCtrls[i].text.trim().isNotEmpty;
      if (!hasNature && !hasAmount) {
        return i;
      }
    }
    return null;
  }

  Future<void> _addNatureToCart() async {
    final beforeCount = _cartRowIndexes().length;
    final slot = _nextCartSlot();
    if (slot == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum line items reached.')),
      );
      return;
    }
    await _handleNatureSelection(slot);
    if (!mounted) return;
    final afterCount = _cartRowIndexes().length;
    if (afterCount > beforeCount) {
      _playAddToItemAnimation();
    }
  }

  Future<void> _addNatureFromList(Map<String, dynamic> selected) async {
    final rawNatureId = selected['nature_id'];
    final natureId = rawNatureId is num
        ? rawNatureId.toInt()
        : int.tryParse(rawNatureId?.toString() ?? '');
    final hasInlineSubNature =
        ((selected['sub_nature'] ?? '').toString().trim()).isNotEmpty;

    if (natureId != null && !hasInlineSubNature) {
      await _showSubNaturesInContainer(selected, natureId);
      return;
    }

    final beforeCount = _cartRowIndexes().length;
    final slot = _nextCartSlot();
    if (slot == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum line items reached.')),
      );
      return;
    }

    final applied = await _applySelectedNatureToRow(slot, selected);
    if (!mounted || !applied) return;
    final afterCount = _cartRowIndexes().length;
    if (afterCount > beforeCount) {
      _playAddToItemAnimation();
    }
  }

  Future<void> _showSubNaturesInContainer(
    Map<String, dynamic> selectedNature,
    int natureId,
  ) async {
    if (!mounted) return;
    setState(() {
      _activeNatureForSubNature = selectedNature;
      _isLoadingSubNatures = true;
      _subNatureLoadError = null;
      _availableSubNatures = <Map<String, dynamic>>[];
      _natureQuickSearch = '';
    });

    try {
      final data = await _fetchSubNaturesForNature(natureId);
      if (!mounted) return;
      setState(() {
        _availableSubNatures = data;
        _isLoadingSubNatures = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _availableSubNatures = <Map<String, dynamic>>[];
        _isLoadingSubNatures = false;
        _subNatureLoadError = e.toString();
      });
    }
  }

  void _exitSubNatureMode() {
    if (!mounted) return;
    setState(() {
      _activeNatureForSubNature = null;
      _availableSubNatures = <Map<String, dynamic>>[];
      _subNatureLoadError = null;
      _isLoadingSubNatures = false;
      _natureQuickSearch = '';
    });
  }

  Future<void> _addSubNatureFromList(Map<String, dynamic> subNature) async {
    final baseNature = _activeNatureForSubNature;
    if (baseNature == null) return;
    final merged = <String, dynamic>{
      ...baseNature,
      'sub_nature': subNature['SubNature'],
      'sub_acct_no': subNature['AcctNo'],
      'sub_nature_id': subNature['SubNatureID'],
    };
    await _addNatureFromList(merged);
    if (mounted) {
      _exitSubNatureMode();
    }
  }

  void _playAddToItemAnimation() {
    final addContext = _addButtonKey.currentContext;
    final itemContext = _itemButtonKey.currentContext;
    if (addContext == null || itemContext == null || !mounted) return;

    final addBox = addContext.findRenderObject() as RenderBox?;
    final itemBox = itemContext.findRenderObject() as RenderBox?;
    if (addBox == null || itemBox == null) return;
    if (!addBox.attached || !itemBox.attached) return;

    final overlay = Overlay.of(context, rootOverlay: true);

    final start = addBox.localToGlobal(addBox.size.center(Offset.zero));
    final end = itemBox.localToGlobal(itemBox.size.center(Offset.zero));

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeInOutCubic,
          onEnd: () => entry.remove(),
          builder: (context, t, child) {
            final x = ui.lerpDouble(start.dx, end.dx, t) ?? end.dx;
            final yBase = ui.lerpDouble(start.dy, end.dy, t) ?? end.dy;
            final arc = (1 - (2 * t - 1).abs()) * 28;
            final y = yBase - arc;

            return Stack(
              children: [
                Positioned(
                  left: x - 14,
                  top: y - 14,
                  child: Opacity(opacity: 1 - (t * 0.15), child: child),
                ),
              ],
            );
          },
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 16,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
  }

  void _removeCartRow(int index) {
    setState(() {
      natures[index] = null;
      _natureStartDates[index] = null;
      _rowNatureIds[index] = null;
      _rowSubNatureIds[index] = null;
      accountCtrls[index].clear();
      amountCtrls[index].clear();
    });
    _saveDraftForCurrentCategory();
    _recalculate();
  }

  Future<void> _showCartItemsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final rows = _cartRowIndexes();
          return AlertDialog(
            title: const Text('Cart Items'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  rows.isEmpty
                      ? const Text('No items added yet.')
                      : ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 360),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: rows.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 12),
                            itemBuilder: (context, i) {
                              final rowIndex = rows[i];
                              final nature = (natures[rowIndex] ?? '').trim();
                              final amount = double.tryParse(
                                    amountCtrls[rowIndex].text.trim(),
                                  ) ??
                                  0.0;
                              final line2 = _natureLine2(rowIndex);
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nature.isEmpty ? '-' : nature,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (line2 != null && line2.isNotEmpty)
                                          Text(
                                            line2,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'P ${amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Remove',
                                    onPressed: () {
                                      _removeCartRow(rowIndex);
                                      setDialogState(() {});
                                    },
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Total: P ${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSimpleUserFormContent() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 780),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          final compact = maxW < 520;
          const tileRows = 2;
          const tileColumns = 3;
          final tileHeight = compact ? 220.0 : 260.0;
          final panelPadding = compact ? 10.0 : 12.0;
          final tileRadius = compact ? 12.0 : 16.0;
          final showingSubNature = _activeNatureForSubNature != null;
          final selectionItems =
              showingSubNature ? _availableSubNatures : availableNatures;
          final totalNatureCount = availableNatures.length;
          final totalSubNatureCount = _availableSubNatures.length;
          final searchQuery = _natureQuickSearch.trim().toLowerCase();
          final filteredSelectionItems = searchQuery.isEmpty
              ? selectionItems
              : selectionItems.where((item) {
                  final label = (showingSubNature
                          ? item['SubNature']
                          : item['nature_of_collection'])
                      .toString()
                      .toLowerCase();
                  final code =
                      (showingSubNature ? item['AcctNo'] : item['nature_code'])
                          .toString()
                          .toLowerCase();
                  return label.contains(searchQuery) ||
                      code.contains(searchQuery);
                }).toList();

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(compact ? 8 : 10),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD6DBE6)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Autocomplete<_ManagedPayor>(
                        optionsBuilder: (textEditingValue) {
                          final query =
                              textEditingValue.text.trim().toLowerCase();
                          final source =
                              List<_ManagedPayor>.from(_managedPayors);
                          if (query.isEmpty) return source.take(8);
                          return source
                              .where(
                                (p) => p.fullName.toLowerCase().contains(query),
                              )
                              .take(12);
                        },
                        displayStringForOption: (option) => option.fullName,
                        onSelected: (option) {
                          setState(() {
                            payorCtrl.text = option.fullName;
                          });
                        },
                        fieldViewBuilder:
                            (context, textController, focusNode, onSubmitted) {
                          if (payorCtrl.text.trim().isNotEmpty &&
                              textController.text != payorCtrl.text) {
                            textController.text = payorCtrl.text;
                          }
                          return TextField(
                            controller: textController,
                            focusNode: focusNode,
                            onChanged: (v) => payorCtrl.text = v,
                            decoration: const InputDecoration(
                              labelText: 'Payor (search/dropdown)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          );
                        },
                      ),
                    ),
                    if (_allowManagePayorAccess) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _openManagePayorOverlay,
                        icon: const Icon(Icons.manage_accounts),
                        label: const Text('Manage Payor'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                key: _addButtonKey,
                width: double.infinity,
                padding: EdgeInsets.all(panelPadding),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _categoryThemeColor(selectedCategory)
                        .withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                ),
                child: selectionItems.isEmpty
                    ? ((showingSubNature
                            ? _isLoadingSubNatures
                            : _isLoadingNatures)
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                showingSubNature
                                    ? ((_subNatureLoadError == null)
                                        ? 'No subnature found'
                                        : 'Failed to load subnature')
                                    : ((_naturesLoadError == null)
                                        ? 'No nature found for category: $selectedCategory'
                                        : 'Failed to load natures'),
                                style: const TextStyle(fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () {
                                  if (showingSubNature &&
                                      _activeNatureForSubNature != null) {
                                    final rawId =
                                        _activeNatureForSubNature!['nature_id'];
                                    final natureId = rawId is num
                                        ? rawId.toInt()
                                        : int.tryParse(rawId?.toString() ?? '');
                                    if (natureId != null) {
                                      _showSubNaturesInContainer(
                                        _activeNatureForSubNature!,
                                        natureId,
                                      );
                                    }
                                  } else {
                                    _loadAvailableNatures();
                                  }
                                },
                                icon: const Icon(Icons.refresh),
                                label: Text(showingSubNature
                                    ? 'Reload subnature list'
                                    : 'Reload nature list'),
                              ),
                              if (showingSubNature)
                                TextButton.icon(
                                  onPressed: _exitSubNatureMode,
                                  icon: const Icon(Icons.arrow_back),
                                  label: const Text('Back to nature'),
                                ),
                            ],
                          ))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE9F3FF),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0xFF9FC4F8),
                                  ),
                                ),
                                child: Text(
                                  'Nature: $totalNatureCount',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E3A5F),
                                  ),
                                ),
                              ),
                              if (showingSubNature)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAFBF2),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: const Color(0xFFA8DEBF),
                                    ),
                                  ),
                                  child: Text(
                                    'Subnature: $totalSubNatureCount',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF175A34),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (showingSubNature)
                            Row(
                              children: [
                                IconButton(
                                  onPressed: _exitSubNatureMode,
                                  icon: const Icon(Icons.arrow_back),
                                  tooltip: 'Back to nature',
                                  visualDensity: VisualDensity.compact,
                                ),
                                Expanded(
                                  child: Text(
                                    'Subnature of ${(_activeNatureForSubNature?['nature_of_collection'] ?? '').toString()}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color:
                                          Colors.black.withValues(alpha: 0.75),
                                      fontSize: compact ? 11 : 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            const SizedBox.shrink(),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  onChanged: (value) {
                                    setState(() {
                                      _natureQuickSearch = value;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    hintText: showingSubNature
                                        ? 'Search subnature...'
                                        : 'Search nature...',
                                    prefixIcon:
                                        const Icon(Icons.search, size: 18),
                                    suffixIcon:
                                        _natureQuickSearch.trim().isEmpty
                                            ? null
                                            : IconButton(
                                                onPressed: () {
                                                  setState(() {
                                                    _natureQuickSearch = '';
                                                  });
                                                },
                                                icon: const Icon(Icons.close,
                                                    size: 18),
                                                tooltip: 'Clear search',
                                              ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: compact ? 132 : 168,
                                child: DropdownButtonFormField<String>(
                                  value: (paymentMethod == 'cash' ||
                                          paymentMethod == 'check' ||
                                          paymentMethod == 'money')
                                      ? paymentMethod
                                      : null,
                                  isDense: true,
                                  decoration: InputDecoration(
                                    labelText: 'Payment',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'cash',
                                      child: Text('Cash'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'check',
                                      child: Text('Check'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'money',
                                      child: Text('Money'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      paymentMethod = value;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: tileHeight,
                            child: LayoutBuilder(
                              builder: (context, gridConstraints) {
                                final spacing = compact ? 8.0 : 10.0;
                                final tileMainExtent =
                                    ((gridConstraints.maxWidth -
                                                (spacing * (tileColumns - 1))) /
                                            tileColumns)
                                        .clamp(96.0, 220.0);
                                if (filteredSelectionItems.isEmpty) {
                                  return Center(
                                    child: Text(
                                      showingSubNature
                                          ? 'No matching subnature found.'
                                          : 'No matching nature found.',
                                      style: TextStyle(
                                        fontSize: compact ? 11 : 12,
                                        color:
                                            Colors.black.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  );
                                }
                                return GridView.builder(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: filteredSelectionItems.length,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: tileRows,
                                    crossAxisSpacing: spacing,
                                    mainAxisSpacing: spacing,
                                    mainAxisExtent: tileMainExtent,
                                  ),
                                  itemBuilder: (context, index) {
                                    final themeColor =
                                        _categoryThemeColor(selectedCategory);
                                    final item = filteredSelectionItems[index];
                                    final label = (showingSubNature
                                            ? item['SubNature']
                                            : item['nature_of_collection'])
                                        .toString()
                                        .trim();
                                    if (label.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius:
                                            BorderRadius.circular(tileRadius),
                                        overlayColor: WidgetStateProperty
                                            .resolveWith<Color?>(
                                          (states) {
                                            if (states.contains(
                                                WidgetState.pressed)) {
                                              return themeColor.withValues(
                                                  alpha: 0.35);
                                            }
                                            return null;
                                          },
                                        ),
                                        splashColor:
                                            themeColor.withValues(alpha: 0.26),
                                        highlightColor:
                                            themeColor.withValues(alpha: 0.22),
                                        onTap: () => showingSubNature
                                            ? _addSubNatureFromList(item)
                                            : _addNatureFromList(item),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(tileRadius),
                                          child: BackdropFilter(
                                            filter: ui.ImageFilter.blur(
                                              sigmaX: 8,
                                              sigmaY: 8,
                                            ),
                                            child: Ink(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        tileRadius),
                                                color: Colors.white.withValues(
                                                  alpha: 0.96,
                                                ),
                                                border: Border.all(
                                                  color: themeColor.withValues(
                                                      alpha: 0.35),
                                                  width: 1.5,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color:
                                                        Colors.black.withValues(
                                                      alpha: 0.08,
                                                    ),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 3),
                                                  ),
                                                ],
                                              ),
                                              child: Padding(
                                                padding: EdgeInsets.fromLTRB(
                                                  compact ? 8 : 10,
                                                  compact ? 7 : 9,
                                                  compact ? 8 : 10,
                                                  compact ? 7 : 9,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 7,
                                                        vertical: 3,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: themeColor
                                                            .withValues(
                                                          alpha: 0.20,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(999),
                                                      ),
                                                      child: Icon(
                                                        Icons.auto_awesome,
                                                        size: compact ? 11 : 12,
                                                        color: themeColor
                                                            .withValues(
                                                          alpha: 0.90,
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                        height:
                                                            compact ? 5 : 7),
                                                    Expanded(
                                                      child: Center(
                                                        child: Text(
                                                          label,
                                                          textAlign:
                                                              TextAlign.center,
                                                          maxLines:
                                                              compact ? 4 : 6,
                                                          softWrap: true,
                                                          style: TextStyle(
                                                            color: const Color(
                                                                0xFF1A1D23),
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: compact
                                                                ? 13
                                                                : 14,
                                                            height: 1.2,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const contentWidth = col0 + (col * 3) + 4;

    return Scaffold(
      appBar: widget.readOnly
          ? AppBar(
              title: const Text('Receipt Preview'),
              backgroundColor: _categoryThemeColor(selectedCategory),
            )
          : null,
      floatingActionButton: null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      backgroundColor: widget.readOnly
          ? _categoryThemeColor(selectedCategory).withValues(alpha: 0.10)
          : const Color(0xFFE8EAED),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          final maxH = constraints.maxHeight;
          final safeW = (maxW - 24).clamp(280.0, 2400.0);
          final pad = safeW < 520 ? 12.0 : 20.0;
          final effectiveW = (maxW - 24).clamp(280.0, 2400.0);
          final effectiveH = (maxH - 24).clamp(420.0, 2400.0);

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: Container(
                width: effectiveW,
                height: effectiveH,
                padding: EdgeInsets.all(pad),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Scrollbar(
                  controller: _verticalScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _verticalScrollController,
                    primary: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildReceiptControls(),
                        const SizedBox(height: 8),
                        if (_isSimpleUserEntryMode)
                          _buildSimpleUserFormContent()
                        else
                          LayoutBuilder(
                            builder: (context, tableConstraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Center(
                                  child: RepaintBoundary(
                                    key: _receiptCaptureKey,
                                    child: Container(
                                      width: contentWidth,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.black,
                                          width: 2,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            children: [
                                              _cell(
                                                width: col0,
                                                height: headerRowHeight +
                                                    topRowHeight * 2,
                                                thick: true,
                                                child: const Center(
                                                  child: SizedBox(
                                                    width: 100,
                                                    child: _Logo(),
                                                  ),
                                                ),
                                              ),
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _cell(
                                                    width: col * 3,
                                                    height: headerRowHeight,
                                                    thick: true,
                                                    alignment: Alignment.center,
                                                    child: _headerCell(
                                                      'Official Receipt\nof the\nRepublic of the Philippines',
                                                    ),
                                                  ),
                                                  _cell(
                                                    width: col * 3,
                                                    height: topRowHeight,
                                                    thick: true,
                                                    child: Row(
                                                      children: [
                                                        const Text('No. '),
                                                        Expanded(
                                                          child: TextField(
                                                            controller:
                                                                serialCtrl,
                                                            readOnly:
                                                                widget.readOnly,
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                            decoration:
                                                                const InputDecoration(
                                                              border:
                                                                  InputBorder
                                                                      .none,
                                                              isDense: true,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  _cell(
                                                    width: col * 3,
                                                    height: topRowHeight,
                                                    thick: true,
                                                    child: Row(
                                                      children: [
                                                        const Text('Date'),
                                                        const SizedBox(
                                                            width: 8),
                                                        SizedBox(
                                                          width: 100,
                                                          child: TextField(
                                                            controller:
                                                                dateCtrl,
                                                            readOnly:
                                                                widget.readOnly,
                                                            decoration:
                                                                const InputDecoration(
                                                              border:
                                                                  InputBorder
                                                                      .none,
                                                              isDense: true,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              _cell(
                                                width: col0 + col * 3,
                                                child: Row(
                                                  children: [
                                                    const Text('Agency'),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: TextField(
                                                        controller: agencyCtrl,
                                                        readOnly: true,
                                                        decoration:
                                                            const InputDecoration(
                                                          border:
                                                              InputBorder.none,
                                                          isDense: true,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              _cell(
                                                width: col0 + col * 3,
                                                doubleBottom: true,
                                                child: Row(
                                                  children: [
                                                    const Text('Payor'),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: TextField(
                                                        controller: payorCtrl,
                                                        readOnly:
                                                            widget.readOnly,
                                                        decoration:
                                                            const InputDecoration(
                                                          border:
                                                              InputBorder.none,
                                                          isDense: true,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              _cell(
                                                width: col0 + col,
                                                padding: EdgeInsets.zero,
                                                alignment: Alignment.center,
                                                child: const Text(
                                                  'Nature of\nCollection',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                      fontSize: 11, height: 1),
                                                ),
                                              ),
                                              _cell(
                                                width: col,
                                                padding: EdgeInsets.zero,
                                                alignment: Alignment.center,
                                                child: const Text(
                                                  'Account\nCode',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                      fontSize: 11, height: 1),
                                                ),
                                              ),
                                              _cell(
                                                width: col,
                                                padding: EdgeInsets.zero,
                                                alignment: Alignment.center,
                                                child: const SizedBox(
                                                  height: 22,
                                                  child: Center(
                                                    child: Text(
                                                      'Amount',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        height: 1,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          for (int i = 0; i < rowCount; i++)
                                            Row(
                                              children: [
                                                _cell(
                                                  width: col0 + col,
                                                  height: collectionRowHeight,
                                                  child: _natureDropdown(
                                                      i, collectionRowHeight),
                                                ),
                                                _cell(
                                                  width: col,
                                                  height: collectionRowHeight,
                                                  alignment: Alignment.center,
                                                  child:
                                                      const SizedBox.shrink(),
                                                ),
                                                _cell(
                                                  width: col,
                                                  height: collectionRowHeight,
                                                  alignment: Alignment.center,
                                                  child: _amountField(
                                                      amountCtrls[i]),
                                                ),
                                              ],
                                            ),
                                          Row(
                                            children: [
                                              _cell(
                                                width: col0 + col * 2,
                                                doubleBottom: true,
                                                alignment: Alignment.center,
                                                child: const Text(
                                                  'TOTAL',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 18),
                                                ),
                                              ),
                                              _cell(
                                                width: col,
                                                doubleBottom: true,
                                                alignment:
                                                    Alignment.centerRight,
                                                padding: const EdgeInsets.only(
                                                    right: 5),
                                                child: Text(
                                                  total.toStringAsFixed(2),
                                                  textAlign: TextAlign.right,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 21.9),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              _cell(
                                                width: col0 + col * 3,
                                                noBottom: true,
                                                child: const Text(
                                                    'Amount in Words'),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              _cell(
                                                width: col0 + col * 3,
                                                noTop: true,
                                                child: SizedBox(
                                                  height: 55,
                                                  child: Stack(
                                                    children: [
                                                      CustomPaint(
                                                        size: const Size(
                                                            double.infinity,
                                                            double.infinity),
                                                        painter:
                                                            _LinesPainter(),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 5),
                                                        child: Align(
                                                          alignment:
                                                              Alignment.topLeft,
                                                          child: Text(
                                                            words,
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              height: 1.0,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _cell(
                                                width: col0,
                                                height: paymentHeaderRowHeight +
                                                    paymentBlankRowHeight * 2,
                                                alignment: Alignment.topLeft,
                                                padding: const EdgeInsets.only(
                                                    left: 5, top: 6),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        widget.readOnly
                                                            ? _paymentCheckIcon(
                                                                paymentMethod ==
                                                                    'cash')
                                                            : Transform.scale(
                                                                scale: 0.65,
                                                                child: Checkbox(
                                                                  materialTapTargetSize:
                                                                      MaterialTapTargetSize
                                                                          .shrinkWrap,
                                                                  visualDensity:
                                                                      const VisualDensity(
                                                                    horizontal:
                                                                        -4,
                                                                    vertical:
                                                                        -4,
                                                                  ),
                                                                  value:
                                                                      paymentMethod ==
                                                                          'cash',
                                                                  onChanged:
                                                                      (v) {
                                                                    setState(
                                                                        () {
                                                                      paymentMethod = v ==
                                                                              true
                                                                          ? 'cash'
                                                                          : null;
                                                                    });
                                                                  },
                                                                ),
                                                              ),
                                                        const SizedBox(
                                                            width: 5),
                                                        const Expanded(
                                                          child: Text(
                                                            'Cash',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .normal,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            softWrap: false,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 1),
                                                    Row(
                                                      children: [
                                                        widget.readOnly
                                                            ? _paymentCheckIcon(
                                                                paymentMethod ==
                                                                    'check')
                                                            : Transform.scale(
                                                                scale: 0.65,
                                                                child: Checkbox(
                                                                  materialTapTargetSize:
                                                                      MaterialTapTargetSize
                                                                          .shrinkWrap,
                                                                  visualDensity:
                                                                      const VisualDensity(
                                                                    horizontal:
                                                                        -4,
                                                                    vertical:
                                                                        -4,
                                                                  ),
                                                                  value:
                                                                      paymentMethod ==
                                                                          'check',
                                                                  onChanged:
                                                                      (v) {
                                                                    setState(
                                                                        () {
                                                                      paymentMethod = v ==
                                                                              true
                                                                          ? 'check'
                                                                          : null;
                                                                    });
                                                                  },
                                                                ),
                                                              ),
                                                        const SizedBox(
                                                            width: 5),
                                                        const Expanded(
                                                          child: Text(
                                                            'Check',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .normal,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            softWrap: false,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 1),
                                                    Row(
                                                      children: [
                                                        widget.readOnly
                                                            ? _paymentCheckIcon(
                                                                paymentMethod ==
                                                                    'money')
                                                            : Transform.scale(
                                                                scale: 0.65,
                                                                child: Checkbox(
                                                                  materialTapTargetSize:
                                                                      MaterialTapTargetSize
                                                                          .shrinkWrap,
                                                                  visualDensity:
                                                                      const VisualDensity(
                                                                    horizontal:
                                                                        -4,
                                                                    vertical:
                                                                        -4,
                                                                  ),
                                                                  value:
                                                                      paymentMethod ==
                                                                          'money',
                                                                  onChanged:
                                                                      (v) {
                                                                    setState(
                                                                        () {
                                                                      paymentMethod = v ==
                                                                              true
                                                                          ? 'money'
                                                                          : null;
                                                                    });
                                                                  },
                                                                ),
                                                              ),
                                                        const SizedBox(
                                                            width: 5),
                                                        const Expanded(
                                                          child: Text(
                                                            'Money Order',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .normal,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            softWrap: false,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Row(
                                                    children: [
                                                      _cell(
                                                        width: col,
                                                        height:
                                                            paymentHeaderRowHeight,
                                                        alignment:
                                                            Alignment.center,
                                                        child: const Text(
                                                            'Drawee Bank',
                                                            style: TextStyle(
                                                                fontSize: 11)),
                                                      ),
                                                      _cell(
                                                        width: col,
                                                        height:
                                                            paymentHeaderRowHeight,
                                                        alignment:
                                                            Alignment.center,
                                                        child: const Text(
                                                            'Number',
                                                            style: TextStyle(
                                                                fontSize: 11)),
                                                      ),
                                                      _cell(
                                                        width: col,
                                                        height:
                                                            paymentHeaderRowHeight,
                                                        alignment:
                                                            Alignment.center,
                                                        child: const Text(
                                                            'Date',
                                                            style: TextStyle(
                                                                fontSize: 11)),
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    children: [
                                                      _cell(
                                                        width: col,
                                                        height:
                                                            paymentBlankRowHeight,
                                                        child: const SizedBox
                                                            .shrink(),
                                                      ),
                                                      _cell(
                                                        width: col,
                                                        height:
                                                            paymentBlankRowHeight,
                                                        child: const SizedBox
                                                            .shrink(),
                                                      ),
                                                      _cell(
                                                        width: col,
                                                        height:
                                                            paymentBlankRowHeight,
                                                        child: const SizedBox
                                                            .shrink(),
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    children: [
                                                      _cell(
                                                        width: col,
                                                        height:
                                                            paymentBlankRowHeight,
                                                        noTop: true,
                                                        child: const SizedBox
                                                            .shrink(),
                                                      ),
                                                      _cell(
                                                        width: col,
                                                        height:
                                                            paymentBlankRowHeight,
                                                        child: const SizedBox
                                                            .shrink(),
                                                      ),
                                                      _cell(
                                                        width: col,
                                                        height:
                                                            paymentBlankRowHeight,
                                                        child: const SizedBox
                                                            .shrink(),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              _cell(
                                                width: col0 + col * 3,
                                                height: 125,
                                                alignment: Alignment.topLeft,
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                        5, 5, 5, 5),
                                                child: const Stack(
                                                  children: [
                                                    Align(
                                                      alignment:
                                                          Alignment.topLeft,
                                                      child: Text(
                                                          'Received the amount stated above.'),
                                                    ),
                                                    Align(
                                                      alignment:
                                                          Alignment.bottomRight,
                                                      child: SizedBox.shrink(),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              _cell(
                                                width: col0 + col * 3,
                                                padding:
                                                    const EdgeInsets.all(5),
                                                child: const Text(
                                                  'NOTE: Write the number and date of this receipt on the back of check or money order received.',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontStyle: FontStyle.italic,
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/receipt_logo.png',
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.receipt_long, size: 42, color: Colors.black54);
      },
    );
  }
}

class _LogoAsset extends StatelessWidget {
  const _LogoAsset({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const SizedBox.shrink();
      },
    );
  }
}

class _LinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    const rowGap = 13.0;
    for (double y = rowGap; y < size.height; y += rowGap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum _PayorFrequency {
  oneTime,
  daily,
  weekly,
  every15Days,
  monthly,
  customInterval,
}

extension _PayorFrequencyExt on _PayorFrequency {
  String get label {
    switch (this) {
      case _PayorFrequency.oneTime:
        return 'One-time';
      case _PayorFrequency.daily:
        return 'Daily';
      case _PayorFrequency.weekly:
        return 'Weekly';
      case _PayorFrequency.every15Days:
        return 'Every 15 days';
      case _PayorFrequency.monthly:
        return 'Monthly';
      case _PayorFrequency.customInterval:
        return 'Custom interval';
    }
  }
}

enum _PayorDueStatus { notDueYet, dueToday, overdue }

class _PayorOccurrence {
  _PayorOccurrence({
    required this.dueDate,
    required this.amount,
    this.paidAt,
    this.status = 'expected',
  });

  final DateTime dueDate;
  final double amount;
  DateTime? paidAt;
  String status;

  bool get isPaid => paidAt != null;
}

class _PayorPaymentHistory {
  _PayorPaymentHistory({
    required this.paidAt,
    required this.amount,
    required this.method,
    required this.dueDate,
    required this.note,
  });

  final DateTime paidAt;
  final double amount;
  final String method;
  final DateTime dueDate;
  final String note;
}

class _ManagedPayor {
  _ManagedPayor({
    required this.id,
    required this.scheduleId,
    required this.fullName,
    required this.category,
    required this.nature,
    required this.subNature,
    required this.building,
    required this.stall,
    required this.stallPrice,
    required this.contact,
    required this.notes,
    required this.frequency,
    required this.customIntervalDays,
    required this.startDate,
    required this.defaultAmount,
    required this.createdAt,
    required this.isPaused,
    required this.occurrences,
    required this.paymentHistory,
  });

  String id;
  String? scheduleId;
  final String fullName;
  final String category;
  final String nature;
  final String subNature;
  final String building;
  final String stall;
  final double stallPrice;
  final String contact;
  final String notes;
  final _PayorFrequency frequency;
  final int customIntervalDays;
  final DateTime startDate;
  final double defaultAmount;
  final DateTime createdAt;
  bool isPaused;
  final List<_PayorOccurrence> occurrences;
  final List<_PayorPaymentHistory> paymentHistory;

  Duration _stepDuration() {
    switch (frequency) {
      case _PayorFrequency.oneTime:
        return const Duration(days: 36500);
      case _PayorFrequency.daily:
        return const Duration(days: 1);
      case _PayorFrequency.weekly:
        return const Duration(days: 7);
      case _PayorFrequency.every15Days:
        return const Duration(days: 15);
      case _PayorFrequency.monthly:
        return const Duration(days: 30);
      case _PayorFrequency.customInterval:
        return Duration(
            days: customIntervalDays <= 0 ? 30 : customIntervalDays);
    }
  }

  void ensureScheduleUntil(DateTime limit) {
    if (isPaused) return;
    final endDate = DateTime(limit.year, limit.month, limit.day);
    occurrences.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    if (occurrences.isEmpty) {
      occurrences.add(
        _PayorOccurrence(
          dueDate: DateTime(startDate.year, startDate.month, startDate.day),
          amount: defaultAmount,
        ),
      );
    }
    if (frequency == _PayorFrequency.oneTime) return;
    var cursor = occurrences.last.dueDate;
    final step = _stepDuration();
    while (cursor.isBefore(endDate)) {
      cursor = cursor.add(step);
      occurrences.add(
        _PayorOccurrence(
          dueDate: DateTime(cursor.year, cursor.month, cursor.day),
          amount: defaultAmount,
        ),
      );
      if (occurrences.length > 400) break;
    }
  }

  _PayorOccurrence? firstUnpaidOccurrence() {
    occurrences.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    for (final item in occurrences) {
      if (!item.isPaid) return item;
    }
    return null;
  }

  DateTime? get nextDueDate => firstUnpaidOccurrence()?.dueDate;

  _PayorDueStatus status(DateTime now) {
    final due = nextDueDate;
    if (due == null || isPaused) return _PayorDueStatus.notDueYet;
    final dayNow = DateTime(now.year, now.month, now.day);
    final dayDue = DateTime(due.year, due.month, due.day);
    if (dayDue.isBefore(dayNow)) return _PayorDueStatus.overdue;
    if (DateUtils.isSameDay(dayDue, dayNow)) return _PayorDueStatus.dueToday;
    return _PayorDueStatus.notDueYet;
  }
}

class _CategoryDraft {
  _CategoryDraft({
    required this.natures,
    required this.natureStartDates,
    required this.accountCodes,
    required this.amounts,
    required this.marineFlow,
  });

  final List<String?> natures;
  final List<String?> natureStartDates;
  final List<String> accountCodes;
  final List<String> amounts;
  final String marineFlow;
}
