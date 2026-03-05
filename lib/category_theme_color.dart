import 'package:flutter/material.dart';

String _normalizedCategoryText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

Color categoryThemeColor(String category) {
  final v = _normalizedCategoryText(category);
  final colorMap = <String, Color>{
    _normalizedCategoryText('A. INTERNAL REVENUE ALLOTMENT'):
        const Color(0xFF1E3A8A),
    _normalizedCategoryText('A. REGULATORY FEES (Permits and Licenses)'):
        const Color(0xFF059669),
    _normalizedCategoryText('A. SPECIAL EDUCATION TAX'):
        const Color(0xFF7C3AED),
    _normalizedCategoryText('B. OTHER SHARES FROM NATIONAL TAX COLLECTIONS'):
        const Color(0xFFEA580C),
    _normalizedCategoryText('B. SERVICE/USER CHARGES (Service Income)'):
        const Color(0xFFD97706),
    _normalizedCategoryText('B. TAX ON BUSINESS'): const Color(0xFFDC2626),
    _normalizedCategoryText('C. EXTRAORDINARY RECEIPTS/DONATIONS/AIDS'):
        const Color(0xFF0EA5E9),
    _normalizedCategoryText('C. OTHER TAXES'): const Color(0xFF92400E),
    _normalizedCategoryText(
            'C. RECEIPTS FROM ECONOMIC ENTERPRISES (Business Income)'):
        const Color(0xFFDB2777),
    _normalizedCategoryText('D. INTER-LOCAL TRANSFER'): const Color(0xFF374151),
    _normalizedCategoryText('D. OTHER INCOME/ RECEIPTS (Other General Income)'):
        const Color(0xFF65A30D),
    _normalizedCategoryText('E. CAPITAL/INVESTMENT RECEIPTS'):
        const Color(0xFF0F766E),
    _normalizedCategoryText('F. RECEIPTS FROM LOAN AND BORROWINGS (PAYABLE)'):
        const Color(0xFF4F46E5),
    _normalizedCategoryText('G. OTHER NON-INCOME RECEIPTS'):
        const Color(0xFF525252),
    _normalizedCategoryText('marine'): const Color(0xFF2E7D32),
    _normalizedCategoryText('slaughter'): const Color(0xFFD32F2F),
    _normalizedCategoryText('rent'): const Color(0xFF388E3C),
    _normalizedCategoryText('business permit fees'): const Color(0xFFFF9800),
    _normalizedCategoryText('inspection fees'): const Color(0xFF8E24AA),
    _normalizedCategoryText('other economic enterprises'):
        const Color(0xFFF57C00),
    _normalizedCategoryText('other service income'): const Color(0xFF546E7A),
  };
  return colorMap[v] ?? const Color(0xFF1E3A5F);
}
