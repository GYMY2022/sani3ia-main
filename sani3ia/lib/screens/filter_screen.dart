import 'package:flutter/material.dart';

class FilterScreen extends StatefulWidget {
  final Function(String? category, double? minBudget, double? maxBudget)
  onApply;
  final String? currentCategory;
  final double? currentMinBudget;
  final double? currentMaxBudget;

  const FilterScreen({
    super.key,
    required this.onApply,
    this.currentCategory,
    this.currentMinBudget,
    this.currentMaxBudget,
  });

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  String? _selectedCategory;
  double? _minBudget;
  double? _maxBudget;

  final List<String> _categories = [
    'سباكة',
    'كهرباء',
    'نجارة',
    'بناء',
    'دهانات',
    'تكييفات',
    'ألوميتال',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.currentCategory;
    _minBudget = widget.currentMinBudget;
    _maxBudget = widget.currentMaxBudget;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تصفية النتائج'),
        actions: [
          TextButton(
            onPressed: () {
              widget.onApply(_selectedCategory, _minBudget, _maxBudget);
              Navigator.pop(context);
            },
            child: const Text('تطبيق', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نوع الخدمة:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Wrap(
              spacing: 8,
              children: _categories.map((category) {
                return ChoiceChip(
                  label: Text(category),
                  selected: _selectedCategory == category,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = selected ? category : null;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text(
              'نطاق السعر:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'الحد الأدنى (ج.م)',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _minBudget = double.tryParse(value);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'الحد الأقصى (ج.م)',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _maxBudget = double.tryParse(value);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
