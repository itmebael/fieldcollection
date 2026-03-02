import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'reports.dart';
import 'settings.dart';
import 'login.dart';
import 'session_service.dart';
import 'nature_management.dart';
import 'admin_user_management.dart';

const Color _navy900 = Color(0xFF0A1F33);
const Color _navy800 = Color(0xFF102A46);
const Color _navy700 = Color(0xFF14345C);
const Color _cyan500 = Color(0xFF3BB3FD);
const Color _cyan400 = Color(0xFF5CC7FF);
const Color _cyan300 = Color(0xFF8AD9FF);
const Color _glassWhite = Color(0xFFFFFFFF);
const Color _sidebarBorder = Color(0xFF1C3D5E);
const Color _sidebarItemIdle = Color(0x0014345C);
const Color _sidebarItemActive = Color(0xFF1A426F);

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardContent(),
    const ReportsPage(),
    const NatureManagementScreen(),
    const AdminUserManagementScreen(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    bool isExtended = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      body: Row(
        children: [
          // =======================
          // PROFESSIONAL SIDEBAR
          // =======================
          SizedBox(
            width: isExtended ? 250 : 92,
            child: Container(
              decoration: const BoxDecoration(
                color: _navy900,
                border: Border(
                  right: BorderSide(color: _sidebarBorder),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: isExtended
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: _navy800,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.14),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.shield,
                                    color: Colors.white, size: 22),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Admin Console",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        "System Management",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const Icon(
                            Icons.shield,
                            size: 28,
                            color: Colors.white,
                          ),
                  ),
                  const SizedBox(height: 16),
                  Divider(
                    color: Colors.white.withValues(alpha: 0.18),
                    indent: 14,
                    endIndent: 14,
                    height: 1,
                  ),
                  const SizedBox(height: 12),
                  _buildNavItem(Icons.dashboard, "Dashboard", 0, isExtended),
                  _buildNavItem(Icons.assessment, "Reports", 1, isExtended),
                  _buildNavItem(Icons.playlist_add, "Add Entry", 2, isExtended),
                  _buildNavItem(
                      Icons.manage_accounts, "User Accounts", 3, isExtended),
                  _buildNavItem(Icons.settings, "Settings", 4, isExtended),
                  const Spacer(),
                  Divider(
                    color: Colors.white.withValues(alpha: 0.18),
                    indent: 14,
                    endIndent: 14,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                    child: SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.logout, size: 18),
                        label: isExtended
                            ? const Text("Sign Out")
                            : const SizedBox.shrink(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.30),
                          ),
                          backgroundColor: _navy800,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: isExtended ? 12 : 0,
                          ),
                        ),
                        onPressed: () {
                          SessionService.clearSession().then((_) {
                            if (!context.mounted) return;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginPage(),
                              ),
                            );
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // =======================
          // MAIN CONTENT
          // =======================
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _screens[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      IconData icon, String label, int index, bool isExtended) {
    final bool isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? _sidebarItemActive : _sidebarItemIdle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.34)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisAlignment:
                isExtended ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white.withValues(alpha: isSelected ? 1.0 : 0.84),
                size: 21,
              ),
              if (isExtended) const SizedBox(width: 12),
              if (isExtended)
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color:
                          Colors.white.withValues(alpha: isSelected ? 1 : 0.9),
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===============================
// PROFESSIONAL DASHBOARD UI
// ===============================
class DashboardContent extends StatefulWidget {
  final String selectedCategory;

  const DashboardContent({
    super.key,
    this.selectedCategory = 'All',
  });

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent>
    with WidgetsBindingObserver {
  bool _isLoading = false;
  List<Map<String, dynamic>> _entries = [];
  String _selectedRange = 'Daily';
  String _selectedCategory = 'All';
  String _selectedPeriodType = 'All';
  String _selectedMonthKey = 'All';
  String _selectedDateKey = 'All';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _selectedCategory = _normalizeCategory(widget.selectedCategory);
    WidgetsBinding.instance.addObserver(this);
    _loadDashboardEntries();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && !_isLoading) {
        _loadDashboardEntries();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadDashboardEntries();
    }
  }

  @override
  void didUpdateWidget(covariant DashboardContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategory != widget.selectedCategory) {
      setState(() {
        _selectedCategory = _normalizeCategory(widget.selectedCategory);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _normalizeCategory(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return 'All';
    return normalized;
  }

  String _monthKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}';

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _monthLabelFromKey(String key) {
    if (key == 'All') return 'All Months';
    final parts = key.split('-');
    if (parts.length != 2) return key;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) return key;
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${names[month - 1]} $year';
  }

  List<String> get _monthOptions {
    final keys = <String>{};
    for (final row in _entries) {
      final dt = DateTime.tryParse((row['printed_at'] ?? '').toString());
      if (dt != null) {
        keys.add(_monthKey(dt));
      }
    }
    final list = keys.toList()..sort((a, b) => b.compareTo(a));
    return ['All', ...list];
  }

  List<String> get _dateOptions {
    final keys = <String>{};
    for (final row in _entries) {
      final dt = DateTime.tryParse((row['printed_at'] ?? '').toString());
      if (dt != null) {
        keys.add(_dateKey(dt));
      }
    }
    final list = keys.toList()..sort((a, b) => b.compareTo(a));
    return ['All', ...list];
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? 0.0;
    return 0.0;
  }

  double _extractAmount(Map<String, dynamic> row) {
    final direct = _asDouble(row['total_amount']);
    if (direct > 0) return direct;

    final price = _asDouble(row['price']);
    if (price > 0) return price;

    final collectionPrice = _asDouble(row['collection_price']);
    if (collectionPrice > 0) return collectionPrice;

    final rawItems = row['collection_items'];
    if (rawItems is List) {
      return rawItems.fold<double>(0.0, (sum, item) {
        if (item is Map<String, dynamic>) {
          return sum + _asDouble(item['price']) + _asDouble(item['amount']);
        }
        if (item is Map) {
          final typed = Map<String, dynamic>.from(item);
          return sum + _asDouble(typed['price']) + _asDouble(typed['amount']);
        }
        return sum;
      });
    }
    return 0.0;
  }

  String _extractDate(Map<String, dynamic> row) {
    final printedAt = (row['printed_at'] ?? '').toString().trim();
    if (printedAt.isNotEmpty) return printedAt;
    final savedAt = (row['saved_at'] ?? '').toString().trim();
    if (savedAt.isNotEmpty) return savedAt;
    final createdAt = (row['created_at'] ?? '').toString().trim();
    return createdAt;
  }

  DateTime _referenceDate() {
    if (_selectedPeriodType == 'Date' && _selectedDateKey != 'All') {
      final dt = DateTime.tryParse(_selectedDateKey);
      if (dt != null) return dt;
    }
    if (_selectedPeriodType == 'Month' && _selectedMonthKey != 'All') {
      final parts = _selectedMonthKey.split('-');
      if (parts.length == 2) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        if (year != null && month != null && month >= 1 && month <= 12) {
          return DateTime(year, month, 1);
        }
      }
    }
    return DateTime.now();
  }

  List<String> get _categoryOptions {
    final set = <String>{'All'};
    for (final row in _entries) {
      final category = (row['category'] ?? '').toString().trim();
      if (category.isNotEmpty) {
        set.add(category);
      }
    }
    if (_selectedCategory.trim().isNotEmpty) {
      set.add(_selectedCategory.trim());
    }
    final list = set.toList();
    if (list.length <= 1) return list;
    final body = list.where((e) => e != 'All').toList()..sort();
    return ['All', ...body];
  }

  Future<void> _loadDashboardEntries() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final rows = <Map<String, dynamic>>[];
      final client = Supabase.instance.client;

      try {
        final printLogs = await client
            .from('receipt_print_logs')
            .select(
              'category, total_amount, printed_at, collection_items, nature_code, payment_method',
            )
            .order('printed_at', ascending: false);
        for (final item in List<Map<String, dynamic>>.from(printLogs)) {
          final printedAt = _extractDate(item);
          if (DateTime.tryParse(printedAt) == null) continue;
          rows.add({
            'category': (item['category'] ?? '').toString().trim(),
            'total_amount': _extractAmount(item),
            'printed_at': printedAt,
            'collection_items': item['collection_items'],
            'nature_of_collection': item['nature_of_collection'],
            'nature_code': item['nature_code'],
            'payment_method': item['payment_method'],
          });
        }
      } catch (_) {
        // Fall back to receipts when print-log table is unavailable or blocked.
      }

      if (rows.isEmpty) {
        try {
          final receipts = await client
              .from('receipts')
              .select('*')
              .order('saved_at', ascending: false);
          for (final item in List<Map<String, dynamic>>.from(receipts)) {
            final printedAt = _extractDate(item);
            if (DateTime.tryParse(printedAt) == null) continue;
            rows.add({
              'category': (item['category'] ?? '').toString().trim(),
              'total_amount': _extractAmount(item),
              'printed_at': printedAt,
              'collection_items': item['collection_items'],
              'nature_of_collection': item['nature_of_collection'],
              'nature_code': item['nature_code'],
              'payment_method': item['payment_method'],
            });
          }
        } catch (_) {
          // Keep rows empty if fallback source also fails.
        }
      }

      if (!mounted) return;
      setState(() => _entries = rows);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _sumForCategory(String category) {
    final needle = category.trim().toLowerCase();
    return _filteredEntries()
        .where((e) =>
            (e['category'] ?? '').toString().trim().toLowerCase() == needle)
        .fold<double>(
          0.0,
          (s, e) => s + ((e['total_amount'] as num?)?.toDouble() ?? 0.0),
        );
  }

  double _sumForWindow(
    List<Map<String, dynamic>> entries,
    DateTime start,
    DateTime end,
    String category,
  ) {
    return entries.where((e) {
      final dt = DateTime.tryParse((e['printed_at'] ?? '').toString());
      if (dt == null) return false;
      final cat = (e['category'] ?? '').toString().trim().toLowerCase();
      return cat == category.trim().toLowerCase() &&
          !dt.isBefore(start) &&
          dt.isBefore(end);
    }).fold<double>(
        0.0, (s, e) => s + ((e['total_amount'] as num?)?.toDouble() ?? 0.0));
  }

  _LineSeries _lineSeries(String category) {
    final now = _referenceDate();
    final entries = _filteredEntries();
    final spots = <FlSpot>[];
    final labels = <String>[];

    if (_selectedRange == 'Daily') {
      for (int h = 0; h < 24; h++) {
        final start = DateTime(now.year, now.month, now.day, h);
        final end = start.add(const Duration(hours: 1));
        final sum = _sumForWindow(entries, start, end, category);
        spots.add(FlSpot(h.toDouble(), sum));
        labels.add(h.toString());
      }
      return _LineSeries(spots, labels, 4);
    }

    if (_selectedRange == 'Weekly') {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (int i = 6; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        final start = DateTime(day.year, day.month, day.day);
        final end = start.add(const Duration(days: 1));
        final sum = _sumForWindow(entries, start, end, category);
        spots.add(FlSpot((6 - i).toDouble(), sum));
        labels.add(weekdays[day.weekday - 1]);
      }
      return _LineSeries(spots, labels, 1);
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    for (int m = 1; m <= 12; m++) {
      final start = DateTime(now.year, m, 1);
      final end = DateTime(now.year, m + 1, 1);
      final sum = _sumForWindow(entries, start, end, category);
      spots.add(FlSpot((m - 1).toDouble(), sum));
      labels.add(months[m - 1]);
    }
    return _LineSeries(spots, labels, 1);
  }

  _BarSeries _barSeries(String category) {
    final now = _referenceDate();
    final groups = <BarChartGroupData>[];
    final labels = <String>[];
    final entries = _filteredEntries();
    final categoryColor = category.trim().toLowerCase() == 'all'
        ? null
        : _categoryColor(category, 0);

    if (_selectedRange == 'Daily') {
      for (int h = 0; h < 24; h++) {
        final start = DateTime(now.year, now.month, now.day, h);
        final end = start.add(const Duration(hours: 1));
        final sum = _sumForWindow(entries, start, end, category);
        groups.add(_barGroup(h, sum, primary: categoryColor));
        labels.add(h.toString());
      }
      return _BarSeries(groups, labels, 4);
    }

    if (_selectedRange == 'Weekly') {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (int i = 6; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        final start = DateTime(day.year, day.month, day.day);
        final end = start.add(const Duration(days: 1));
        final sum = _sumForWindow(entries, start, end, category);
        final x = 6 - i;
        groups.add(_barGroup(x, sum, primary: categoryColor));
        labels.add(weekdays[day.weekday - 1]);
      }
      return _BarSeries(groups, labels, 1);
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    for (int m = 1; m <= 12; m++) {
      final start = DateTime(now.year, m, 1);
      final end = DateTime(now.year, m + 1, 1);
      final sum = _sumForWindow(entries, start, end, category);
      final x = m - 1;
      groups.add(_barGroup(x, sum, primary: categoryColor));
      labels.add(months[m - 1]);
    }
    return _BarSeries(groups, labels, 1);
  }

  BarChartGroupData _barGroup(int x, double sum, {Color? primary}) {
    final base = primary ?? _cyan500;
    final hsl = HSLColor.fromColor(base);
    final top = hsl.withLightness((hsl.lightness + 0.14).clamp(0.0, 1.0)).toColor();
    return BarChartGroupData(
      x: x,
      barsSpace: -8,
      barRods: [
        BarChartRodData(
          toY: (sum * 0.9).clamp(0, double.infinity),
          width: 16,
          color: base.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(8),
        ),
        BarChartRodData(
          toY: sum,
          width: 12,
          gradient: LinearGradient(
            colors: [top, base],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }

  Map<String, double> _categoryTotals() {
    final totals = <String, double>{};
    for (final e in _filteredEntries()) {
      final category = (e['category'] ?? '').toString().trim().isEmpty
          ? 'Uncategorized'
          : (e['category'] ?? '').toString().trim();
      final amount = (e['total_amount'] as num?)?.toDouble() ?? 0.0;
      totals[category] = (totals[category] ?? 0.0) + amount;
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final entry in sorted) entry.key: entry.value};
  }

  Color _categoryColor(String category, int i) {
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
    const palette = <Color>[
      Color(0xFFFF6B6B),
      Color(0xFFFFA94D),
      Color(0xFFFFD43B),
      Color(0xFF69DB7C),
      Color(0xFF4DABF7),
      Color(0xFF9775FA),
      Color(0xFFF06595),
      Color(0xFF20C997),
    ];
    return palette[i % palette.length];
  }

  _BarSeries _categoryBarSeries(Map<String, double> totals) {
    final groups = <BarChartGroupData>[];
    final labels = <String>[];
    final entries = totals.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      final category = entries[i].key;
      final amount = entries[i].value;
      groups.add(_barGroup(i, amount));
      labels.add(
          category.length > 10 ? '${category.substring(0, 10)}â€¦' : category);
    }
    return _BarSeries(groups, labels, 1);
  }

  List<_TopNature> _topNatureByCategoryFromEntries() {
    final grouped = <String, Map<String, double>>{};
    for (final row in _filteredEntries()) {
      final category = (row['category'] ?? '').toString().trim();
      final byNature = grouped.putIfAbsent(category, () => <String, double>{});
      if (category.isEmpty) continue;

      final items = row['collection_items'];
      if (items is List && items.isNotEmpty) {
        for (final item in items) {
          Map<String, dynamic>? map;
          if (item is Map<String, dynamic>) {
            map = item;
          } else if (item is Map) {
            map = Map<String, dynamic>.from(item);
          }
          if (map == null) continue;
          final nature = (map['nature'] ?? map['nature_of_collection'] ?? '')
              .toString()
              .trim();
          final amount = _asDouble(map['price']) + _asDouble(map['amount']);
          if (nature.isEmpty || amount <= 0) continue;
          byNature[nature] = (byNature[nature] ?? 0.0) + amount;
        }
        continue;
      }

      final fallbackNature =
          (row['nature_of_collection'] ?? '').toString().trim();
      final fallbackAmount = _extractAmount(row);
      if (fallbackNature.isNotEmpty && fallbackAmount > 0) {
        byNature[fallbackNature] =
            (byNature[fallbackNature] ?? 0.0) + fallbackAmount;
      }
    }

    final result = <_TopNature>[];
    grouped.forEach((category, byNature) {
      if (byNature.isEmpty) return;
      final sorted = byNature.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      result.add(
        _TopNature(
          category: category,
          nature: sorted.first.key,
          amount: sorted.first.value,
        ),
      );
    });
    result.sort((a, b) => b.amount.compareTo(a.amount));
    return result;
  }

  _BarSeries _topNatureBarSeries(List<_TopNature> rows) {
    final groups = <BarChartGroupData>[];
    final labels = <String>[];
    for (var i = 0; i < rows.length; i++) {
      groups.add(
        _barGroup(i, rows[i].amount, primary: _categoryColor(rows[i].category, i)),
      );
      final c = rows[i].category;
      labels.add(c.length > 10 ? '${c.substring(0, 10)}...' : c);
    }
    return _BarSeries(groups, labels, 1);
  }

  Widget _categoryPie(Map<String, double> totals) {
    if (totals.isEmpty) {
      return const Center(child: Text('No data'));
    }
    final entries = totals.entries.toList();
    final sum = entries.fold<double>(0.0, (s, e) => s + e.value);
    return PieChart(
      PieChartData(
        centerSpaceRadius: 44,
        sectionsSpace: 2,
        sections: [
          for (var i = 0; i < entries.length; i++)
            PieChartSectionData(
              value: entries[i].value,
              color: _categoryColor(entries[i].key, i),
              title: sum <= 0
                  ? '0%'
                  : '${((entries[i].value / sum) * 100).toStringAsFixed(0)}%',
              titleStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
              radius: 78,
              titlePositionPercentageOffset: 0.62,
            ),
        ],
      ),
    );
  }

  Widget _pie3d(double marine, double slaughter, double rent) {
    final total = marine + slaughter + rent;
    final m = total == 0 ? 1.0 : marine;
    final s = total == 0 ? 1.0 : slaughter;
    final r = total == 0 ? 1.0 : rent;

    final bottom = PieChart(
      PieChartData(
        centerSpaceRadius: 46,
        sectionsSpace: 2,
        startDegreeOffset: -30,
        sections: [
          PieChartSectionData(
            value: m,
            color: _navy700.withValues(alpha: 0.55),
            title: '',
            radius: 86,
          ),
          PieChartSectionData(
            value: s,
            color: const Color(0xFFB88A00).withValues(alpha: 0.55),
            title: '',
            radius: 86,
          ),
          PieChartSectionData(
            value: r,
            color: const Color(0xFFB35B00).withValues(alpha: 0.55),
            title: '',
            radius: 86,
          ),
        ],
      ),
    );

    final top = PieChart(
      PieChartData(
        centerSpaceRadius: 44,
        sectionsSpace: 2,
        startDegreeOffset: -30,
        sections: [
          PieChartSectionData(
            value: m,
            color: _cyan500,
            title: 'Marine',
            titleStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
            radius: 78,
            titlePositionPercentageOffset: 0.62,
          ),
          PieChartSectionData(
            value: s,
            color: Colors.yellow,
            title: 'Slaughter',
            titleStyle: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
            radius: 78,
            titlePositionPercentageOffset: 0.62,
          ),
          PieChartSectionData(
            value: r,
            color: Colors.orange,
            title: 'Rental',
            titleStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
            radius: 78,
            titlePositionPercentageOffset: 0.62,
          ),
        ],
      ),
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(offset: const Offset(0, 10), child: bottom),
        top,
      ],
    );
  }

  List<Map<String, dynamic>> _filteredEntries() {
    if (_entries.isEmpty) return const [];
    final now = _referenceDate();
    final selectedCategory = _selectedCategory.trim().toLowerCase();
    final applyCategoryFilter =
        selectedCategory.isNotEmpty && selectedCategory != 'all';
    final applyMonthFilter =
        _selectedPeriodType == 'Month' && _selectedMonthKey != 'All';
    final applyDateFilter =
        _selectedPeriodType == 'Date' && _selectedDateKey != 'All';
    DateTime start;
    DateTime end;
    if (_selectedRange == 'Daily') {
      start = DateTime(now.year, now.month, now.day);
      end = start.add(const Duration(days: 1));
    } else if (_selectedRange == 'Weekly') {
      end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      start = end.subtract(const Duration(days: 7));
    } else {
      start = DateTime(now.year, 1, 1);
      end = DateTime(now.year + 1, 1, 1);
    }
    return _entries.where((e) {
      final dt = DateTime.tryParse((e['printed_at'] ?? '').toString());
      if (dt == null) return false;
      if (!applyMonthFilter && !applyDateFilter) {
        if (dt.isBefore(start) || !dt.isBefore(end)) return false;
      }
      if (applyMonthFilter && _monthKey(dt) != _selectedMonthKey) return false;
      if (applyDateFilter && _dateKey(dt) != _selectedDateKey) return false;
      if (!applyCategoryFilter) return true;
      final rowCategory = (e['category'] ?? '').toString().trim().toLowerCase();
      return rowCategory == selectedCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = _selectedCategory.trim();
    final isAllCategory =
        selectedCategory.isEmpty || selectedCategory.toLowerCase() == 'all';

    final selectedToken = selectedCategory.toLowerCase();
    final selectedTotal = _sumForCategory(selectedToken);
    final selectedLine = _lineSeries(selectedToken);
    final selectedBars = _barSeries(selectedToken);
    final categoryTotals = _categoryTotals();
    final topNatures = _topNatureByCategoryFromEntries();
    final topNatureBars = _topNatureBarSeries(topNatures);
    final overallTotal =
        categoryTotals.values.fold<double>(0.0, (sum, value) => sum + value);

    return Container(
      color: const Color(0xFFF2F7FB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===============================
          // HEADER
          // ===============================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: _navy700,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final title = const Text(
                  "Municipal Financial Dashboard",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                );
                final actions = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _isLoading ? null : _loadDashboardEntries,
                      tooltip: "Refresh",
                      icon: const Icon(Icons.refresh, color: Colors.white),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedRange,
                        underline: const SizedBox(),
                        items: ["Daily", "Weekly", "Yearly"]
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() => _selectedRange = val);
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        underline: const SizedBox(),
                        items: _categoryOptions
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                  e,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() => _selectedCategory = val);
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedPeriodType,
                        underline: const SizedBox(),
                        items: const ['All', 'Month', 'Date']
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(e),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() {
                            _selectedPeriodType = val;
                            if (val != 'Month') _selectedMonthKey = 'All';
                            if (val != 'Date') _selectedDateKey = 'All';
                          });
                        },
                      ),
                    ),
                    if (_selectedPeriodType == 'Month')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _monthOptions.contains(_selectedMonthKey)
                              ? _selectedMonthKey
                              : 'All',
                          underline: const SizedBox(),
                          items: _monthOptions
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    _monthLabelFromKey(e),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() => _selectedMonthKey = val);
                          },
                        ),
                      ),
                    if (_selectedPeriodType == 'Date')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _dateOptions.contains(_selectedDateKey)
                              ? _selectedDateKey
                              : 'All',
                          underline: const SizedBox(),
                          items: _dateOptions
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    e == 'All' ? 'All Dates' : e,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() => _selectedDateKey = val);
                          },
                        ),
                      ),
                  ],
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 8),
                      actions,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 12),
                    actions,
                  ],
                );
              },
            ),
          ),

          // ===============================
          // BODY
          // ===============================
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Financial Overview",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _navy800,
                    ),
                  ),
                  if (!_isLoading)
                    Column(
                      children: [
                        if (isAllCategory) ...[
                          _buildHighLowCategoryCards(categoryTotals),
                          const SizedBox(height: 16),
                          _buildCategorySummaryCards(
                            categoryTotals,
                            overallTotal,
                            topNatures,
                          ),
                          const SizedBox(height: 24),
                          _buildGraphCard(
                            "Highest Nature Per Category",
                            _barChart(
                              topNatureBars.groups,
                              topNatureBars.labels,
                              topNatureBars.interval,
                            ),
                            height: 300,
                            totalLabel:
                                "Top nature_of_collection amount per category",
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 14,
                            runSpacing: 8,
                            children: [
                              for (var i = 0; i < categoryTotals.length; i++)
                                _LegendItem(
                                  color: _categoryColor(
                                      categoryTotals.keys.elementAt(i), i),
                                  text: categoryTotals.keys.elementAt(i),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildGraphCard(
                            "All Category Income Pie",
                            _categoryPie3d(categoryTotals),
                            height: 360,
                            totalLabel:
                                "Overall Total: PHP ${overallTotal.toStringAsFixed(2)}",
                          ),
                        ] else ...[
                          _buildGraphCard(
                            "$selectedCategory Income Trend",
                            _lineChart(
                              selectedLine.spots,
                              selectedLine.labels,
                              selectedLine.interval,
                              primaryColor: _categoryColor(selectedCategory, 0),
                            ),
                            totalLabel:
                                "Total: PHP ${selectedTotal.toStringAsFixed(2)}",
                          ),
                          const SizedBox(height: 24),
                          _buildGraphCard(
                            "$selectedCategory Income Bars",
                            _barChart(
                              selectedBars.groups,
                              selectedBars.labels,
                              selectedBars.interval,
                            ),
                            height: 300,
                            totalLabel:
                                "Total: PHP ${selectedTotal.toStringAsFixed(2)}",
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphCard(
    String title,
    Widget chart, {
    double height = 250,
    String? totalLabel,
  }) {
    return Stack(
      children: [
        Positioned.fill(
          top: 8,
          left: 8,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFFDBE9FF), Color(0xFFFFE3EC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _glassWhite.withValues(alpha: 0.84),
                    _glassWhite.withValues(alpha: 0.60),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFFFA8A8).withValues(alpha: 0.35),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _navy900.withValues(alpha: 0.10),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: _navy800,
                    ),
                  ),
                  if (totalLabel != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      totalLabel,
                      style: TextStyle(
                        color: _navy800.withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(height: height, child: chart),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _categoryPie3d(Map<String, double> totals) {
    if (totals.isEmpty) return const Center(child: Text('No data'));
    final entries = totals.entries.toList();
    final sum = entries.fold<double>(0.0, (s, e) => s + e.value);

    final bottom = PieChart(
      PieChartData(
        centerSpaceRadius: 46,
        sectionsSpace: 2,
        startDegreeOffset: -28,
        sections: [
          for (var i = 0; i < entries.length; i++)
            PieChartSectionData(
              value: entries[i].value,
              color:
                  _categoryColor(entries[i].key, i).withValues(alpha: 0.55),
              title: '',
              radius: 86,
            ),
        ],
      ),
    );

    final top = PieChart(
      PieChartData(
        centerSpaceRadius: 44,
        sectionsSpace: 2,
        startDegreeOffset: -28,
        sections: [
          for (var i = 0; i < entries.length; i++)
            PieChartSectionData(
              value: entries[i].value,
              color: _categoryColor(entries[i].key, i),
              title: sum <= 0
                  ? '0%'
                  : '${((entries[i].value / sum) * 100).toStringAsFixed(0)}%',
              titleStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
              radius: 78,
              titlePositionPercentageOffset: 0.62,
            ),
        ],
      ),
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(offset: const Offset(0, 10), child: bottom),
        top,
      ],
    );
  }

  Widget _buildCategorySummaryCards(
    Map<String, double> totals,
    double overallTotal,
    List<_TopNature> topNatures,
  ) {
    if (totals.isEmpty) return const SizedBox.shrink();
    final entries = totals.entries.toList();
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (var i = 0; i < entries.length; i++)
          _buildCategoryCard(
            entries[i].key,
            entries[i].value,
            _categoryColor(entries[i].key, i),
            overallTotal,
            topNatures,
          ),
      ],
    );
  }

  Widget _buildHighLowCategoryCards(Map<String, double> totals) {
    if (totals.isEmpty) return const SizedBox.shrink();
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final highest = sorted.first;
    final lowest = sorted.last;
    final showLowest = sorted.length > 1;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildHighLowCard(
          title: 'Highest Income Category',
          category: highest.key,
          amount: highest.value,
          color: const Color(0xFF1E7A3E),
        ),
        if (showLowest)
          _buildHighLowCard(
            title: 'Lowest Income Category',
            category: lowest.key,
            amount: lowest.value,
            color: const Color(0xFFB3261E),
          ),
      ],
    );
  }

  Widget _buildHighLowCard({
    required String title,
    required String category,
    required double amount,
    required Color color,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 250, maxWidth: 360),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.20),
              color.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: color.withValues(alpha: 0.45),
            width: 1.1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: color.withValues(alpha: 0.95),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _navy900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'PHP ${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _navy800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    String category,
    double amount,
    Color color,
    double overallTotal,
    List<_TopNature> topNatures,
  ) {
    _TopNature? top;
    for (final row in topNatures) {
      if (row.category == category) {
        top = row;
        break;
      }
    }
    final percent = overallTotal <= 0 ? 0.0 : (amount / overallTotal) * 100;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 290),
      child: Stack(
        children: [
          Positioned.fill(
            top: 6,
            left: 6,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: color.withValues(alpha: 0.20),
              ),
            ),
          ),
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(0.02)
              ..rotateY(-0.02),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.28),
                    color.withValues(alpha: 0.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: color.withValues(alpha: 0.48),
                  width: 1.1,
                ),
              ),
              child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _navy800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'PHP ${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _navy900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${percent.toStringAsFixed(1)}% of total',
              style: TextStyle(
                fontSize: 11,
                color: _navy800.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              top == null ? 'Top Nature: -' : 'Top Nature: ${top.nature}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: _navy800.withValues(alpha: 0.82),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (top != null)
              Text(
                'Top Amount: PHP ${top.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 10,
                  color: _navy800.withValues(alpha: 0.70),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineChart(
    List<FlSpot> spots,
    List<String> labels,
    int interval, {
    Color? primaryColor,
  }) {
    final displaySpots = spots.isEmpty ? [const FlSpot(0, 0)] : spots;
    final maxY =
        displaySpots.map((e) => e.y).fold<double>(0, (a, b) => a > b ? a : b);
    final base = primaryColor ?? _cyan500;
    final hsl = HSLColor.fromColor(base);
    final top = hsl.withLightness((hsl.lightness + 0.14).clamp(0.0, 1.0)).toColor();
    final lineGradient = LinearGradient(
      colors: [base, top],
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    );
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval:
              (maxY == 0) ? 1 : (maxY / 4).clamp(1, double.infinity),
          getDrawingHorizontalLine: (value) => FlLine(
            color: _navy800.withValues(alpha: 0.08),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: (maxY == 0) ? 1 : (maxY / 4).clamp(1, double.infinity),
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: TextStyle(
                  color: _navy800.withValues(alpha: 0.65),
                  fontSize: 10,
                ),
              ),
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: interval.toDouble(),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[idx],
                    style: TextStyle(
                      color: _navy800.withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: displaySpots,
            isCurved: true,
            barWidth: 8,
            color: base.withValues(alpha: 0.18),
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
          LineChartBarData(
            spots: displaySpots,
            isCurved: true,
            barWidth: 4,
            gradient: lineGradient,
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  base.withValues(alpha: 0.28),
                  base.withValues(alpha: 0.02),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, _) => spot == displaySpots.last,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 5,
                color: Colors.white,
                strokeWidth: 3,
                strokeColor: base,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.white,
            getTooltipItems: (touchedSpots) => touchedSpots
                .map(
                  (spot) => LineTooltipItem(
                    spot.y.toStringAsFixed(2),
                    const TextStyle(
                      color: _navy800,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _barChart(
    List<BarChartGroupData> groups,
    List<String> labels,
    int interval,
  ) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: _navy800.withValues(alpha: 0.08),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: TextStyle(
                  color: _navy800.withValues(alpha: 0.65),
                  fontSize: 10,
                ),
              ),
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: interval.toDouble(),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[idx],
                    style: TextStyle(
                      color: _navy800.withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: groups.isEmpty
            ? [
                BarChartGroupData(
                    x: 0, barRods: [BarChartRodData(toY: 0, color: _cyan500)])
              ]
            : groups,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.white,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                rod.toY.toStringAsFixed(2),
                const TextStyle(
                  color: _navy800,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(text),
      ],
    );
  }
}

class _TopNature {
  final String category;
  final String nature;
  final double amount;

  const _TopNature({
    required this.category,
    required this.nature,
    required this.amount,
  });
}

class _LineSeries {
  final List<FlSpot> spots;
  final List<String> labels;
  final int interval;

  const _LineSeries(this.spots, this.labels, this.interval);
}

class _BarSeries {
  final List<BarChartGroupData> groups;
  final List<String> labels;
  final int interval;

  const _BarSeries(this.groups, this.labels, this.interval);
}
