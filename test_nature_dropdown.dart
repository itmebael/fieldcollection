import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://your-supabase-url.supabase.co',
    anonKey: 'your-anon-key',
  );
  
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nature Dropdown Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const NatureDropdownTest(),
    );
  }
}

class NatureDropdownTest extends StatefulWidget {
  const NatureDropdownTest({super.key});

  @override
  State<NatureDropdownTest> createState() => _NatureDropdownTestState();
}

class _NatureDropdownTestState extends State<NatureDropdownTest> {
  String? _selectedCategory = 'Marine';
  String? _selectedMarineFlow = 'Incoming';
  String? _selectedNature;
  List<Map<String, dynamic>> _availableNatures = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableNatures();
  }

  Future<void> _loadAvailableNatures() async {
    setState(() => _isLoading = true);
    
    try {
      print('DEBUG: Loading natures for category: $_selectedCategory, marine_flow: $_selectedMarineFlow');
      
      final client = Supabase.instance.client;
      var query = client
          .from('receipt_natures')
          .select('nature_of_collection, amount');
      
      if (_selectedCategory != null) {
        query = query.eq('category', _selectedCategory!);
      }
      
      if (_selectedCategory == 'Marine' && _selectedMarineFlow != null) {
        query = query.eq('marine_flow', _selectedMarineFlow!);
      }
      
      final data = await query.order('nature_of_collection');
      print('DEBUG: Loaded ${data.length} natures: $data');
      
      if (mounted) {
        setState(() {
          _availableNatures = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading natures: $e');
      if (mounted) {
        setState(() {
          _availableNatures = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nature Dropdown Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading)
              const LinearProgressIndicator(),
            
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: ['Marine', 'Slaughter', 'Rent'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategory = newValue;
                  _selectedNature = null;
                });
                _loadAvailableNatures();
              },
            ),
            
            const SizedBox(height: 16),
            
            if (_selectedCategory == 'Marine') ...[
              const Text('Marine Flow', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                      });
                      _loadAvailableNatures();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedNature,
                    decoration: const InputDecoration(
                      labelText: 'Nature of Collection',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      if (_availableNatures.isNotEmpty)
                        ..._availableNatures.map((nature) {
                          return DropdownMenuItem<String>(
                            value: nature['nature_of_collection'],
                            child: Text(nature['nature_of_collection']),
                          );
                        })
                    ],
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedNature = newValue;
                      });
                    },
                    hint: const Text('Select nature of collection'),
                    disabledHint: const Text('No nature entries available'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh nature list',
                  onPressed: _isLoading ? null : () {
                    print('DEBUG: Manual refresh triggered');
                    _loadAvailableNatures();
                  },
                ),
              ],
            ),
            
            if (_availableNatures.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'No nature entries found for this category',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
            
            const SizedBox(height: 32),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Debug Info:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Category: ${_selectedCategory ?? "None"}'),
                    Text('Marine Flow: ${_selectedMarineFlow ?? "None"}'),
                    Text('Selected Nature: ${_selectedNature ?? "None"}'),
                    Text('Available Natures: ${_availableNatures.length}'),
                    const SizedBox(height: 8),
                    const Text('Available Natures List:'),
                    ..._availableNatures.map((nature) => 
                      Text('- ${nature['nature_of_collection']}: ₱${nature['amount']}')).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
