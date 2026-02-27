import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reciept.dart';
import 'bottom_bar_view.dart';
import 'models/tabIcon_data.dart';
import 'language_service.dart';
import 'user_dashboard.dart';
import 'managereciept.dart';

class ReceiptViewScreen extends StatefulWidget {
  const ReceiptViewScreen({super.key});

  @override
  State<ReceiptViewScreen> createState() => _ReceiptViewScreenState();
}

class _ReceiptViewScreenState extends State<ReceiptViewScreen> {
  List<String> categories = ['All'];
  String selectedCategory = 'All';
  List<Map<String, dynamic>> receipts = [];
  Map<String, dynamic>? selectedReceipt;
  bool isLoading = false;
  bool hasError = false;
  int _navIndex = 0;

  bool get _canUpdateUi {
    if (!mounted) return false;
    final route = ModalRoute.of(context);
    return route == null || route.isCurrent;
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadReceipts();
  }

  Future<void> _loadCategories() async {
    try {
      final client = Supabase.instance.client;
      final fromNatures = await client.from('receipt_natures').select('category');
      final fromReceipts = await client.from('receipts').select('category');

      final seen = <String>{'all'};
      final values = <String>['All'];

      void addCategory(dynamic raw) {
        final value = (raw ?? '').toString().trim();
        if (value.isEmpty) return;
        final key = value.toLowerCase();
        if (seen.add(key)) {
          values.add(value);
        }
      }

      for (final row in List<Map<String, dynamic>>.from(fromNatures)) {
        addCategory(row['category']);
      }
      for (final row in List<Map<String, dynamic>>.from(fromReceipts)) {
        addCategory(row['category']);
      }

      if (!_canUpdateUi) return;
      setState(() {
        categories = values;
        if (!categories.contains(selectedCategory)) {
          selectedCategory = 'All';
        }
      });
    } catch (_) {
      if (!_canUpdateUi) return;
      setState(() {
        categories = ['All'];
        selectedCategory = 'All';
      });
    }
  }

  String _effectiveCategoryForActions() {
    if (selectedCategory != 'All') return selectedCategory;
    if (categories.length > 1) return categories[1];
    final fromReceipt = (selectedReceipt?['category'] ?? '').toString().trim();
    if (fromReceipt.isNotEmpty) return fromReceipt;
    return '';
  }

  Future<void> _loadReceipts() async {
    if (!_canUpdateUi) return;

    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      final query = Supabase.instance.client.from('receipts').select();
      final filteredQuery = selectedCategory != 'All'
          ? query.eq('category', selectedCategory)
          : query;
      final data = await filteredQuery.order('saved_at', ascending: false);
      if (_canUpdateUi) {
        setState(() {
          receipts = List<Map<String, dynamic>>.from(data);
          selectedReceipt = receipts.isNotEmpty ? receipts.first : null;
        });
      }
    } catch (e) {
      if (_canUpdateUi) {
        setState(() {
          hasError = true;
        });
      }
    } finally {
      if (_canUpdateUi) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Color _getCategoryColor(String? category) {
    final v = (category ?? '').toLowerCase().trim();
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
    return Colors.grey;
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'marine':
        return Icons.water;
      case 'slaughter':
        return Icons.restaurant;
      case 'rent':
        return Icons.home;
      default:
        return Icons.receipt;
    }
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

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Unknown date';

    DateTime date;
    if (dateValue is String) {
      date = DateTime.parse(dateValue);
    } else if (dateValue is DateTime) {
      date = dateValue;
    } else {
      return 'Invalid date';
    }

    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bottomBarPadding =
        BottomBarView.baseHeight + MediaQuery.of(context).padding.bottom;
    final body = isLoading
        ? const Center(child: CircularProgressIndicator())
        : hasError
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text('Failed to load receipts'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadReceipts,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              )
            : receipts.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No receipts found',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Create a new receipt to get started',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(color: Color(0xFFE0E3E7)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        margin: const EdgeInsets.all(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Filter Receipts',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: selectedCategory,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Category',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: categories.map((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(
                                            value,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      selectedItemBuilder: (context) {
                                        return categories
                                            .map(
                                              (value) => Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  value,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList();
                                      },
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          selectedCategory = newValue!;
                                        });
                                        _loadReceipts();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (selectedReceipt != null)
                        Card(
                          elevation: 1,
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: _getCategoryColor(
                                          selectedReceipt!['category']),
                                      child: Icon(
                                        _getCategoryIcon(
                                            selectedReceipt!['category']),
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            selectedReceipt![
                                                    'nature_of_collection'] ??
                                                'No Nature',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16),
                                          ),
                                          Text(
                                              'Category: ${selectedReceipt!['category']}'),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₱${selectedReceipt!['price']?.toStringAsFixed(2) ?? '0.00'}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Color(0xFF1E3A5F),
                                          ),
                                        ),
                                        Text(
                                          _formatDate(
                                              selectedReceipt!['saved_at']),
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (selectedReceipt!['marine_flow'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                        'Flow: ${selectedReceipt!['marine_flow']}'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      Expanded(
                        child: selectedReceipt != null
                            ? ReceiptScreen(
                                receiptData: selectedReceipt,
                                readOnly: true,
                                useFullWidth: true,
                              )
                            : const Center(
                                child: Text('Select a receipt to view details'),
                              ),
                      ),
                    ],
                  );

    return Scaffold(
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: bottomBarPadding),
            child: body,
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: BottomBarView(
              tabIconsList: [
                TabIconData(
                  imagePath: 'assets/history.png',
                  label: LanguageService.translate('History'),
                  index: 0,
                  isSelected: _navIndex == 0,
                ),
                TabIconData(
                  imagePath: 'assets/statistic-report.png',
                  label: LanguageService.translate('Dashboard'),
                  index: 1,
                  isSelected: _navIndex == 1,
                ),
                TabIconData(
                  imagePath: 'assets/hosting.png',
                  label: LanguageService.translate('Storage'),
                  index: 2,
                  isSelected: _navIndex == 2,
                ),
                TabIconData(
                  imagePath: 'assets/settings.png',
                  label: LanguageService.translate('Settings'),
                  index: 3,
                  isSelected: _navIndex == 3,
                ),
              ],
              changeIndex: (index) {
                FocusScope.of(context).unfocus();
                if (!mounted) return;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => UserDashboardNavigation(
                        selectedCategory: _effectiveCategoryForActions(),
                        initialIndex: index,
                      ),
                    ),
                  );
                });
              },
              addClick: () {
                FocusScope.of(context).unfocus();
                if (!mounted) return;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ManageReceiptOverviewPage(
                        isUserMode: true,
                        initialCategory: _effectiveCategoryForActions(),
                        initialMarineFlow: 'Incoming',
                      ),
                    ),
                  );
                });
              },
              themeColor: _themeColorForCategory(
                _effectiveCategoryForActions(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
