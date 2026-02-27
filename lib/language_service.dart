import 'package:flutter/material.dart';
import 'user_settings_service.dart';

class LanguageService {
  static final ValueNotifier<String> currentLanguage = ValueNotifier('English');

  static Map<String, Map<String, String>> translations = {
    'English': {
      'Dashboard': 'Dashboard',
      'Reports': 'Reports',
      'Manage Receipt': 'Manage Receipt',
      'Nature Entries': 'Nature Entries',
      'Settings': 'Settings',
      'Municipal Financial Dashboard': 'Municipal Financial Dashboard',
      'Daily/Weekly/Yearly': 'Daily/Weekly/Yearly',
      'Financial Overview': 'Financial Overview',
      'Marine Income': 'Marine Income',
      'Slaughter Income': 'Slaughter Income',
      'Rental Income': 'Rental Income',
      'Income Distribution': 'Income Distribution',
      'Income Breakdown Overview': 'Income Breakdown Overview',
      'Export': 'Export',
      'Date': 'Date',
      'Category': 'Category',
      'Amount': 'Amount',
      'Payment': 'Payment',
      'Collecting Officer': 'Collecting Officer',
      'Signature': 'Signature',
      'Enter a valid nature of collection and price.': 'Enter a valid nature of collection and price.',
      'Saved to Supabase.': 'Saved to Supabase.',
      'Failed to save to Supabase:': 'Failed to save to Supabase:',
      'Select an entry first.': 'Select an entry first.',
      'Entry category updated.': 'Entry category updated.',
      'Failed to update entry:': 'Failed to update entry:',
      'Enter a valid nature and price.': 'Enter a valid nature and price.',
      'Entry details updated.': 'Entry details updated.',
      'Failed to update details:': 'Failed to update details:',
      'Save to Database': 'Save to Database',
      'Show Marine': 'Show Marine',
      'Show Slaughter': 'Show Slaughter',
      'Add at least one collection item before saving.': 'Add at least one collection item before saving.',
      'Receipt saved to public.receipts.': 'Receipt saved to public.receipts.',
      'Failed to save receipt:': 'Failed to save receipt:',
      'View Receipts': 'View Receipts',
      'Saving...': 'Saving...',
      'Save to receipts': 'Save to receipts',
      'System Preference': 'System Preference',
      'Language Selection': 'Language Selection',
      'Developers': 'Developers',
      'Receipts': 'Receipts',
      'Add Entries': 'Add Entries',
      'History': 'History',
      'Storage': 'Storage',
      'Recent Transactions': 'Recent Transactions',
      'Filter by Month Range:': 'Filter by Month Range:',
      'Start Month': 'Start Month',
      'End Month': 'End Month',
      'Print All Receipts': 'Print All Receipts',
      'Printing...': 'Printing...',
      'No receipts available to preview.': 'No receipts available to preview.',
      'No receipts available to print.': 'No receipts available to print.',
      'Actual Receipt Preview': 'Actual Receipt Preview',
      'Previous': 'Previous',
      'Next': 'Next',
      'Cancel': 'Cancel',
      'Print All': 'Print All',
      'Unable to generate preview:': 'Unable to generate preview:',
    },
    'Filipino/Tagalog': {
      'Dashboard': 'Dashboard',
      'Reports': 'Mga Ulat',
      'Manage Receipt': 'Pamahalaan ang Resibo',
      'Nature Entries': 'Mga Uri ng Koleksyon',
      'Settings': 'Mga Setting',
      'Municipal Financial Dashboard': 'Dashboard ng Pananalapi ng Munisipyo',
      'Daily/Weekly/Yearly': 'Araw-araw/Pang-linggo/Pang-taon',
      'Financial Overview': 'Pangkalahatang Pananaw sa Pananalapi',
      'Marine Income': 'Kita sa Marine',
      'Slaughter Income': 'Kita sa Slaughter',
      'Rental Income': 'Kita sa Rental',
      'Income Distribution': 'Pamamahagi ng Kita',
      'Income Breakdown Overview': 'Pangkalahatang Pagbabalangkas ng Kita',
      'Export': 'I-export',
      'Date': 'Petsa',
      'Category': 'Kategorya',
      'Amount': 'Halaga',
      'Payment': 'Paraan ng Pagbabayad',
      'Collecting Officer': 'Tagakolekta',
      'Signature': 'Lagda',
      'Enter a valid nature of collection and price.': 'Maglagay ng wastong uri ng koleksyon at presyo.',
      'Saved to Supabase.': 'Nai-save sa Supabase.',
      'Failed to save to Supabase:': 'Hindi na-save sa Supabase:',
      'Select an entry first.': 'Pumili muna ng entry.',
      'Entry category updated.': 'Na-update ang kategorya ng entry.',
      'Failed to update entry:': 'Hindi na-update ang entry:',
      'Enter a valid nature and price.': 'Maglagay ng wastong uri at presyo.',
      'Entry details updated.': 'Na-update ang mga detalye ng entry.',
      'Failed to update details:': 'Hindi na-update ang mga detalye:',
      'Save to Database': 'I-save sa Database',
      'Show Marine': 'Ipakita ang Marina',
      'Show Slaughter': 'Ipakita ang Katayan',
      'Add at least one collection item before saving.': 'Maglagay ng kahit isang item ng koleksyon bago mag-save.',
      'Receipt saved to public.receipts.': 'Nai-save ang resibo sa public.receipts.',
      'Failed to save receipt:': 'Hindi na-save ang resibo:',
      'View Receipts': 'Tingnan ang mga Resibo',
      'Saving...': 'Nagse-save...',
      'Save to receipts': 'I-save sa mga resibo',
      'System Preference': 'System Preference',
      'Language Selection': 'Language Selection',
      'Developers': 'Developers',
      'Receipts': 'Mga Resibo',
      'Add Entries': 'Magdagdag ng Entry',
      'History': 'Kasaysayan',
      'Storage': 'Imbakan',
      'Recent Transactions': 'Mga Kamakailang Transaksyon',
      'Filter by Month Range:': 'I-filter ayon sa Saklaw ng Buwan:',
      'Start Month': 'Simulang Buwan',
      'End Month': 'Huling Buwan',
      'Print All Receipts': 'I-print Lahat ng Resibo',
      'Printing...': 'Nagpi-print...',
      'No receipts available to preview.': 'Walang resibo para i-preview.',
      'No receipts available to print.': 'Walang resibo para i-print.',
      'Actual Receipt Preview': 'Aktwal na Preview ng Resibo',
      'Previous': 'Nakaraan',
      'Next': 'Susunod',
      'Cancel': 'Kanselahin',
      'Print All': 'I-print Lahat',
      'Unable to generate preview:': 'Hindi mabuo ang preview:',
    },
  };

  static String translate(String key) {
    final language = currentLanguage.value;
    return translations[language]?[key] ?? key;
  }

  static Widget translateWidget(String key, {TextStyle? style}) {
    return ValueListenableBuilder<String>(
      valueListenable: currentLanguage,
      builder: (context, language, child) {
        return Text(translate(key), style: style);
      },
    );
  }

  static void setLanguage(String language) {
    if (translations.containsKey(language)) {
      currentLanguage.value = language;
    } else {
      currentLanguage.value = 'English';
    }
  }

  static Future<void> initialize() async {
    try {
      final saved = await UserSettingsService.fetchSettings();
      final dbLanguage = (saved?['language'] ?? 'English').toString();
      setLanguage(dbLanguage);
    } catch (_) {
      setLanguage('English');
    }
  }
}
