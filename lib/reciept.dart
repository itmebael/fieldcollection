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
import 'category_constants.dart';
import 'nature_catalog_data.dart';

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
  });

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
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
  List<Map<String, dynamic>> availableNatures = [];
  List<String> _availableCategories = List<String>.from(
    CategoryConstants.categories,
  );
  static const String _penaltyNatureLabel = 'Penalty';
  static const String _amusementTaxNatureLabel = 'amusement tax/';
  static const String _fixedAgencyName = 'CTO CATBALOGAN';
  int _natureLoadVersion = 0;
  bool _isApplyingAutoAmounts = false;
  final ScrollController _verticalScrollController = ScrollController();
  String? _officerSignatureImagePath;
  String? _officerSignatureImageUrl;
  final GlobalKey _receiptCaptureKey = GlobalKey();
  static final Map<String, _CategoryDraft> _categoryDrafts =
      <String, _CategoryDraft>{};

  Color _categoryThemeColor(String category) {
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
    if (!widget.readOnly) {
      _loadAvailableNatures();
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

  String _categoryDraftKey(String category) =>
      category.trim().toLowerCase();

  void _saveDraftForCurrentCategory({bool markUnsaved = true}) {
    final key = _categoryDraftKey(selectedCategory);
    if (key.isEmpty) return;
    _categoryDrafts[key] = _CategoryDraft(
      natures: List<String?>.from(natures),
      natureStartDates: _natureStartDates
          .map((d) => d == null ? null : d.toIso8601String())
          .toList(),
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
        if (officerCtrl.text.trim().isEmpty && defaultOfficer.isNotEmpty) {
          officerCtrl.text = defaultOfficer;
        }
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
    try {
      final normalizedRows = await _fetchAvailableNaturesNow();
      if (!mounted || requestVersion != _natureLoadVersion) return;
      setState(() {
        availableNatures = normalizedRows;
      });
    } catch (e) {
      print('Error loading natures: $e');
      if (!mounted || requestVersion != _natureLoadVersion) return;
      // If table doesn't exist, use default data
      if (e.toString().contains('Could not find the table')) {
        print('DEBUG: Table not found, using default data');
        setState(() {
          availableNatures = _getDefaultNatures();
        });
      } else {
        setState(() {
          availableNatures = [];
        });
      }
    }
  }

  String _normalizeCategoryKey(String value) {
    return value.trim().toLowerCase();
  }

  Future<void> _loadAvailableCategories() async {
    try {
      final client = Supabase.instance.client;
      final natureRows = await client.from('receipt_natures').select('category');
      final receiptRows = await client.from('receipts').select('category');

      final seen = <String>{};
      final categories = <String>[];

      void addCategory(dynamic raw) {
        final value = (raw ?? '').toString().trim();
        if (value.isEmpty) return;
        final key = _normalizeCategoryKey(value);
        if (seen.add(key)) {
          categories.add(value);
        }
      }

      for (final row in List<Map<String, dynamic>>.from(natureRows)) {
        addCategory(row['category']);
      }
      for (final row in List<Map<String, dynamic>>.from(receiptRows)) {
        addCategory(row['category']);
      }

      if (categories.isEmpty) {
        for (final value in NatureCatalogData.categories()) {
          addCategory(value);
        }
      }
      if (categories.isEmpty) {
        for (final value in CategoryConstants.categories) {
          addCategory(value);
        }
      } else {
        categories.sort();
      }

      final selected = selectedCategory.trim();
      if (selected.isNotEmpty &&
          !seen.contains(_normalizeCategoryKey(selected))) {
        categories.insert(0, selected);
      }

      if (!mounted) return;
      setState(() {
        _availableCategories = categories;
      });
    } catch (_) {
      final seen = <String>{};
      final categories = <String>[];
      for (final value in NatureCatalogData.categories()) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) continue;
        if (seen.add(_normalizeCategoryKey(trimmed))) {
          categories.add(trimmed);
        }
      }
      for (final value in CategoryConstants.categories) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) continue;
        if (seen.add(_normalizeCategoryKey(trimmed))) {
          categories.add(trimmed);
        }
      }

      final selected = selectedCategory.trim();
      if (selected.isNotEmpty &&
          !seen.contains(_normalizeCategoryKey(selected))) {
        categories.insert(0, selected);
      }

      if (!mounted) return;
      setState(() {
        _availableCategories = categories;
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
    List<Map<String, dynamic>> localRowsForCategory() {
      final normalize = (dynamic v) => (v ?? '').toString().trim().toLowerCase();
      final selectedCat = normalize(selectedCategory);
      if (selectedCat.isEmpty) return <Map<String, dynamic>>[];
      final selectedFlow = normalize(selectedMarineFlow);

      final rows = NatureCatalogData.rows.where((row) {
        if (normalize(row['category']) != selectedCat) return false;
        if (selectedCat != 'marine') return true;
        final flow = normalize(row['marine_flow']);
        return flow.isEmpty || flow == selectedFlow;
      }).map((row) {
        return {
          'nature_of_collection': row['nature_of_collection'],
          'amount': row['amount'],
          'nature_code': row['nature_code'],
        };
      }).toList();
      return rows;
    }

    if (selectedCategory.trim().isEmpty) {
      return <Map<String, dynamic>>[];
    }
    final client = Supabase.instance.client;
    try {
      final data = await client
          .from('receipt_natures')
          .select('nature_of_collection, amount, category, marine_flow, nature_code')
          .eq('category', selectedCategory)
          .order('nature_of_collection');

      List<Map<String, dynamic>> rows = List<Map<String, dynamic>>.from(data);
      final normalize =
          (dynamic v) => (v ?? '').toString().trim().toLowerCase();

      if (selectedCategory == 'Marine') {
        final flowRows = rows
            .where((row) =>
                normalize(row['marine_flow']) == normalize(selectedMarineFlow))
            .toList();
        final noFlowRows =
            rows.where((row) => normalize(row['marine_flow']).isEmpty).toList();
        rows = flowRows.isNotEmpty ? flowRows : noFlowRows;
      }

      if (rows.isEmpty) {
        final fallbackData = await client
            .from('receipt_natures')
            .select(
              'nature_of_collection, amount, category, marine_flow, nature_code',
            )
            .order('nature_of_collection');
        final allRows = List<Map<String, dynamic>>.from(fallbackData);
        rows = allRows.where((row) {
          final categoryMatch =
              normalize(row['category']) == normalize(selectedCategory);
          if (!categoryMatch) return false;
          if (selectedCategory != 'Marine') return true;
          final flow = normalize(row['marine_flow']);
          return flow == normalize(selectedMarineFlow) || flow.isEmpty;
        }).toList();
      }

      final normalizedRows = rows
          .map((row) {
            return {
              'nature_of_collection': row['nature_of_collection'],
              'amount': row['amount'],
              'nature_code': row['nature_code'],
            };
          })
          .where((row) => (row['nature_of_collection'] ?? '')
              .toString()
              .trim()
              .isNotEmpty)
          .toList();

      if (normalizedRows.isNotEmpty) return normalizedRows;
      return localRowsForCategory();
    } catch (_) {
      return localRowsForCategory();
    }
  }

  @override
  void dispose() {
    if (!widget.readOnly && _hasPendingUnpersistedData) {
      _categoryDrafts.clear();
    }
    _natureLoadVersion++;
    _verticalScrollController.dispose();
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

  // Get default natures when table doesn't exist
  List<Map<String, dynamic>> _getDefaultNatures() {
    final rows = NatureCatalogData.rows
        .where((row) =>
            (row['category'] ?? '').toString().trim().toLowerCase() ==
            selectedCategory.trim().toLowerCase())
        .map((row) => <String, dynamic>{
              'nature_of_collection': row['nature_of_collection'],
              'amount': row['amount'],
              'nature_code': row['nature_code'],
            })
        .toList();
    if (rows.isNotEmpty) return rows;
    return const [
      {'nature_of_collection': 'General Fee', 'amount': 0.0, 'nature_code': null},
    ];
  }

  Future<void> _showQuantityPopup(int index, double amount) async {
    final quantityController = TextEditingController(text: '1');

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter Quantity'),
          content: TextField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantity',
              hintText: 'Enter quantity',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final quantity =
                    double.tryParse(quantityController.text) ?? 1.0;
                final totalAmount = amount * quantity;
                amountCtrls[index].text = totalAmount.toStringAsFixed(2);
                _recalculate();
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
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
      final amusementAmount = ((subtotalWithoutAmusement * 0.10) * 100).round() / 100;
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
      onTap: () async {
        final selected = await _showNatureSearchDialog();
        if (selected == null) {
          return;
        }

        final selectedName = selected['nature_of_collection']?.toString();
        if (selectedName == null || selectedName.isEmpty) {
          setState(() {
            natures[i] = null;
            _natureStartDates[i] = null;
          });
          amountCtrls[i].clear();
          _saveDraftForCurrentCategory();
          _recalculate();
          return;
        }

        setState(() {
          natures[i] = selectedName;
          final selectedCode = (selected['nature_code'] ?? '').toString().trim();
          if (selectedCode.isNotEmpty) {
            accountCtrls[i].text = selectedCode;
          }
          if (!_requiresStartDateForBusinessPermit()) {
            _natureStartDates[i] = null;
          }
        });

        if (_requiresStartDateForBusinessPermit()) {
          final picked = await _showBusinessPermitStartDatePopup(
            initialDate: _natureStartDates[i] ?? DateTime.now(),
          );
          if (picked != null && mounted) {
            setState(() {
              _natureStartDates[i] = picked;
            });
          }
        }
        _saveDraftForCurrentCategory();
        double amount = (selected['amount'] as num?)?.toDouble() ?? 0.0;
        if (amount <= 0) {
          final manualAmount = await _showAmountPopup();
          if (manualAmount == null) return;
          amount = manualAmount;
        }
        if (_usesPeriodPricing()) {
          await _showPeriodPopup(i, amount);
        } else {
          await _showQuantityPopup(i, amount);
        }
        _saveDraftForCurrentCategory();
        _recalculate();
      },
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
    );
  }

  bool _usesPeriodPricing() {
    final category = selectedCategory.toLowerCase().trim();
    return category == 'rent' ||
        category == 'market operation' ||
        category == 'market operations' ||
        (category.contains('market') && category.contains('operation'));
  }

  Future<void> _showPeriodPopup(int index, double monthlyAmount) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
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
        );
      },
    );

    if (selected == null) return;

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
        dialogNatures = _getDefaultNatures();
      }
    }

    final selected = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
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
            final label =
                (row['nature_of_collection'] ?? '').toString().trim().toLowerCase();
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
        'nature': nature,
        'nature_line2': _natureLine2(i),
        'start_date': _natureStartDates[i]?.toIso8601String(),
        'account_code': accountCode,
        'nature_code': resolvedNatureCode,
        'price': amount,
      });
    }
    return items;
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
        'officer':
            officerCtrl.text.trim().isEmpty ? null : officerCtrl.text.trim(),
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
    final previewItems = _buildCollectionItems()
        .where((e) => ((e['price'] as num?)?.toDouble() ?? 0.0) > 0)
        .toList();
    final shouldPrint = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(18),
          child: SizedBox(
            width: 420,
            height: 720,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: _categoryThemeColor(selectedCategory),
                  child: const Text(
                    'Final Receipt Preview',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: _buildThermalSummaryPreview(previewItems),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => Navigator.pop(context, true),
                        icon: const Icon(Icons.print),
                        label: const Text('Confirm & Print'),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              _categoryThemeColor(selectedCategory),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldPrint != true || !mounted) return;
    await _printReceipt();
  }

  Widget _buildThermalSummaryPreview(List<Map<String, dynamic>> items) {
    final serial = serialCtrl.text.trim().isEmpty ? '-' : serialCtrl.text.trim();
    final date = dateCtrl.text.trim().isEmpty ? '-' : dateCtrl.text.trim();
    final payor = payorCtrl.text.trim();
    final collector = officerCtrl.text.trim();
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
                'RECEIPT SUMMARY',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Text('No: $serial'),
            Text('Date: $date'),
            if (payor.isNotEmpty) Text('Payor: $payor'),
            if (collector.isNotEmpty) Text('Collector: $collector'),
            const SizedBox(height: 2),
            const Text('Payment:'),
            Text('${isCash ? '[x]' : '[ ]'} Cash  ${isCheck ? '[x]' : '[ ]'} Check'),
            Text('${isMoneyOrder ? '[x]' : '[ ]'} Money Order'),
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

      final pageHeightMm = (90 + (itemRows.length * 8)).clamp(120, 300).toDouble();
      final thermalFormat = PdfPageFormat(
        58 * PdfPageFormat.mm,
        pageHeightMm * PdfPageFormat.mm,
        marginLeft: 2 * PdfPageFormat.mm,
        marginRight: 2 * PdfPageFormat.mm,
        marginTop: 2 * PdfPageFormat.mm,
        marginBottom: 2 * PdfPageFormat.mm,
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
                    'RECEIPT SUMMARY',
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text('No: $serialForLog', style: const pw.TextStyle(fontSize: 7)),
                pw.Text('Date: ${dateCtrl.text.trim()}',
                    style: const pw.TextStyle(fontSize: 7)),
                if (payorCtrl.text.trim().isNotEmpty)
                  pw.Text('Payor: ${payorCtrl.text.trim()}',
                      style: const pw.TextStyle(fontSize: 7)),
                if (officerCtrl.text.trim().isNotEmpty)
                  pw.Text('Collector: ${officerCtrl.text.trim()}',
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
        'officer':
            officerCtrl.text.trim().isEmpty ? null : officerCtrl.text.trim(),
        'total_amount': total,
        'collection_items': items,
        'nature_code': combinedNatureCodes,
        'payment_method': paymentMethod,
      };

      try {
        await _insertPrintLogWithNatureCodeFallback(printLogPayload);
        // Also flush any old queued logs when connection is available.
        await OfflineReceiptStorageService.syncPending();
      } catch (_) {
        await OfflineReceiptStorageService.enqueuePrintLog(printLogPayload);
      }

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Receipt printed. If database is offline, it is stored in Storage and will auto-upload later.',
          ),
        ),
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

  bool _isMalformedArrayLiteralError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('22p02') && msg.contains('malformed array literal');
  }

  List<String> _normalizeNatureCodesToList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return <String>[];
    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _insertPrintLogWithNatureCodeFallback(
    Map<String, dynamic> payload,
  ) async {
    final client = Supabase.instance.client;
    try {
      await client.from('receipt_print_logs').insert(payload);
    } catch (e) {
      if (!_isMalformedArrayLiteralError(e)) rethrow;
      final retryPayload = Map<String, dynamic>.from(payload);
      retryPayload['nature_code'] =
          _normalizeNatureCodesToList(retryPayload['nature_code']);
      await client.from('receipt_print_logs').insert(retryPayload);
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
            final dropdownWidth = constraints.maxWidth < 280
                ? constraints.maxWidth
                : (constraints.maxWidth * 0.48).clamp(150.0, 240.0);
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
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Category',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(
                      width: dropdownWidth,
                      child: DropdownButtonFormField<String>(
                        value: _resolvedCategoryValue(),
                        isExpanded: true,
                        isDense: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: _availableCategories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(
                                  category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        selectedItemBuilder: (context) {
                          return _availableCategories
                              .map(
                                (category) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    category,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList();
                        },
                        onChanged: (value) {
                          if (value == null) return;
                          _saveDraftForCurrentCategory();
                          setState(() {
                            selectedCategory = value;
                          });
                          _restoreDraftForCategory(value);
                          _loadAvailableNatures();
                        },
                      ),
                    ),
                  ],
                ),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                        isSaving ? 'Nagse-save...' : 'I-save sa mga resibo'),
                  ),
                if (widget.showPrintButton)
                  OutlinedButton.icon(
                    onPressed: _showPrintConfirmation,
                    icon: const Icon(Icons.print),
                    label: const Text('Preview & Print'),
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
                    setState(() => selectedMarineFlow = 'Incoming');
                    _loadAvailableNatures();
                  },
                ),
                ChoiceChip(
                  label: const Text('Outgoing'),
                  selected: selectedMarineFlow == 'Outgoing',
                  onSelected: (_) {
                    setState(() => selectedMarineFlow = 'Outgoing');
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
        return AlertDialog(
          title: const Text('Enter Amount'),
          content: TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                      content: Text('Please enter a valid amount greater than 0'),
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop(amount);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
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
      backgroundColor: widget.readOnly
          ? _categoryThemeColor(selectedCategory).withValues(alpha: 0.10)
          : const Color(0xFFE8EAED),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          final maxH = constraints.maxHeight;
          final safeW = (maxW - 24).clamp(280.0, 2400.0);
          final pad = safeW < 520 ? 12.0 : 20.0;
          final scale = 1.0;
          final effectiveW = (maxW - 24).clamp(280.0, 2400.0);
          final effectiveH = (maxH - 24).clamp(420.0, 2400.0);

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.topCenter,
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
                                                width: col0 + col,
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
                                              _cell(
                                                width: col * 2,
                                                child: Row(
                                                  children: [
                                                    const Text('Fund'),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: TextField(
                                                        controller: fundCtrl,
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
                                                child: Stack(
                                                  children: [
                                                    const Align(
                                                      alignment:
                                                          Alignment.topLeft,
                                                      child: Text(
                                                          'Received the amount stated above.'),
                                                    ),
                                                    Align(
                                                      alignment:
                                                          Alignment.bottomRight,
                                                      child: SizedBox(
                                                        width: 220,
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            if (_officerSignatureImageUrl !=
                                                                null) ...[
                                                              SizedBox(
                                                                height: 34,
                                                                child: Image
                                                                    .network(
                                                                  _officerSignatureImageUrl!,
                                                                  fit: BoxFit
                                                                      .contain,
                                                                  errorBuilder: (context,
                                                                          error,
                                                                          stackTrace) =>
                                                                      const SizedBox
                                                                          .shrink(),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 2),
                                                            ],
                                                            TextField(
                                                              controller:
                                                                  officerCtrl,
                                                              readOnly: widget
                                                                  .readOnly,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold),
                                                              textCapitalization:
                                                                  TextCapitalization
                                                                      .characters,
                                                              decoration:
                                                                  const InputDecoration(
                                                                border:
                                                                    InputBorder
                                                                        .none,
                                                                isDense: true,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 2),
                                                            Container(
                                                                height: 1,
                                                                color: Colors
                                                                    .black),
                                                            const Padding(
                                                              padding: EdgeInsets
                                                                  .only(top: 2),
                                                              child: Text(
                                                                  'Collecting Officer',
                                                                  textAlign:
                                                                      TextAlign
                                                                          .center),
                                                            ),
                                                          ],
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
