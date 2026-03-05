import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reciept.dart';
import 'bottom_bar_view.dart';
import 'models/tabIcon_data.dart';
import 'category_theme_color.dart';

class ManageReceiptOverviewPage extends StatefulWidget {
  final bool isUserMode;
  final String initialCategory;
  final String initialMarineFlow;
  final bool openManagePayorOnStart;

  const ManageReceiptOverviewPage({
    super.key,
    this.isUserMode = false,
    this.initialCategory = 'Marine',
    this.initialMarineFlow = 'Incoming',
    this.openManagePayorOnStart = false,
  });

  @override
  State<ManageReceiptOverviewPage> createState() =>
      _ManageReceiptOverviewPageState();
}

class _ManageReceiptOverviewPageState extends State<ManageReceiptOverviewPage> {
  final String _selectedCategory = 'All';
  Timer? _receiptLoadTimer;
  int _userNavIndex = -1;
  bool _receiptsTableMissing = false;

  bool _isReceiptsTableMissingError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('pgrst205') &&
        msg.contains("public.receipts") &&
        msg.contains('schema cache');
  }

  Color _themeColorForCategory(String category) {
    return categoryThemeColor(category);
  }

  Color _onColorFor(Color background) {
    return background.computeLuminance() > 0.62 ? Colors.black87 : Colors.white;
  }

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    // Cancel previous timer
    _receiptLoadTimer?.cancel();

    // Add small delay to prevent excessive calls
    _receiptLoadTimer = Timer(const Duration(milliseconds: 100), () async {
      try {
        final client = Supabase.instance.client;
        if (!_receiptsTableMissing) {
          if (_selectedCategory != 'All') {
            await client
                .from('receipts')
                .select('*')
                .eq('category', _selectedCategory)
                .order('saved_at', ascending: false);
          } else {
            await client
                .from('receipts')
                .select('*')
                .order('saved_at', ascending: false);
          }
          return;
        }

        // Fallback path when public.receipts is not available.
        if (_selectedCategory != 'All') {
          await client
              .from('receipt_print_logs')
              .select('*')
              .eq('category', _selectedCategory)
              .order('printed_at', ascending: false);
        } else {
          await client
              .from('receipt_print_logs')
              .select('*')
              .order('printed_at', ascending: false);
        }
      } catch (e) {
        if (_isReceiptsTableMissingError(e)) {
          _receiptsTableMissing = true;
          // Retry once using fallback table.
          _loadReceipts();
          return;
        }
      }
    });
  }

  @override
  void dispose() {
    _receiptLoadTimer?.cancel();
    super.dispose();
  }

  void _closeReceiptForm() {
    _loadReceipts();
  }

  Widget _buildReceiptFormContainer() {
    final headerColor = _themeColorForCategory(widget.initialCategory);
    final headerTextColor = _onColorFor(headerColor);
    return Column(
      children: [
        // Header with back button
        Container(
          padding: const EdgeInsets.all(16),
          color: headerColor,
          child: Row(
            children: [
              Text(
                'View Receipt',
                style: TextStyle(
                  color: headerTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        // Receipt form
        Expanded(
          child: ReceiptScreen(
            initialCategory: widget.initialCategory,
            initialMarineFlow: widget.initialMarineFlow,
            onSaveSuccess: _closeReceiptForm,
            showSaveButton: false, // Hide save button in form container
            showViewReceiptsButton:
                false, // Hide view receipts button in form container
            showPrintButton: widget.isUserMode,
            openManagePayorOnStart: widget.openManagePayorOnStart,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: _buildReceiptFormContainer(),
      bottomNavigationBar: widget.isUserMode
          ? BottomBarView(
              tabIconsList: [
                TabIconData(
                  imagePath: 'assets/history.png',
                  label: 'History',
                  index: 0,
                  isSelected: _userNavIndex == 0,
                ),
                TabIconData(
                  imagePath: 'assets/statistic-report.png',
                  label: 'Dashboard',
                  index: 1,
                  isSelected: _userNavIndex == 1,
                ),
                TabIconData(
                  imagePath: 'assets/hosting.png',
                  label: 'Storage',
                  index: 2,
                  isSelected: _userNavIndex == 2,
                ),
                TabIconData(
                  imagePath: 'assets/settings.png',
                  label: 'Settings',
                  index: 3,
                  isSelected: _userNavIndex == 3,
                ),
              ],
              changeIndex: (index) {
                Navigator.pop(context, index);
              },
              addClick: () {
                setState(() => _userNavIndex = -1);
              },
              themeColor: _themeColorForCategory(widget.initialCategory),
            )
          : null,
    );
  }
}
