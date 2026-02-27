import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditReceiptScreen extends StatefulWidget {
  final Map<String, dynamic> receipt;
  
  const EditReceiptScreen({super.key, required this.receipt});

  @override
  State<EditReceiptScreen> createState() => _EditReceiptScreenState();
}

class _EditReceiptScreenState extends State<EditReceiptScreen> {
  late String _selectedCategory;
  late String _selectedMarineFlow;
  late TextEditingController _natureController;
  late TextEditingController _priceController;
  bool _isLoading = false;
  List<Map<String, dynamic>> _availableNatures = [];
  List<String> _availableCategories = [];
  String? _selectedNature;
  int _natureLoadVersion = 0;

  @override
  void initState() {
    super.initState();
    _selectedCategory = (widget.receipt['category'] ?? '').toString();
    _selectedMarineFlow = widget.receipt['marine_flow'] ?? 'Incoming';
    _natureController = TextEditingController(text: widget.receipt['nature_of_collection'] ?? '');
    _priceController = TextEditingController(text: (widget.receipt['price'] ?? 0.0).toString());
    _selectedNature = widget.receipt['nature_of_collection'];
    _loadAvailableCategories();
    _loadAvailableNatures();
  }

  Future<void> _loadAvailableCategories() async {
    try {
      final client = Supabase.instance.client;
      final fromNatures = await client.from('receipt_natures').select('category');
      final fromReceipts = await client.from('receipts').select('category');

      final seen = <String>{};
      final categories = <String>[];

      void addCategory(dynamic raw) {
        final value = (raw ?? '').toString().trim();
        if (value.isEmpty) return;
        final key = value.toLowerCase();
        if (seen.add(key)) {
          categories.add(value);
        }
      }

      for (final row in List<Map<String, dynamic>>.from(fromNatures)) {
        addCategory(row['category']);
      }
      for (final row in List<Map<String, dynamic>>.from(fromReceipts)) {
        addCategory(row['category']);
      }

      if (!mounted) return;
      setState(() {
        _availableCategories = categories;
        if (_selectedCategory.isEmpty && categories.isNotEmpty) {
          _selectedCategory = categories.first;
        } else if (_selectedCategory.isNotEmpty &&
            !categories
                .map((e) => e.toLowerCase())
                .contains(_selectedCategory.toLowerCase()) &&
            categories.isNotEmpty) {
          _selectedCategory = categories.first;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _availableCategories =
            _selectedCategory.trim().isEmpty ? <String>[] : <String>[_selectedCategory.trim()];
      });
    }
  }

  Future<void> _loadAvailableNatures() async {
    final requestVersion = ++_natureLoadVersion;
    if (_selectedCategory.trim().isEmpty) {
      if (mounted && requestVersion == _natureLoadVersion) {
        setState(() => _availableNatures = []);
      }
      return;
    }
    try {
      final client = Supabase.instance.client;
      var query = client
          .from('receipt_natures')
          .select('nature_of_collection, amount')
          .eq('category', _selectedCategory);

      if (_selectedCategory == 'Marine') {
        query = query.eq('marine_flow', _selectedMarineFlow);
      }

      final data = await query.order('nature_of_collection');
      if (!mounted || requestVersion != _natureLoadVersion) return;
      setState(() {
        _availableNatures = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      print('Error loading natures: $e');
      if (!mounted || requestVersion != _natureLoadVersion) return;
      setState(() {
        _availableNatures = [];
      });
    }
  }

  @override
  void dispose() {
    _natureLoadVersion++;
    _natureController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _updateReceipt() async {
    final nature = _natureController.text.trim();
    final priceText = _priceController.text.trim();
    final price = double.tryParse(priceText);

    if (nature.isEmpty || price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid nature and price'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final client = Supabase.instance.client;
      await client
          .from('receipts')
          .update({
            'category': _selectedCategory,
            'marine_flow': _selectedCategory == 'Marine' ? _selectedMarineFlow : null,
            'nature_of_collection': nature,
            'price': price,
            'saved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.receipt['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // Return true to indicate update
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteReceipt() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Receipt'),
        content: const Text('Are you sure you want to delete this receipt?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final client = Supabase.instance.client;
      await client
          .from('receipts')
          .delete()
          .eq('id', widget.receipt['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // Return true to indicate deletion
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Receipt'),
        backgroundColor: const Color(0xFF1E3A5F),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _isLoading ? null : _deleteReceipt,
            tooltip: 'Delete Receipt',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFFE0E3E7)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Edit Receipt',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory.trim().isEmpty ? null : _selectedCategory,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: _availableCategories.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue == null) return;
                      setState(() {
                        _selectedCategory = newValue;
                        _selectedNature = null;
                        _natureController.clear();
                        _priceController.clear();
                      });
                      _loadAvailableNatures();
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_selectedCategory == 'Marine') ...[
                    const Text(
                      'Marine Flow',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Incoming'),
                          selected: _selectedMarineFlow == 'Incoming',
                          onSelected: (bool selected) {
                            setState(() {
                            _selectedMarineFlow = 'Incoming';
                            _selectedNature = null;
                            _natureController.clear();
                            _priceController.clear();
                          });
                          _loadAvailableNatures();
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Outgoing'),
                        selected: _selectedMarineFlow == 'Outgoing',
                        onSelected: (bool selected) {
                          setState(() {
                            _selectedMarineFlow = 'Outgoing';
                            _selectedNature = null;
                            _natureController.clear();
                            _priceController.clear();
                          });
                          _loadAvailableNatures();
                        },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  DropdownButtonFormField<String>(
                    value: _selectedNature,
                    decoration: const InputDecoration(
                      labelText: 'Nature of Collection',
                      border: OutlineInputBorder(),
                    ),
                    items: _availableNatures.map((nature) {
                      return DropdownMenuItem<String>(
                        value: nature['nature_of_collection'],
                        child: Text(nature['nature_of_collection']),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedNature = newValue;
                        _natureController.text = newValue ?? '';
                        // Auto-populate amount
                        final selectedNatureData = _availableNatures.firstWhere(
                          (nature) => nature['nature_of_collection'] == newValue,
                          orElse: () => {'amount': 0.0},
                        );
                        _priceController.text = selectedNatureData['amount'].toString();
                      });
                    },
                    hint: const Text('Select nature of collection'),
                  ),
                  if (_availableNatures.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'No nature entries found for this category',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      border: OutlineInputBorder(),
                      prefixText: '₱',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _updateReceipt,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isLoading ? 'Updating...' : 'Update Receipt'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A5F),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
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
}
