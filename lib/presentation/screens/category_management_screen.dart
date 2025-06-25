import 'package:flutter/material.dart';
import '../../models/category.dart';
import '../../services/transaction_service.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final TransactionService _transactionService = TransactionService();
  late Future<List<Category>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() {
    setState(() {
      _categoriesFuture = _transactionService.getAllCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账单分类管理'),
      ),
      body: FutureBuilder<List<Category>>(
        future: _categoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('没有找到任何分类。'));
          }

          final categories = snapshot.data!;
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final isDefault = category.name == '未分类';
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: category.color,
                  child: Icon(category.icon, color: Colors.white),
                ),
                title: Text(category.name),
                trailing: isDefault
                    ? null // '未分类' is not editable/deletable
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              _showCategoryEditorDialog(category: category);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              _showDeleteConfirmationDialog(category);
                            },
                          ),
                        ],
                      ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showCategoryEditorDialog();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showCategoryEditorDialog({Category? category}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _CategoryEditorDialog(
        category: category,
        transactionService: _transactionService,
      ),
    );

    if (result == true) {
      _loadCategories();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(category == null ? '分类已添加。' : '分类已更新。'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showDeleteConfirmationDialog(Category category) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('你确定要删除 "${category.name}" 分类吗?'),
                const Text('所有关联的账单将会被归类到 "未分类"。此操作无法撤销。'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('删除'),
              onPressed: () async {
                try {
                  await _transactionService.deleteCategory(category.id!);
                  if (mounted) {
                    Navigator.of(context).pop(); // Close dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('分类 "${category.name}" 已删除。'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.of(context).pop(); // Close dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('删除失败: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  _loadCategories();
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class _CategoryEditorDialog extends StatefulWidget {
  final Category? category;
  final TransactionService transactionService;

  const _CategoryEditorDialog({
    this.category,
    required this.transactionService,
  });

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late int _selectedIconCodePoint;
  late int _selectedColorValue;
  bool get _isEditing => widget.category != null;

  // Pre-defined lists for icon and color pickers for simplicity and robustness
  final List<IconData> _icons = [
    Icons.shopping_cart, Icons.restaurant, Icons.directions_car,
    Icons.local_play, Icons.home, Icons.health_and_safety,
    Icons.school, Icons.work, Icons.pets,
    Icons.card_giftcard, Icons.train, Icons.phone_android,
  ];
  final List<Color> _colors = [
    Colors.blue, Colors.orange, Colors.green, Colors.purple, Colors.brown,
    Colors.red, Colors.teal, Colors.pink, Colors.amber, Colors.indigo,
    Colors.cyan, Colors.lime,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name);
    _selectedIconCodePoint = widget.category?.iconCodePoint ?? _icons.first.codePoint;
    _selectedColorValue = widget.category?.colorValue ?? _colors.first.value;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    if (_formKey.currentState!.validate()) {
      try {
        final newCategory = Category(
          id: widget.category?.id,
          name: _nameController.text.trim(),
          iconCodePoint: _selectedIconCodePoint,
          colorValue: _selectedColorValue,
        );

        if (_isEditing) {
          await widget.transactionService.updateCategory(newCategory);
        } else {
          await widget.transactionService.addCategory(newCategory);
        }
        
        if (mounted) {
          Navigator.of(context).pop(true); // Pop with success result
        }

      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? '编辑分类' : '新增分类'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '名称'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '名称不能为空。';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildPicker(
                context,
                title: '选择图标',
                itemCount: _icons.length,
                itemBuilder: (index) {
                  final icon = _icons[index];
                  return Icon(icon, size: 30);
                },
                isSelected: (index) => _icons[index].codePoint == _selectedIconCodePoint,
                onSelect: (index) => setState(() => _selectedIconCodePoint = _icons[index].codePoint),
              ),
              const SizedBox(height: 20),
               _buildPicker(
                context,
                title: '选择颜色',
                itemCount: _colors.length,
                itemBuilder: (index) {
                  final color = _colors[index];
                  return Container(width: 30, height: 30, color: color);
                },
                isSelected: (index) => _colors[index].value == _selectedColorValue,
                onSelect: (index) => setState(() => _selectedColorValue = _colors[index].value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _saveCategory,
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _buildPicker(
    BuildContext context, {
    required String title,
    required int itemCount,
    required Widget Function(int) itemBuilder,
    required bool Function(int) isSelected,
    required void Function(int) onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: List.generate(itemCount, (index) {
            return GestureDetector(
              onTap: () => onSelect(index),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected(index)
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: itemBuilder(index),
              ),
            );
          }),
        ),
      ],
    );
  }
} 