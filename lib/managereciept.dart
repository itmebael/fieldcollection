import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reciept.dart';
import 'bottom_bar_view.dart';
import 'models/tabIcon_data.dart';

class ManageReceiptOverviewPage extends StatefulWidget {
  final bool isUserMode;
  final String initialCategory;
  final String initialMarineFlow;

  const ManageReceiptOverviewPage({
    super.key,
    this.isUserMode = false,
    this.initialCategory = 'Marine',
    this.initialMarineFlow = 'Incoming',
  });

  @override
  State<ManageReceiptOverviewPage> createState() =>
      _ManageReceiptOverviewPageState();
}

class _ManageReceiptOverviewPageState extends State<ManageReceiptOverviewPage> {
  String _selectedCategory = 'All';
  Timer? _receiptLoadTimer;
  int _userNavIndex = -1;

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
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    // Cancel previous timer
    _receiptLoadTimer?.cancel();

    // Add small delay to prevent excessive calls
    _receiptLoadTimer = Timer(const Duration(milliseconds: 100), () async {
      try {
        final client = Supabase.instance.client;
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
      } catch (e) {
        print('Error loading receipts: $e');
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
    return Column(
      children: [
        // Header with back button
        Container(
          padding: const EdgeInsets.all(16),
          color: _themeColorForCategory(widget.initialCategory),
          child: Row(
            children: [
              const Text(
                'View Receipt',
                style: TextStyle(
                  color: Colors.white,
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
