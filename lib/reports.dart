import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reciept.dart';
import 'language_service.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        elevation: 0,
        title: Text(
          LanguageService.translate("Municipal Financial Dashboard"),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 25),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: Text(LanguageService.translate("Export")),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1E3A5F),
              ),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 50, vertical: 40),
        child: _RealReportContent(),
      ),
    );
  }
}

class _RealReportContent extends StatefulWidget {
  const _RealReportContent();

  @override
  State<_RealReportContent> createState() => _RealReportContentState();
}

class _RealReportContentState extends State<_RealReportContent> {
  bool isLoading = false;
  bool isPrintingAll = false;
  List<Map<String, dynamic>> allRows = [];
  List<String> months = [];
  String? startMonth;
  String? endMonth;
  String _selectedCategoryFilter = 'All';
  bool _isExportingCategory = false;
  final TextEditingController _natureSearchController = TextEditingController();
  String _natureSearch = '';
  int _natureSortColumnIndex = 2;
  bool _natureSortAscending = false;

  @override
  void initState() {
    super.initState();
    _loadRows();
  }

  @override
  void dispose() {
    _natureSearchController.dispose();
    super.dispose();
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

    final items = row['collection_items'];
    if (items is List) {
      return items.fold<double>(0.0, (sum, item) {
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

  Future<void> _loadRows() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final client = Supabase.instance.client;
      List<Map<String, dynamic>> data = [];
      try {
        final logs = await client
            .from('receipt_print_logs')
            .select(
              'id, serial_no, category, marine_flow, printed_at, receipt_date, payor, officer, total_amount, collection_items, nature_code, payment_method',
            )
            .order('printed_at', ascending: false);
        data = List<Map<String, dynamic>>.from(logs);
      } catch (_) {
        data = [];
      }

      if (data.isEmpty) {
        try {
          final receipts = await client
              .from('receipts')
              .select('*')
              .order('saved_at', ascending: false);
          data = List<Map<String, dynamic>>.from(receipts);
        } catch (_) {
          data = [];
        }
      }
      if (!mounted) return;

      final rows = List<Map<String, dynamic>>.from(data).map((row) {
        final normalizedDate = _extractDate(row);
        return <String, dynamic>{
          ...row,
          // Normalize print-log row keys for existing table/preview UI
          'saved_at': normalizedDate,
          'printed_at': normalizedDate,
          'price': _extractAmount(row),
          'total_amount': _extractAmount(row),
          'nature_of_collection':
              _firstNatureFromItems(row['collection_items']),
        };
      }).toList();
      final monthSet = <String>{};
      for (final row in rows) {
        final dt = DateTime.tryParse((row['saved_at'] ?? '').toString());
        if (dt != null) {
          monthSet.add('${_monthName(dt.month)} ${dt.year}');
        }
      }
      final sortedMonths = monthSet.toList()
        ..sort((a, b) => _parseMonth(b).compareTo(_parseMonth(a)));

      setState(() {
        allRows = rows;
        months = sortedMonths;
        if (months.isNotEmpty) {
          startMonth ??= months.last;
          endMonth ??= months.first;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        allRows = [];
        months = [];
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  DateTime _parseMonth(String monthYear) {
    final parts = monthYear.split(' ');
    return DateTime(int.parse(parts[1]), _monthToNumber(parts[0]));
  }

  int _monthToNumber(String month) {
    const values = {
      'January': 1,
      'February': 2,
      'March': 3,
      'April': 4,
      'May': 5,
      'June': 6,
      'July': 7,
      'August': 8,
      'September': 9,
      'October': 10,
      'November': 11,
      'December': 12,
    };
    return values[month] ?? 1;
  }

  String _monthName(int month) {
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
    return names[month - 1];
  }

  List<Map<String, dynamic>> get filteredRows {
    if (startMonth == null || endMonth == null) return allRows;
    final start = _parseMonth(startMonth!);
    final end = _parseMonth(endMonth!);
    return allRows.where((row) {
      final dt = DateTime.tryParse((row['saved_at'] ?? '').toString());
      if (dt == null) return false;
      final reportMonth = DateTime(dt.year, dt.month);
      final inMonth = reportMonth.isAfter(start.subtract(const Duration(days: 1))) &&
          reportMonth.isBefore(end.add(const Duration(days: 31)));
      if (!inMonth) return false;
      if (_selectedCategoryFilter == 'All') return true;
      final category = (row['category'] ?? '').toString().trim();
      return category == _selectedCategoryFilter;
    }).toList();
  }

  List<String> get _categoryOptions {
    final set = <String>{'All'};
    for (final row in allRows) {
      final category = (row['category'] ?? '').toString().trim();
      if (category.isNotEmpty) set.add(category);
    }
    final list = set.toList();
    if (list.length > 1) {
      final body = list.where((e) => e != 'All').toList()..sort();
      return ['All', ...body];
    }
    return list;
  }

  double _resolveAmount(Map<String, dynamic> row) {
    final printTotal = (row['total_amount'] as num?)?.toDouble();
    if (printTotal != null) return printTotal;

    final direct = (row['price'] as num?)?.toDouble();
    if (direct != null) return direct;

    final items = row['collection_items'];
    if (items is List) {
      return items.fold<double>(0.0, (sum, item) {
        if (item is Map<String, dynamic>) {
          return sum + ((item['price'] as num?)?.toDouble() ?? 0.0);
        }
        return sum;
      });
    }
    return 0.0;
  }

  Map<String, double> _incomeByCategory() {
    final totals = <String, double>{};
    for (final row in filteredRows) {
      final rawCategory = (row['category'] ?? '').toString().trim();
      final category = rawCategory.isEmpty ? 'Uncategorized' : rawCategory;
      totals[category] = (totals[category] ?? 0.0) + _resolveAmount(row);
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in sorted) e.key: e.value};
  }

  List<_CategoryNatureRow> _natureRowsByCategory() {
    final grouped = <String, double>{};

    for (final row in filteredRows) {
      final rawCategory = (row['category'] ?? '').toString().trim();
      final category = rawCategory.isEmpty ? 'Uncategorized' : rawCategory;
      var hadItem = false;
      final items = row['collection_items'];

      if (items is List) {
        for (final item in items) {
          Map<String, dynamic>? m;
          if (item is Map<String, dynamic>) {
            m = item;
          } else if (item is Map) {
            m = Map<String, dynamic>.from(item);
          }
          if (m == null) continue;
          final nature = (m['nature'] ?? m['nature_of_collection'] ?? '')
              .toString()
              .trim();
          final amount = ((m['price'] as num?)?.toDouble() ?? 0.0) +
              ((m['amount'] as num?)?.toDouble() ?? 0.0);
          if (nature.isEmpty || amount <= 0) continue;
          hadItem = true;
          final key = '$category|||$nature';
          grouped[key] = (grouped[key] ?? 0.0) + amount;
        }
      }

      if (!hadItem) {
        final fallbackNature = (row['nature_of_collection'] ?? '-').toString();
        final amount = _resolveAmount(row);
        if (amount > 0) {
          final key = '$category|||$fallbackNature';
          grouped[key] = (grouped[key] ?? 0.0) + amount;
        }
      }
    }

    final rows = grouped.entries.map((entry) {
      final parts = entry.key.split('|||');
      final category = parts.isNotEmpty ? parts.first : 'Uncategorized';
      final nature = parts.length > 1 ? parts[1] : '-';
      return _CategoryNatureRow(
        category: category,
        nature: nature,
        amount: entry.value,
      );
    }).toList();

    return rows;
  }

  List<_CategoryNatureRow> _displayNatureRows(List<_CategoryNatureRow> source) {
    final q = _natureSearch.trim().toLowerCase();
    final filtered = q.isEmpty
        ? List<_CategoryNatureRow>.from(source)
        : source.where((row) {
            return row.category.toLowerCase().contains(q) ||
                row.nature.toLowerCase().contains(q);
          }).toList();

    filtered.sort((a, b) {
      int cmp;
      switch (_natureSortColumnIndex) {
        case 0:
          cmp = a.category.toLowerCase().compareTo(b.category.toLowerCase());
          break;
        case 1:
          cmp = a.nature.toLowerCase().compareTo(b.nature.toLowerCase());
          break;
        case 2:
        default:
          cmp = a.amount.compareTo(b.amount);
          break;
      }
      return _natureSortAscending ? cmp : -cmp;
    });
    return filtered;
  }

  Widget _buildNatureByCategoryTable(List<_CategoryNatureRow> rows) {
    final displayRows = _displayNatureRows(rows);
    if (displayRows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No matching rows.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD6DEE8)),
          color: Colors.white,
        ),
        child: SizedBox(
          height: 300,
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 34,
                headingRowHeight: 46,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 50,
                sortColumnIndex: _natureSortColumnIndex,
                sortAscending: _natureSortAscending,
                headingRowColor:
                    WidgetStateProperty.all(const Color(0xFFEAF1F8)),
                columns: [
                  DataColumn(
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        _natureSortColumnIndex = columnIndex;
                        _natureSortAscending = ascending;
                      });
                    },
                    label: const Text(
                      'Category',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataColumn(
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        _natureSortColumnIndex = columnIndex;
                        _natureSortAscending = ascending;
                      });
                    },
                    label: const Text(
                      'Nature of Collection',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataColumn(
                    numeric: true,
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        _natureSortColumnIndex = columnIndex;
                        _natureSortAscending = ascending;
                      });
                    },
                    label: const Text(
                      'Amount',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
                rows: List.generate(displayRows.length, (index) {
                  final row = displayRows[index];
                  final striped = index.isOdd;
                  return DataRow.byIndex(
                    index: index,
                    color: WidgetStateProperty.all(
                      striped ? const Color(0xFFF9FBFE) : Colors.white,
                    ),
                    cells: [
                      DataCell(
                        Text(
                          row.category,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(Text(row.nature)),
                      DataCell(
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'PHP ${row.amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportCategoryDataCsv() async {
    if (_isExportingCategory) return;
    final incomeByCategory = _incomeByCategory();
    if (incomeByCategory.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No category data to export.')),
      );
      return;
    }

    setState(() => _isExportingCategory = true);
    try {
      final now = DateTime.now();
      final defaultName =
          'category_report_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Category Report',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (path == null || path.trim().isEmpty) return;

      final buffer = StringBuffer();
      buffer.writeln('category,total_amount');
      incomeByCategory.forEach((category, total) {
        final safeCategory = category.replaceAll('"', '""');
        buffer.writeln('"$safeCategory",${total.toStringAsFixed(2)}');
      });

      final file = File(path);
      await file.writeAsString(buffer.toString(), flush: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Category data exported: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export category data: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExportingCategory = false);
    }
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
    return w.trim();
  }

  Future<Uint8List> _buildAllReceiptsPdfBytes(
      List<Map<String, dynamic>> rows) async {
    final baseFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final boldFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: baseFont,
        bold: boldFont,
      ),
    );

    for (final row in rows) {
      final receiptDate = (row['receipt_date'] ?? '').toString().trim();
      final dt = DateTime.tryParse((row['saved_at'] ?? '').toString());
      final fallbackDate = dt == null
          ? '-'
          : '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}/${(dt.year % 100).toString().padLeft(2, '0')}';
      final dateText = receiptDate.isNotEmpty ? receiptDate : fallbackDate;
      final serialNo = row['serial_no']?.toString().trim();
      final reference =
          serialNo?.isNotEmpty == true ? serialNo! : 'REC-${row['id'] ?? '-'}';
      final category = (row['category'] ?? '-').toString();
      final marineFlow = (row['marine_flow'] ?? '-').toString();
      final payor = (row['payor'] ?? '-').toString();
      final officer = (row['officer'] ?? '-').toString();
      final paymentMethod =
          (row['payment_method'] ?? '').toString().toLowerCase().trim();
      final total = _resolveAmount(row);
      final amountWords = _numberToWords(total);

      final rawItems = row['collection_items'];
      final items = <Map<String, dynamic>>[];
      if (rawItems is List) {
        for (final item in rawItems) {
          if (item is Map<String, dynamic>) {
            items.add(item);
          } else if (item is Map) {
            items.add(Map<String, dynamic>.from(item));
          }
        }
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) {
            final tableItems = items.isEmpty
                ? <Map<String, dynamic>>[
                    {'nature': '-', 'price': 0.0}
                  ]
                : items;

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Center(
                        child: pw.Text(
                          'OFFICIAL RECEIPT',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Date: $dateText'),
                          pw.Text('No.: $reference'),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text('Category: $category'),
                      if (category == 'Marine')
                        pw.Text('Marine Flow: $marineFlow'),
                      pw.SizedBox(height: 6),
                      pw.Text('Received from: $payor'),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'Nature of Collection',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Table(
                        border: pw.TableBorder.all(width: 0.6),
                        columnWidths: const {
                          0: pw.FlexColumnWidth(4),
                          1: pw.FlexColumnWidth(2),
                        },
                        children: [
                          pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(
                                  'Nature',
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(
                                  'Amount',
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          ...tableItems.map((item) {
                            final nature = (item['nature'] ??
                                    item['nature_of_collection'] ??
                                    '-')
                                .toString();
                            final amount =
                                (item['price'] as num?)?.toDouble() ?? 0.0;
                            return pw.TableRow(
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text(nature),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text(amount.toStringAsFixed(2)),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                      pw.SizedBox(height: 10),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Amount in words: $amountWords'),
                          pw.Text(
                            'TOTAL: PHP ${total.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 10),
                      pw.Row(
                        children: [
                          pw.Text(
                            '[${paymentMethod == 'cash' ? 'x' : ' '}] Cash   '
                            '[${paymentMethod == 'check' ? 'x' : ' '}] Check   '
                            '[${paymentMethod == 'money' ? 'x' : ' '}] Money Order',
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 22),
                      pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Column(
                          children: [
                            pw.Container(
                                width: 200, height: 1, color: PdfColors.black),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              officer.isEmpty || officer == '-'
                                  ? 'Collecting Officer'
                                  : officer,
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                            pw.Text('Collecting Officer'),
                          ],
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

    return pdf.save();
  }

  Future<void> _printPdfBytes(Uint8List bytes) async {
    try {
      await Printing.layoutPdf(onLayout: (format) async => bytes);
    } on MissingPluginException {
      final tempDir = Directory.systemTemp;
      final filePath =
          '${tempDir.path}\\all_receipts_${DateTime.now().millisecondsSinceEpoch}.pdf';
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
  }

  Future<void> _showPrintAllPreview() async {
    final rows = filteredRows;
    if (rows.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(LanguageService.translate(
                'No receipts available to preview.'))),
      );
      return;
    }

    setState(() => isPrintingAll = true);
    Uint8List previewBytes;
    try {
      previewBytes = await _buildAllReceiptsPdfBytes(rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => isPrintingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${LanguageService.translate('Unable to generate preview:')} $e')),
      );
      return;
    } finally {
      if (mounted) {
        setState(() => isPrintingAll = false);
      }
    }

    if (!mounted) return;
    int currentPage = 0;
    final pageController = PageController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(18),
              child: SizedBox(
                width: 1180,
                height: 780,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      color: const Color(0xFF1E3A5F),
                      child: Text(
                        '${LanguageService.translate('Actual Receipt Preview')} (${currentPage + 1}/${rows.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: pageController,
                        itemCount: rows.length,
                        onPageChanged: (index) {
                          setDialogState(() => currentPage = index);
                        },
                        itemBuilder: (_, index) {
                          return Padding(
                            padding: const EdgeInsets.all(10),
                            child: ReceiptScreen(
                              receiptData: rows[index],
                              readOnly: true,
                              showSaveButton: false,
                              showViewReceiptsButton: false,
                              showPrintButton: false,
                              useFullWidth: true,
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: currentPage > 0
                                ? () {
                                    pageController.previousPage(
                                      duration:
                                          const Duration(milliseconds: 220),
                                      curve: Curves.easeOut,
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_left),
                            label: Text(LanguageService.translate('Previous')),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: currentPage < rows.length - 1
                                ? () {
                                    pageController.nextPage(
                                      duration:
                                          const Duration(milliseconds: 220),
                                      curve: Curves.easeOut,
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_right),
                            label: Text(LanguageService.translate('Next')),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: Text(LanguageService.translate('Cancel')),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: isPrintingAll
                                ? null
                                : () async {
                                    Navigator.of(dialogContext).pop();
                                    setState(() => isPrintingAll = true);
                                    try {
                                      await _printPdfBytes(previewBytes);
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(this.context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Failed to print receipts: $e')),
                                      );
                                    } finally {
                                      if (mounted) {
                                        setState(() => isPrintingAll = false);
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.print),
                            label: Text(LanguageService.translate('Print All')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A5F),
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
      },
    );
    pageController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mainChildren = <Widget>[
      const _GlassPanel(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Office of the Municipal Treasurer",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text("Transaction Monitoring Report", style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
      const SizedBox(height: 30),
      _GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              LanguageService.translate("Filter by Month Range:"),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            _monthDropdown(
              value: startMonth,
              hint: LanguageService.translate('Start Month'),
              onChanged: (v) => setState(() => startMonth = v),
            ),
            const Text("-"),
            _monthDropdown(
              value: endMonth,
              hint: LanguageService.translate('End Month'),
              onChanged: (v) => setState(() => endMonth = v),
            ),
            Text(
              LanguageService.translate("Category:"),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            _monthDropdown(
              value: _selectedCategoryFilter,
              hint: 'Category',
              onChanged: (v) {
                if (v == null) return;
                setState(() => _selectedCategoryFilter = v);
              },
              itemsOverride: _categoryOptions,
            ),
          ],
        ),
      ),
      const SizedBox(height: 25),
      _GlassPanel(
        padding: const EdgeInsets.all(16),
        child: Builder(
          builder: (context) {
            final incomeByCategory = _incomeByCategory();
            final natureRows = _natureRowsByCategory();
            if (incomeByCategory.isEmpty && natureRows.isEmpty) {
              return const Text(
                'No income data for selected filters.',
                style: TextStyle(color: Colors.black54),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Income by Category',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          _isExportingCategory ? null : _exportCategoryDataCsv,
                      icon: _isExportingCategory
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download, size: 18),
                      label: Text(
                        _isExportingCategory
                            ? 'Exporting...'
                            : 'Export Category Data',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _natureSearchController,
                  onChanged: (value) {
                    setState(() => _natureSearch = value);
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'Search category or nature',
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF7FAFE),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD6DEE8)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD6DEE8)),
                    ),
                    suffixIcon: _natureSearch.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            onPressed: () {
                              _natureSearchController.clear();
                              setState(() => _natureSearch = '');
                            },
                            icon: const Icon(Icons.close, size: 18),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildNatureByCategoryTable(natureRows),
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Text(
              LanguageService.translate("Recent Transactions"),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton.icon(
            onPressed: (isLoading || isPrintingAll || filteredRows.isEmpty)
                ? null
                : _showPrintAllPreview,
            icon: isPrintingAll
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print),
            label: Text(
              isPrintingAll
                  ? LanguageService.translate('Printing...')
                  : LanguageService.translate('Print All Receipts'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
      const SizedBox(height: 15),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactHeight = constraints.maxHeight < 900;
        if (compactHeight) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...mainChildren,
                SizedBox(
                  height: 360,
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _RealReportTable(filteredRows),
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...mainChildren,
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _RealReportTable(filteredRows),
            ),
          ],
        );
      },
    );
  }

  Widget _monthDropdown({
    required String? value,
    required String hint,
    required ValueChanged<String?> onChanged,
    List<String>? itemsOverride,
  }) {
    final items = itemsOverride ?? months;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFBFC9D4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint),
          items: items
              .map((m) => DropdownMenuItem<String>(value: m, child: Text(m)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  String? _firstNatureFromItems(dynamic items) {
    if (items is! List || items.isEmpty) return null;
    final first = items.first;
    if (first is Map<String, dynamic>) {
      final nature = (first['nature'] ?? first['nature_of_collection'] ?? '')
          .toString()
          .trim();
      return nature.isEmpty ? null : nature;
    }
    return null;
  }
}

class _CategoryNatureRow {
  final String category;
  final String nature;
  final double amount;

  const _CategoryNatureRow({
    required this.category,
    required this.nature,
    required this.amount,
  });
}

class _RealReportTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _RealReportTable(this.rows);

  double _resolveAmount(Map<String, dynamic> row) {
    final printTotal = (row['total_amount'] as num?)?.toDouble();
    if (printTotal != null) return printTotal;

    final direct = (row['price'] as num?)?.toDouble();
    if (direct != null) return direct;

    final items = row['collection_items'];
    if (items is List) {
      return items.fold<double>(0.0, (sum, item) {
        if (item is Map<String, dynamic>) {
          return sum + ((item['price'] as num?)?.toDouble() ?? 0.0);
        }
        return sum;
      });
    }
    return 0.0;
  }

  String _resolveNature(Map<String, dynamic> row) {
    final savedNature = (row['nature_of_collection'] ?? '').toString().trim();
    if (savedNature.isNotEmpty) return savedNature;

    final items = row['collection_items'];
    if (items is List && items.isNotEmpty) {
      final first = items.first;
      if (first is Map<String, dynamic>) {
        final nature = (first['nature'] ?? '').toString().trim();
        if (nature.isNotEmpty) return nature;
      }
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 30,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFEAF1F8)),
            columns: const [
              DataColumn(label: Text("Petsa")),
              DataColumn(label: Text("Kategorya")),
              DataColumn(label: Text("Reference No.")),
              DataColumn(label: Text("Nature")),
              DataColumn(label: Text("Marine Flow")),
              DataColumn(label: Text("Halaga")),
              DataColumn(label: Text("Receipt")),
            ],
            rows: rows.map((row) {
              final dt = DateTime.tryParse((row['saved_at'] ?? '').toString());
              final dateText = dt == null
                  ? "-"
                  : "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
              final amount = _resolveAmount(row);
              final serialNo = row['serial_no']?.toString().trim();
              return DataRow(
                cells: [
                  DataCell(Text(dateText)),
                  DataCell(Text((row['category'] ?? '-').toString())),
                  DataCell(Text(serialNo?.isNotEmpty == true
                      ? serialNo!
                      : "REC-${row['id'] ?? '-'}")),
                  DataCell(Text(_resolveNature(row))),
                  DataCell(Text((row['marine_flow'] ?? '-').toString())),
                  DataCell(Text(
                    "PHP ${amount.toStringAsFixed(2)}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )),
                  DataCell(
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReceiptScreen(
                              receiptData: row,
                              readOnly: true,
                              showSaveButton: false,
                              showViewReceiptsButton: false,
                              showPrintButton: false,
                              useFullWidth: true,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text("View"),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _ReportContent extends StatefulWidget {
  const _ReportContent();

  @override
  State<_ReportContent> createState() => _ReportContentState();
}

class _ReportContentState extends State<_ReportContent> {
  final List<Map<String, String>> allReports = [
    {
      "date": "2026-02-20",
      "category": "Marine",
      "ref": "REF-001",
      "amount": "₱1,500.00",
      "payment": "Cash",
      "officer": "Juan Dela Cruz",
    },
    {
      "date": "2026-02-20",
      "category": "Slaughter",
      "ref": "REF-002",
      "amount": "₱500.00",
      "payment": "Check",
      "officer": "Maria Santos",
    },
    {
      "date": "2026-02-19",
      "category": "Rental",
      "ref": "REF-003",
      "amount": "₱10,000.00",
      "payment": "Money Order",
      "officer": "Carlos Reyes",
    },
  ];

  String? startMonth;
  String? endMonth;

  final List<String> availableMonths = [
    "October 2025",
    "November 2025",
    "December 2025",
    "January 2026",
    "February 2026",
  ];

  DateTime _parseMonth(String monthYear) {
    final parts = monthYear.split(" ");
    final month = _monthToNumber(parts[0]);
    final year = int.parse(parts[1]);
    return DateTime(year, month);
  }

  int _monthToNumber(String month) {
    const months = {
      "January": 1,
      "February": 2,
      "March": 3,
      "April": 4,
      "May": 5,
      "June": 6,
      "July": 7,
      "August": 8,
      "September": 9,
      "October": 10,
      "November": 11,
      "December": 12,
    };
    return months[month]!;
  }

  List<Map<String, String>> get filteredReports {
    if (startMonth == null || endMonth == null) return allReports;

    DateTime start = _parseMonth(startMonth!);
    DateTime end = _parseMonth(endMonth!);

    return allReports.where((report) {
      DateTime reportDate = DateTime.parse(report["date"]!);
      DateTime reportMonth = DateTime(reportDate.year, reportDate.month);
      return reportMonth.isAfter(start.subtract(const Duration(days: 1))) &&
          reportMonth.isBefore(end.add(const Duration(days: 31)));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOfficialHeader(),
        const SizedBox(height: 30),

        // MONTH RANGE FILTER
        _GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              const Text(
                "Filter by Month Range:",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 20),
              _buildDropdown(
                value: startMonth,
                hint: "Start Month",
                onChanged: (value) {
                  setState(() => startMonth = value);
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text("-", style: TextStyle(fontSize: 18)),
              ),
              _buildDropdown(
                value: endMonth,
                hint: "End Month",
                onChanged: (value) {
                  setState(() => endMonth = value);
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 25),

        const Text(
          "Recent Transactions",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 15),

        Expanded(
          child: _ReportTable(filteredReports),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFBFC9D4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint),
          items: availableMonths
              .map((month) => DropdownMenuItem(
                    value: month,
                    child: Text(month),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildOfficialHeader() {
    return const _GlassPanel(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Office of the Municipal Treasurer",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            "Transaction Monitoring Report",
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 10),
          Divider(),
          SizedBox(height: 6),
          Text(
            "Generated Date: February 21, 2026",
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _ReportTable extends StatelessWidget {
  final List<Map<String, String>> reports;

  const _ReportTable(this.reports);

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 40,
          headingRowColor: WidgetStateProperty.all(const Color(0xFFEAF1F8)),
          columns: const [
            DataColumn(label: Text("Petsa")),
            DataColumn(label: Text("Kategorya")),
            DataColumn(label: Text("Reference No.")),
            DataColumn(label: Text("Halaga")),
            DataColumn(label: Text("Paraan ng Pagbabayad")),
            DataColumn(label: Text("Tagakolekta")),
            DataColumn(label: Text("Lagda")),
          ],
          rows: reports.map((report) {
            return DataRow(
              cells: [
                DataCell(Text(report["date"]!)),
                DataCell(Text(report["category"]!)),
                DataCell(Text(
                  report["ref"]!,
                  style: const TextStyle(
                    color: Color(0xFF1E3A5F),
                    fontWeight: FontWeight.w600,
                  ),
                )),
                DataCell(Text(
                  report["amount"]!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )),
                DataCell(
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      report["payment"]!,
                      style: const TextStyle(
                        color: Color(0xFF1E3A5F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(
                  report["officer"]!,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                )),
                DataCell(
                  Container(
                    width: 120,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFBFC9D4)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class ManageReceiptPage extends StatefulWidget {
  const ManageReceiptPage({super.key});

  @override
  State<ManageReceiptPage> createState() => _ManageReceiptPageState();
}

class _ManageReceiptPageState extends State<ManageReceiptPage> {
  String _selectedCategory = "Marine";
  String _selectedMarineFlow = "Incoming";
  final TextEditingController _collectionNameController =
      TextEditingController();
  final TextEditingController _collectionPriceController =
      TextEditingController();
  final TextEditingController _editNatureController = TextEditingController();
  final TextEditingController _editPriceController = TextEditingController();
  String _editCategory = "Marine";
  String _editMarineFlow = "Incoming";
  List<Map<String, dynamic>> _editEntries = [];
  String? _selectedEditEntryId;
  bool _isLoadingEntries = false;

  @override
  void initState() {
    super.initState();
    _loadEntriesForEdit();
  }

  @override
  void dispose() {
    _collectionNameController.dispose();
    _collectionPriceController.dispose();
    _editNatureController.dispose();
    _editPriceController.dispose();
    super.dispose();
  }

  Future<void> _addCollectionToReceipt() async {
    final nature = _collectionNameController.text.trim();
    final amount = double.tryParse(_collectionPriceController.text.trim());

    if (nature.isEmpty || amount == null || amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Maglagay ng wastong uri ng koleksyon at presyo."),
          backgroundColor: Color(0xFFB3261E),
        ),
      );
      return;
    }

    try {
      await _saveCollectionToSupabase(
        nature: nature,
        amount: amount,
      );
      setState(() {
        _editCategory = _selectedCategory;
        if (_selectedCategory == "Marine") {
          _editMarineFlow = _selectedMarineFlow;
        }
      });
      await _loadEntriesForEdit();
      if (!mounted) return;
      _collectionNameController.clear();
      _collectionPriceController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Nai-save sa Supabase."),
          backgroundColor: Color(0xFF1E3A5F),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Hindi na-save sa Supabase: $e"),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
    }
  }

  Future<void> _updateEntryCategory() async {
    final id = _selectedEditEntryId;
    if (id == null || id.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pumili muna ng entry."),
          backgroundColor: Color(0xFFB3261E),
        ),
      );
      return;
    }

    try {
      final client = Supabase.instance.client;
      await client.from("receipts").update({
        "category": _editCategory,
        "marine_flow": _editCategory == "Marine" ? _editMarineFlow : null,
      }).eq("id", id);
      await _loadEntriesForEdit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Na-update ang kategorya ng entry."),
          backgroundColor: Color(0xFF1E3A5F),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Hindi na-update ang entry: $e"),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
    }
  }

  Future<void> _updateEntryDetails() async {
    final id = _selectedEditEntryId;
    if (id == null || id.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Select an entry first."),
          backgroundColor: Color(0xFFB3261E),
        ),
      );
      return;
    }

    final nature = _editNatureController.text.trim();
    final amount = double.tryParse(_editPriceController.text.trim());

    if (nature.isEmpty || amount == null || amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Maglagay ng wastong uri at presyo."),
          backgroundColor: Color(0xFFB3261E),
        ),
      );
      return;
    }

    try {
      final client = Supabase.instance.client;
      await client.from("receipts").update({
        "nature_of_collection": nature,
        "collection_price": amount,
        "collection_items": [
          {"nature": nature, "price": amount}
        ],
      }).eq("id", id);

      await _loadEntriesForEdit();
      _syncEditFieldsFromSelection();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Na-update ang mga detalye ng entry."),
          backgroundColor: Color(0xFF1E3A5F),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Hindi na-update ang mga detalye: $e"),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
    }
  }

  void _syncEditFieldsFromSelection() {
    if (_selectedEditEntryId == null || _selectedEditEntryId!.isEmpty) {
      _editNatureController.clear();
      _editPriceController.clear();
      return;
    }

    final match = _editEntries.where(
      (e) => (e["id"] ?? "").toString() == _selectedEditEntryId,
    );
    if (match.isEmpty) {
      _editNatureController.clear();
      _editPriceController.clear();
      return;
    }

    final entry = match.first;
    _editNatureController.text =
        (entry["nature_of_collection"] ?? "").toString();
    _editPriceController.text = (entry["collection_price"] ?? "").toString();
  }

  Future<void> _loadEntriesForEdit() async {
    setState(() => _isLoadingEntries = true);
    try {
      final client = Supabase.instance.client;
      final query = client
          .from("receipts")
          .select(
            "id, category, marine_flow, nature_of_collection, collection_price, saved_at, html_content, file_name",
          )
          .eq("category", _editCategory);

      final data = _editCategory == "Marine"
          ? await query.eq("marine_flow", _editMarineFlow).order(
                "saved_at",
                ascending: false,
              )
          : await query.order("saved_at", ascending: false);

      if (!mounted) return;
      final rows = List<Map<String, dynamic>>.from(data);
      setState(() {
        _editEntries = rows;
        if (_selectedEditEntryId != null &&
            rows.every((e) => e["id"] != _selectedEditEntryId)) {
          _selectedEditEntryId = null;
        }
      });
      _syncEditFieldsFromSelection();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _editEntries = [];
        _selectedEditEntryId = null;
      });
      _syncEditFieldsFromSelection();
    } finally {
      if (mounted) {
        setState(() => _isLoadingEntries = false);
      }
    }
  }

  Future<void> _saveCollectionToSupabase({
    required String nature,
    required double amount,
  }) async {
    final client = Supabase.instance.client;
    final now = DateTime.now();
    final safeCategory = _selectedCategory.toLowerCase().replaceAll(" ", "_");
    final safeFlow = _selectedMarineFlow.toLowerCase();
    final timestamp =
        now.toIso8601String().replaceAll(":", "-").replaceAll(".", "-");
    final fileName = _selectedCategory == "Marine"
        ? "receipt_${safeCategory}_${safeFlow}_$timestamp.html"
        : "receipt_${safeCategory}_$timestamp.html";
    final receiptSnapshot = """
<h2>Official Receipt</h2>
<p><strong>Category:</strong> $_selectedCategory</p>
<p><strong>Marine Flow:</strong> ${_selectedCategory == "Marine" ? _selectedMarineFlow : "-"}</p>
<p><strong>Nature of Collection:</strong> $nature</p>
<p><strong>Price:</strong> $amount</p>
<p><strong>Saved At:</strong> ${now.toIso8601String()}</p>
""";

    await client.from("receipts").insert({
      "category": _selectedCategory,
      "marine_flow": _selectedCategory == "Marine" ? _selectedMarineFlow : null,
      "file_name": fileName,
      "html_content": receiptSnapshot,
      "saved_at": now.toIso8601String(),
      "nature_of_collection": nature,
      "collection_price": amount,
      "collection_items": [
        {"nature": nature, "price": amount}
      ],
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        title: const Text(
          "Manage Receipt",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildControlPanel(),
              const SizedBox(height: 16),
              _buildEditPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return _GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Manage Receipt",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E3A5F),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "1) Select category 2) Add entry 3) Save to database.",
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 18),
          const Text(
            "Category",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: const [
              DropdownMenuItem(value: "Marine", child: Text("Marina")),
              DropdownMenuItem(value: "Slaughter", child: Text("Katayan")),
              DropdownMenuItem(value: "Rent", child: Text("Renta")),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedCategory = value;
              });
            },
          ),
          if (_selectedCategory == "Marine") ...[
            const SizedBox(height: 16),
            const Text(
              "Marine Type",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _marineFlowButton("Incoming"),
                _marineFlowButton("Outgoing"),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFF8FAFD),
              border: Border.all(color: const Color(0xFFDDE5EF)),
            ),
            child: Text(
              _selectedCategory == "Marine"
                  ? "Active: $_selectedCategory ($_selectedMarineFlow)"
                  : "Active: $_selectedCategory",
              style: const TextStyle(
                color: Color(0xFF1E3A5F),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Add Nature of Collection",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _collectionNameController,
            decoration: InputDecoration(
              labelText: "Nature of Collection",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _collectionPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: "Price",
              prefixText: "PHP ",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addCollectionToReceipt,
              icon: const Icon(Icons.cloud_upload),
              label: const Text("I-save sa Database"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditPanel() {
    return _GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Edit Entry",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E3A5F),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Select category first, add/save entry, then edit or view receipts.",
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _editCategory,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: const [
              DropdownMenuItem(value: "Marine", child: Text("Marina")),
              DropdownMenuItem(value: "Slaughter", child: Text("Katayan")),
              DropdownMenuItem(value: "Rent", child: Text("Renta")),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _editCategory = value);
              _loadEntriesForEdit();
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openReceiptByCategory("Marine"),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text("Ipakita ang Marina"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openReceiptByCategory("Slaughter"),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text("Ipakita ang Katayan"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openReceiptByCategory("Rent"),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text("Show Rent"),
                ),
              ),
            ],
          ),
          if (_editCategory == "Marine") ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _editFlowButton("Incoming"),
                _editFlowButton("Outgoing"),
              ],
            ),
          ],
          const SizedBox(height: 10),
          _buildEntriesContainer(),
          const SizedBox(height: 12),
          TextField(
            controller: _editNatureController,
            decoration: InputDecoration(
              labelText: "Edit Nature of Collection",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _editPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: "Edit Price",
              prefixText: "PHP ",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _updateEntryDetails,
                  icon: const Icon(Icons.save_as),
                  label: const Text("Update Nature/Price"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D5EA8),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _updateEntryCategory,
                  icon: const Icon(Icons.edit),
                  label: const Text("Edit Category"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A5F),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _viewSelectedReceipt,
                  icon: const Icon(Icons.visibility),
                  label: const Text("View Receipt"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _viewSelectedReceipt() {
    if (_editEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No entries available to view."),
          backgroundColor: Color(0xFFB3261E),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReceiptScreen(
          initialCategory: _editCategory,
          initialMarineFlow: _editMarineFlow,
        ),
      ),
    );
  }

  void _openReceiptByCategory(String category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReceiptScreen(
          initialCategory: category,
          initialMarineFlow: _editMarineFlow,
        ),
      ),
    );
  }

  Widget _buildEntriesContainer() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 280),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE5EF)),
      ),
      child: _isLoadingEntries
          ? const Center(child: CircularProgressIndicator())
          : _editEntries.isEmpty
              ? const Text(
                  "No entries found for selected category/flow.",
                  style: TextStyle(color: Colors.black54),
                )
              : ListView.builder(
                  itemCount: _editEntries.length,
                  itemBuilder: (context, index) {
                    final item = _editEntries[index];
                    final id = (item["id"] ?? "").toString();
                    final isSelected = id == _selectedEditEntryId;
                    return InkWell(
                      onTap: () {
                        setState(() => _selectedEditEntryId = id);
                        _syncEditFieldsFromSelection();
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFD7E9FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF1E3A5F)
                                : const Color(0xFFD6DEE8),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item["nature_of_collection"]?.toString() ?? "-",
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Price: ${item["collection_price"]?.toString() ?? "-"}",
                            ),
                            Text(
                              "Saved: ${item["saved_at"]?.toString() ?? "-"}",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _marineFlowButton(String value) {
    final isSelected = _selectedMarineFlow == value;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _selectedMarineFlow = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD7E9FF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF1E3A5F) : const Color(0xFFBFC9D4),
          ),
        ),
        child: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _editFlowButton(String value) {
    final isSelected = _editMarineFlow == value;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        setState(() => _editMarineFlow = value);
        _loadEntriesForEdit();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD7E9FF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF1E3A5F) : const Color(0xFFBFC9D4),
          ),
        ),
        child: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _GlassPanel({
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            border: Border.all(color: const Color(0xFFD6DEE8)),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
