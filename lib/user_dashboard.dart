import 'package:flutter/material.dart';
import 'bottom_bar_view.dart';
import 'models/tabIcon_data.dart';
import 'dashboard.dart';
import 'managereciept.dart';
import 'user_receipt_history.dart';
import 'settings.dart';
import 'offline_storage_page.dart';
import 'offline_receipt_storage_service.dart';
import 'language_service.dart';

class UserDashboardNavigation extends StatefulWidget {
  final String selectedCategory;
  final int initialIndex;

  const UserDashboardNavigation({
    super.key,
    this.selectedCategory = '',
    this.initialIndex = 1,
  });

  @override
  State<UserDashboardNavigation> createState() =>
      _UserDashboardNavigationState();
}

class _UserDashboardNavigationState extends State<UserDashboardNavigation> {
  int _selectedIndex = 1;
  bool _openedReceiptOnStart = false;
  late String _selectedCategory;

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

  Widget _screenForIndex(int index) {
    switch (index) {
      case 0:
        return UserReceiptHistoryPage(
          key: ValueKey('user_history_$_selectedCategory'),
          selectedCategory: _selectedCategory,
        );
      case 1:
        return DashboardContent(
          key: ValueKey('user_analytics_$_selectedCategory'),
          selectedCategory: _selectedCategory,
        );
      case 2:
        return OfflineStoragePage(
          key: ValueKey('offline_storage_$_selectedCategory'),
          selectedCategory: _selectedCategory,
        );
      case 3:
      default:
        return SettingsPage(
          key: ValueKey('user_settings_$_selectedCategory'),
          showUserLogout: true,
          showAdminSerialSetting: false,
          selectedCategory: _selectedCategory,
        );
    }
  }

  @override
  void initState() {
    super.initState();
    final idx = widget.initialIndex.clamp(0, 3);
    _selectedIndex = idx;
    _selectedCategory = widget.selectedCategory.trim().isEmpty
        ? 'All'
        : widget.selectedCategory.trim();
    // Attempt background sync of queued receipts on dashboard open.
    OfflineReceiptStorageService.syncPending();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _openedReceiptOnStart) return;
      _openedReceiptOnStart = true;
      _openReceiptForm();
    });
  }

  Future<void> _openReceiptForm() async {
    final result = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => ManageReceiptOverviewPage(
          isUserMode: true,
          initialCategory: _selectedCategory,
          initialMarineFlow: 'Incoming',
        ),
      ),
    );
    if (!mounted) return;
    // If receipt page requested a tab switch, apply it.
    if (result != null && result >= 0 && result <= 3) {
      setState(() => _selectedIndex = result);
      return;
    }
    // Otherwise just refresh current screen.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final textScale = screenWidth < 380
        ? 1.0
        : screenWidth < 480
            ? 1.06
            : 1.12;
    final bottomBarPadding = BottomBarView.baseHeight + media.padding.bottom;
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLanguage,
      builder: (context, language, _) {
        return Scaffold(
          body: Stack(
            children: [
              // =======================
              // BACKGROUND GLOW CIRCLES
              // =======================
              Positioned(
                top: -120,
                left: -120,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _themeColorForCategory(_selectedCategory)
                        .withValues(alpha: 0.18),
                  ),
                ),
              ),
              Positioned(
                bottom: -140,
                right: -140,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _themeColorForCategory(_selectedCategory)
                        .withValues(alpha: 0.12),
                  ),
                ),
              ),
              // =======================
              // MAIN CONTENT
              // =======================
              Padding(
                padding: EdgeInsets.only(bottom: bottomBarPadding),
                child: MediaQuery(
                  data: media.copyWith(
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _screenForIndex(_selectedIndex),
                  ),
                ),
              ),
              // ===============================
              // BOTTOM NAVIGATION BAR
              // ===============================
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
                      isSelected: _selectedIndex == 0,
                    ),
                    TabIconData(
                      imagePath: 'assets/statistic-report.png',
                      label: LanguageService.translate('Dashboard'),
                      index: 1,
                      isSelected: _selectedIndex == 1,
                    ),
                    TabIconData(
                      imagePath: 'assets/hosting.png',
                      label: LanguageService.translate('Storage'),
                      index: 2,
                      isSelected: _selectedIndex == 2,
                    ),
                    TabIconData(
                      imagePath: 'assets/settings.png',
                      label: LanguageService.translate('Settings'),
                      index: 3,
                      isSelected: _selectedIndex == 3,
                    ),
                  ],
                  changeIndex: (index) {
                    setState(() => _selectedIndex = index);
                  },
                  addClick: () {
                    _openReceiptForm();
                  },
                  themeColor: _themeColorForCategory(_selectedCategory),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
