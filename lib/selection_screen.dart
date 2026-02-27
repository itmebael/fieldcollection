import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard.dart';
import 'user_dashboard.dart';
import 'session_service.dart';
import 'category_constants.dart';

class CategorySelectionScreen extends StatefulWidget {
  final bool isAdmin;

  const CategorySelectionScreen({Key? key, required this.isAdmin})
      : super(key: key);

  @override
  _CategorySelectionScreenState createState() =>
      _CategorySelectionScreenState();
}

class _CategorySelectionScreenState extends State<CategorySelectionScreen>
    with TickerProviderStateMixin {
  String? _selectedCategory;
  late PageController _pageController;
  int _currentPage = 0;
  Color _backgroundColor = const Color(0xFFF4F8FB); // Default background
  bool _isLoadingCategories = true;

  List<Map<String, dynamic>> _categories = [
    {
      'title': 'Marine',
      'description': 'Marine and fisheries operations',
      'color': Color.fromARGB(255, 117, 220, 121),
      'primaryColor': Color(0xFF2E7D32),
      'accentColor': Color(0xFFA5D6A7),
      'icon': 'assets/breakfast.png',
    },
    {
      'title': 'Slaughter',
      'description': 'Meat and slaughterhouse operations',
      'color': Color.fromARGB(255, 255, 122, 113),
      'primaryColor': Color(0xFFD32F2F),
      'accentColor': Color(0xFFFFB197),
      'icon': 'assets/dinner.png',
    },
    {
      'title': 'Rent',
      'description': 'Rental and property operations',
      'color': Color.fromARGB(255, 84, 238, 90),
      'primaryColor': Color(0xFF388E3C),
      'accentColor': Color(0xFFA9FFB5),
      'icon': 'assets/lunch.png',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.78);
    _loadCategories();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _navigateToDashboard() async {
    if (_selectedCategory != null) {
      // Navigate to appropriate dashboard based on user role
      if (widget.isAdmin) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
        );
      } else {
        await SessionService.saveUserSession(_selectedCategory!);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UserDashboardNavigation(
              selectedCategory: _selectedCategory!,
            ),
          ),
        );
      }
    }
  }

  Color _baseColorForCategory(String category) {
    final v = category.toLowerCase().trim();
    if (v == 'business permit fees' || v.contains('business permit')) {
      return const Color(0xFFFF9800); // Orange
    }
    if (v == 'inspection fees' || v.contains('inspection')) {
      return const Color(0xFF8E24AA); // Violet
    }
    if (v == 'other economic enterprises' || v.contains('other economic')) {
      return const Color(0xFFFFEB3B); // Yellow
    }
    if (v == 'other service income' || v.contains('other service')) {
      return const Color(0xFF9E9E9E); // Gray
    }
    if (v == 'parking and terminal fees' || v.contains('parking and terminal')) {
      return const Color(0xFFEC407A); // Pink
    }
    if (v == 'amusement tax/' ||
        v == 'amusement tax' ||
        v.contains('amusement tax')) {
      return const Color(0xFF9ACD32); // Yellow-green
    }
    if (v.contains('marine') || v.contains('fish') || v.contains('sea')) {
      return const Color(0xFF2E7D32); // Green
    }
    if (v.contains('slaughter') || v.contains('katayan')) {
      return const Color(0xFFD32F2F); // Red
    }
    if (v.contains('rent') || v.contains('rental')) {
      return const Color(0xFF2E7D32); // Green
    }
    if (v.contains('market') && v.contains('operation')) {
      return const Color(0xFFEF6C00); // Orange
    }
    return const Color(0xFF455A64); // Default blue-grey
  }

  Color _colorForCategory(String category) {
    final base = HSLColor.fromColor(_baseColorForCategory(category));
    return base.withSaturation(0.50).withLightness(0.84).toColor();
  }

  Color _primaryColorForCategory(String category) {
    return _baseColorForCategory(category);
  }

  Color _accentColorForCategory(String category) {
    final base = HSLColor.fromColor(_baseColorForCategory(category));
    return base.withSaturation(0.78).withLightness(0.64).toColor();
  }

  String _iconForCategory(String category) {
    final v = category.toLowerCase().trim();
    if (v.contains('slaughter') || v.contains('katayan')) {
      return 'assets/dinner.png';
    }
    if (v.contains('rent') || v.contains('rental')) {
      return 'assets/lunch.png';
    }
    return 'assets/breakfast.png';
  }

  String _descriptionForCategory(String category) {
    final v = category.toLowerCase().trim();
    if (v.contains('slaughter') || v.contains('katayan')) {
      return 'Meat and slaughterhouse operations';
    }
    if (v.contains('rent') || v.contains('rental')) {
      return 'Rental and property operations';
    }
    if (v.contains('fish') || v.contains('marine') || v.contains('sea')) {
      return 'Marine and fisheries operations';
    }
    return 'Government operation category';
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final client = Supabase.instance.client;
      final natureRows = await client.from('receipt_natures').select('category');
      final receiptRows = await client.from('receipts').select('category');

      final seen = <String>{};
      final ordered = <String>[];

      void addCategory(dynamic raw) {
        final c = (raw ?? '').toString().trim();
        if (c.isEmpty) return;
        final key = c.toLowerCase();
        if (seen.add(key)) ordered.add(c);
      }

      for (final row in List<Map<String, dynamic>>.from(natureRows)) {
        addCategory(row['category']);
      }
      for (final row in List<Map<String, dynamic>>.from(receiptRows)) {
        addCategory(row['category']);
      }

      if (ordered.isEmpty) {
        ordered.addAll(CategoryConstants.categories);
      } else {
        ordered.sort();
      }

      final categories = ordered
          .map((c) => <String, dynamic>{
                'title': c,
                'description': _descriptionForCategory(c),
                'color': _colorForCategory(c),
                'primaryColor': _primaryColorForCategory(c),
                'accentColor': _accentColorForCategory(c),
                'icon': _iconForCategory(c),
              })
          .toList();

      if (!mounted) return;
      setState(() {
        _categories = categories;
        _currentPage = 0;
        _selectedCategory = _categories.first['title'] as String;
        _backgroundColor = _categories.first['color'] as Color;
        _isLoadingCategories = false;
      });
    } catch (_) {
      final categories = CategoryConstants.categories
          .map((c) => <String, dynamic>{
                'title': c,
                'description': _descriptionForCategory(c),
                'color': _colorForCategory(c),
                'primaryColor': _primaryColorForCategory(c),
                'accentColor': _accentColorForCategory(c),
                'icon': _iconForCategory(c),
              })
          .toList();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _currentPage = 0;
        _selectedCategory = _categories.first['title'] as String;
        _backgroundColor = _categories.first['color'] as Color;
        _isLoadingCategories = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;
        final isNarrow = screenW < 700;
        final isShort = screenH < 700;
        final horizontalPadding = isNarrow ? 14.0 : 24.0;
        final titleSize = isNarrow ? 22.0 : 28.0;
        final subtitleSize = isNarrow ? 14.0 : 16.0;
        final buttonHeight = isNarrow ? 54.0 : 60.0;
        final cardWidth = isNarrow
            ? (screenW - (horizontalPadding * 2) - 28).clamp(220.0, 360.0)
            : 320.0;
        return Scaffold(
          backgroundColor: _backgroundColor,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, color: Colors.blue[800]),
                  ),
                  SizedBox(height: isShort ? 8 : 16),
                  Text(
                    'Select Operation Category',
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose your government operation category',
                    style: TextStyle(
                      fontSize: subtitleSize,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: isShort ? 18 : 28),
                  Expanded(
                    child: _isLoadingCategories
                        ? const Center(child: CircularProgressIndicator())
                        : AnimatedBuilder(
                            animation: _pageController,
                            builder: (context, _) {
                              final page = _pageController.hasClients
                                  ? (_pageController.page ?? _currentPage.toDouble())
                                  : _currentPage.toDouble();
                              return PageView.builder(
                                controller: _pageController,
                                padEnds: true,
                                itemCount: _categories.length,
                                onPageChanged: (index) {
                                  setState(() {
                                    _currentPage = index;
                                    _selectedCategory =
                                        _categories[index]['title'];
                                    _backgroundColor = _categories[index]['color'];
                                  });
                                },
                                itemBuilder: (context, index) {
                                  final categoryData = _categories[index];
                                  final distance = (page - index).abs();
                                  final t = distance.clamp(0.0, 1.0).toDouble();
                                  final scale = 1.0 - (0.20 * t);
                                  final opacity = 1.0 - (0.42 * t);
                                  final verticalShift = 24.0 * t;
                                  final rotateY = (page - index) * 0.24;
                                  final isCenter = distance < 0.5;

                                  return Opacity(
                                    opacity: opacity.clamp(0.50, 1.0).toDouble(),
                                    child: Transform(
                                      alignment: Alignment.center,
                                      transform: Matrix4.identity()
                                        ..setEntry(3, 2, 0.0012)
                                        ..translate(0.0, verticalShift)
                                        ..rotateY(rotateY),
                                      child: Transform.scale(
                                        scale: scale.clamp(0.80, 1.0).toDouble(),
                                        child: Align(
                                          child: _buildCategoryCard(
                                            categoryData,
                                            isCenter,
                                            cardWidth,
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
                  SizedBox(height: isShort ? 16 : 24),
                  _buildPageIndicator(),
                  SizedBox(height: isShort ? 16 : 28),
                  ElevatedButton(
                    onPressed:
                        _selectedCategory != null ? _navigateToDashboard : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _categories.isEmpty
                          ? const Color(0xFF1E3A5F)
                          : _categories[_currentPage]['primaryColor'],
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      minimumSize: Size(double.infinity, buttonHeight),
                    ),
                    child: Text(
                      'Continue to Dashboard',
                      style: TextStyle(
                        fontSize: isNarrow ? 16 : 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryCard(
    Map<String, dynamic> categoryData,
    bool isSelected,
    double cardWidth,
  ) {
    final Color primary = categoryData['primaryColor'];
    final Color bgColor = categoryData['color'];
    final Color accent = (categoryData['accentColor'] as Color?) ??
        primary.withValues(alpha: 0.8);
    final double circleSize = 84;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: SizedBox(
        width: cardWidth,
        child: Stack(
          children: <Widget>[
            Positioned(
              top: 50,
              left: 16,
              right: 12,
              bottom: 8,
              child: Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateZ(-0.028),
                alignment: Alignment.center,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      bottomRight: Radius.circular(14.0),
                      bottomLeft: Radius.circular(14.0),
                      topLeft: Radius.circular(14.0),
                      topRight: Radius.circular(56.0),
                    ),
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.45),
                        primary.withValues(alpha: 0.16),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: primary.withValues(alpha: 0.48),
                        offset: const Offset(0, 24),
                        blurRadius: 34,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateX(isSelected ? 0.045 : 0.032)
                ..rotateY(isSelected ? -0.02 : -0.012),
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.only(
                    top: 32, left: 8, right: 8, bottom: 16),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(8.0),
                    bottomLeft: Radius.circular(8.0),
                    topLeft: Radius.circular(8.0),
                    topRight: Radius.circular(54.0),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          bottomRight: Radius.circular(8.0),
                          bottomLeft: Radius.circular(8.0),
                          topLeft: Radius.circular(8.0),
                          topRight: Radius.circular(54.0),
                        ),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.72),
                          width: 1.25,
                        ),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.95),
                            bgColor.withValues(alpha: 0.88),
                            accent.withValues(alpha: 0.24),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: primary.withValues(alpha: 0.46),
                            offset: const Offset(0, 20),
                            blurRadius: 36,
                          ),
                          const BoxShadow(
                            color: Colors.white70,
                            offset: Offset(-3, -3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(
                            top: 54, left: 16, right: 16, bottom: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              categoryData['title'],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 0.2,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              categoryData['description'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      accent.withValues(alpha: 0.28),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: primary.withValues(alpha: 0.50),
                      offset: const Offset(0, 12),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: Image.asset(
                  categoryData['icon'],
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Selection Indicator
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.34),
                        offset: const Offset(3.0, 3.0),
                        blurRadius: 8.0,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.check_circle,
                      color: primary,
                      size: 20,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    if (_categories.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _categories.map((categoryData) {
        final index = _categories.indexOf(categoryData);
        return AnimatedContainer(
          duration: Duration(milliseconds: 300),
          width: _currentPage == index ? 20 : 8,
          height: 8,
          margin: EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: _currentPage == index
                ? categoryData['primaryColor']
                : Colors.grey[300],
          ),
        );
      }).toList(),
    );
  }
}
