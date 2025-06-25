import 'package:flutter/material.dart';
import '../../models/category.dart';
import '../../services/transaction_service.dart';

class CategoryPicker extends StatefulWidget {
  final int initialCategoryId;
  final Function(int) onCategorySelected;

  const CategoryPicker({
    super.key,
    required this.initialCategoryId,
    required this.onCategorySelected,
  });

  @override
  State<CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<CategoryPicker> {
  final TransactionService _transactionService = TransactionService();
  late Future<List<Category>> _categoriesFuture;
  Category? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _transactionService.getAllCategories();
    _initiallySelectCategory();
  }
  
  void _initiallySelectCategory() async {
    final categories = await _categoriesFuture;
    if (mounted) {
       setState(() {
        _selectedCategory = categories.firstWhere(
          (c) => c.id == widget.initialCategoryId,
          orElse: () => categories.first, // Fallback to the first category
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('分类', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showCategoryPickerSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _selectedCategory == null
                ? const SizedBox(height: 24, child: Center(child: Text("选择分类...")))
                : Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _selectedCategory!.color,
                        child: Icon(_selectedCategory!.icon, size: 16, color: Colors.white),
                        radius: 12,
                      ),
                      const SizedBox(width: 8),
                      Text(_selectedCategory!.name),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  void _showCategoryPickerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return FutureBuilder<List<Category>>(
          future: _categoriesFuture,
          builder: (futureContext, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final categories = snapshot.data!;
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
              ),
              itemCount: categories.length,
              itemBuilder: (gridCtx, index) {
                final category = categories[index];
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                    widget.onCategorySelected(category.id!);
                    Navigator.of(ctx).pop();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: category.color,
                        child: Icon(category.icon, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(category.name, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
} 