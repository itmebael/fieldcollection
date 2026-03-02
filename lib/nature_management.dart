import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';
import 'session_service.dart';

class NatureManagementScreen extends StatefulWidget {
  const NatureManagementScreen({super.key});

  @override
  State<NatureManagementScreen> createState() => _NatureManagementScreenState();
}

class _NatureManagementScreenState extends State<NatureManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _natureController = TextEditingController();
  final _amountController = TextEditingController();

  String? _selectedCategory;
  String? _selectedMarineFlow = 'Incoming';
  String _entriesCategoryFilter = '_current';
  String _entriesFlowFilter = '_auto';
  List<String> _categoryOptions = [];
  List<Map<String, dynamic>> _natureEntries = [];
  bool _isLoading = false;
  bool _isSaving = false;

  String _norm(dynamic v) => (v ?? '').toString().trim().toLowerCase();

  bool _isAuthExpiredError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('jwt expired') ||
        msg.contains('pgrst303') ||
        msg.contains('unauthorized');
  }

  bool _isMalformedArrayLiteralError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('22p02') && msg.contains('malformed array literal');
  }

  Future<void> _handleAuthExpired() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session expired. Please log in again.'),
      ),
    );
    await SessionService.clearSession();
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // Ignore sign-out cleanup failures.
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  String _formatAmount(dynamic value) {
    if (value == null) return '0.00';
    if (value is num) return value.toDouble().toStringAsFixed(2);
    final parsed = double.tryParse(value.toString());
    return (parsed ?? 0.0).toStringAsFixed(2);
  }

  String _formatNature(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return 'Unknown';
    return text;
  }

  List<Map<String, dynamic>> _visibleEntries() {
    String? categoryFilter;
    if (_entriesCategoryFilter == '_current') {
      final current = _selectedCategory?.trim();
      if (current != null && current.isNotEmpty) {
        categoryFilter = current;
      }
    } else if (_entriesCategoryFilter != '_all') {
      categoryFilter = _entriesCategoryFilter;
    }

    var filtered = _natureEntries.where((entry) {
      if (categoryFilter == null) return true;
      return _norm(entry['category']) == _norm(categoryFilter);
    }).toList();

    if (_entriesFlowFilter == '_auto') {
      if (categoryFilter != null && _norm(categoryFilter) == 'marine') {
        filtered = filtered.where((entry) {
          final flow = _norm(entry['marine_flow']);
          if (flow.isEmpty) return true;
          return flow == _norm(_selectedMarineFlow);
        }).toList();
      }
      return filtered;
    }

    if (_entriesFlowFilter == '_any') {
      return filtered;
    }

    final desiredFlow = _norm(_entriesFlowFilter);
    return filtered.where((entry) {
      if (_norm(entry['category']) != 'marine') return false;
      return _norm(entry['marine_flow']) == desiredFlow;
    }).toList();
  }

  Future<void> _showEntriesFilterDialog() async {
    String tempCategoryFilter = _entriesCategoryFilter;
    String tempFlowFilter = _entriesFlowFilter;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Filter Entries'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Category'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: tempCategoryFilter,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem(
                      value: '_current',
                      child: Text('Current Category'),
                    ),
                    const DropdownMenuItem(
                      value: '_all',
                      child: Text('All Categories'),
                    ),
                    ..._categoryOptions.map(
                      (c) => DropdownMenuItem<String>(
                        value: c,
                        child: Text(c),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => tempCategoryFilter = value);
                  },
                ),
                const SizedBox(height: 12),
                const Text('Marine Flow'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: tempFlowFilter,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: '_auto',
                      child: Text('Auto (from current form)'),
                    ),
                    DropdownMenuItem(
                      value: '_any',
                      child: Text('Any'),
                    ),
                    DropdownMenuItem(
                      value: 'Incoming',
                      child: Text('Incoming'),
                    ),
                    DropdownMenuItem(
                      value: 'Outgoing',
                      child: Text('Outgoing'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => tempFlowFilter = value);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _entriesCategoryFilter = '_current';
                    _entriesFlowFilter = '_auto';
                  });
                  Navigator.pop(context);
                },
                child: const Text('Reset'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _entriesCategoryFilter = tempCategoryFilter;
                    _entriesFlowFilter = tempFlowFilter;
                  });
                  Navigator.pop(context);
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _entriesHeaderLabel() {
    if (_entriesCategoryFilter == '_all') return 'All Categories';
    if (_entriesCategoryFilter == '_current') {
      final current = _selectedCategory?.trim();
      if (current == null || current.isEmpty) return 'Existing Nature Entries';
      return 'Existing Nature Entries ($current)';
    }
    return 'Existing Nature Entries (${_entriesCategoryFilter.trim()})';
  }

  String _entriesFilterBadge() {
    final categoryLabel = _entriesCategoryFilter == '_current'
        ? 'Current'
        : _entriesCategoryFilter == '_all'
            ? 'All'
            : _entriesCategoryFilter;
    final flowLabel = _entriesFlowFilter == '_auto'
        ? 'Auto'
        : _entriesFlowFilter == '_any'
            ? 'Any'
            : _entriesFlowFilter;
    return 'Filter: $categoryLabel | $flowLabel';
  }

  @override
  void initState() {
    super.initState();
    _loadNatureEntries();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _natureController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadNatureEntries() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final client = Supabase.instance.client;

      // Try to load from receipt_natures table first
      var query = client
          .from('receipt_natures')
          .select('*')
          .order('nature_of_collection');

      final data = await query;

      if (mounted) {
        final rows = List<Map<String, dynamic>>.from(data);
        final categoriesFromNatures = rows
            .map((e) => (e['category'] ?? '').toString().trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();

        final receiptCategoriesData =
            await client.from('receipts').select('category');
        final categoriesFromReceipts = List<Map<String, dynamic>>.from(
          receiptCategoriesData,
        )
            .map((e) => (e['category'] ?? '').toString().trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();

        final mergedCategories = <String>{
          ...categoriesFromNatures,
          ...categoriesFromReceipts,
        }.toList()
          ..sort();

        setState(() {
          _natureEntries = rows;
          _categoryOptions = mergedCategories;
          if (_selectedCategory == null ||
              !_categoryOptions.contains(_selectedCategory)) {
            _selectedCategory = _categoryOptions.first;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (_isAuthExpiredError(e)) {
        setState(() {
          _natureEntries = [];
          _isLoading = false;
        });
        await _handleAuthExpired();
        return;
      }
      print('Error loading nature entries: $e');
      if (mounted) {
        setState(() {
          _natureEntries = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveNatureEntry() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final client = Supabase.instance.client;
      final amountText = _amountController.text.trim();

      final natureData = {
        'nature_code': _codeController.text.trim(),
        'category': _selectedCategory,
        'nature_of_collection': _natureController.text.trim(),
        'amount': amountText.isEmpty ? null : double.tryParse(amountText),
        'marine_flow':
            _selectedCategory == 'Marine' ? _selectedMarineFlow : null,
      };

      try {
        await client.from('receipt_natures').insert(natureData);
      } catch (e) {
        if (!_isMalformedArrayLiteralError(e)) rethrow;
        final retryPayload = Map<String, dynamic>.from(natureData);
        final code = (retryPayload['nature_code'] ?? '').toString().trim();
        retryPayload['nature_code'] = code.isEmpty ? <String>[] : <String>[code];
        await client.from('receipt_natures').insert(retryPayload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nature entry saved successfully!')),
        );

        // Clear form
        _codeController.clear();
        _natureController.clear();
        _amountController.clear();

        // Reload entries
        await _loadNatureEntries();

        setState(() {
          _isSaving = false;
        });
      }
    } catch (e) {
      if (_isAuthExpiredError(e)) {
        setState(() => _isSaving = false);
        await _handleAuthExpired();
        return;
      }
      print('Error saving nature entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving nature entry: $e'),
          ),
        );
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteNatureEntry(int id) async {
    try {
      final client = Supabase.instance.client;
      await client.from('receipt_natures').delete().eq('id', id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nature entry deleted successfully!')),
        );
        await _loadNatureEntries();
      }
    } catch (e) {
      if (_isAuthExpiredError(e)) {
        await _handleAuthExpired();
        return;
      }
      print('Error deleting nature entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error deleting nature entry: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();
    final newCategory = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'e.g., Market',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(context, value);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newCategory == null || newCategory.trim().isEmpty) return;
    final category = newCategory.trim();

    setState(() {
      if (!_categoryOptions.contains(category)) {
        _categoryOptions = [..._categoryOptions, category]..sort();
      }
      _selectedCategory = category;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Nature Entries'),
        backgroundColor: const Color(0xFF14345C),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Input Form Section
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add New Nature Entry',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      // Category Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: 'Add category',
                            icon: const Icon(Icons.add),
                            onPressed: _showAddCategoryDialog,
                          ),
                        ),
                        items: _categoryOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedCategory = newValue;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please select category from Supabase data';
                          }
                          return null;
                        },
                      ),
                      if (_categoryOptions.isEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'No categories found in Supabase (receipt_natures/receipts).',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Marine Flow (only for Marine category)
                      if (_selectedCategory == 'Marine') ...[
                        const Text('Marine Flow',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Incoming'),
                              selected: _selectedMarineFlow == 'Incoming',
                              onSelected: (bool selected) {
                                setState(() {
                                  _selectedMarineFlow = 'Incoming';
                                });
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Outgoing'),
                              selected: _selectedMarineFlow == 'Outgoing',
                              onSelected: (bool selected) {
                                setState(() {
                                  _selectedMarineFlow = 'Outgoing';
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Nature of Collection Input
                      TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: 'Code',
                          border: OutlineInputBorder(),
                          hintText: 'e.g., M-IN-001',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter code';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Nature of Collection Input
                      TextFormField(
                        controller: _natureController,
                        decoration: const InputDecoration(
                          labelText: 'Nature of Collection',
                          border: OutlineInputBorder(),
                          hintText:
                              'e.g., Dock Fee, Processing Fee, Monthly Rent',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter nature of collection';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Amount Input
                      TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          border: OutlineInputBorder(),
                          prefixText: 'PHP ',
                          hintText: '0.00',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isNotEmpty &&
                              double.tryParse(text) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_isSaving || _categoryOptions.isEmpty)
                              ? null
                              : _saveNatureEntry,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isSaving
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  'Save Nature Entry',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Existing Entries Section
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 180),
                  child: Text(
                      _entriesHeaderLabel(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _showEntriesFilterDialog,
                  icon: const Icon(Icons.filter_list),
                  label: const Text('Filter'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _entriesFilterBadge(),
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Entries List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _visibleEntries().isEmpty
                      ? const Center(
                          child: Text(
                            'No entries found for selected category.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _visibleEntries().length,
                          itemBuilder: (context, index) {
                            final entry = _visibleEntries()[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(_formatNature(
                                    entry['nature_of_collection'])),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if ((entry['nature_code'] ?? '')
                                        .toString()
                                        .trim()
                                        .isNotEmpty)
                                      Text('Code: ${entry['nature_code']}'),
                                    Text('Category: ${entry['category']}'),
                                    if (entry['marine_flow'] != null)
                                      Text(
                                          'Marine Flow: ${entry['marine_flow']}'),
                                    Text(
                                        'Amount: PHP ${_formatAmount(entry['amount'])}'),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _deleteNatureEntry(entry['id']),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
