import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/category.dart';
import '../../models/transaction.dart' as model;
import '../../models/transaction_data.dart';
import '../../services/transaction_service.dart';
import 'category_picker.dart';

class TransactionForm extends StatefulWidget {
  final model.Transaction? initialTransaction;
  final GlobalKey<TransactionFormState> formKey;

  const TransactionForm({
    super.key,
    this.initialTransaction,
    required this.formKey,
  });

  @override
  TransactionFormState createState() => TransactionFormState();
}

class TransactionFormState extends State<TransactionForm> {
  final _transactionService = TransactionService();
  final _internalFormKey = GlobalKey<FormState>();

  late TextEditingController _merchantController;
  late TextEditingController _amountController;
  late TextEditingController _remarksController;
  
  TransactionType _selectedType = TransactionType.expense;
  DateTime _selectedDate = DateTime.now();
  int? _selectedCategoryId;

  bool get _isEditing => widget.initialTransaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.initialTransaction;
    _merchantController = TextEditingController(text: tx?.merchant ?? '');
    _amountController = TextEditingController(text: tx?.amount.toString() ?? '');
    _remarksController = TextEditingController(text: tx?.remarks ?? '');
    _selectedType = tx?.type ?? TransactionType.expense;
    _selectedDate = tx?.timestamp ?? DateTime.now();
    
    if (tx != null) {
      _selectedCategoryId = tx.categoryId;
    } else {
      _fetchDefaultCategory();
    }
  }

  Future<void> _fetchDefaultCategory() async {
    final categories = await _transactionService.getAllCategories();
    if (mounted) {
      setState(() {
        _selectedCategoryId = categories
            .firstWhere((c) => c.name == '未分类', orElse: () => categories.first)
            .id;
      });
    }
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  bool validate() {
    // First, check if the form fields meet their validation criteria.
    final isFormValid = _internalFormKey.currentState?.validate() ?? false;
    if (!isFormValid) {
      return false;
    }
    // Additionally, ensure a category is selected. This should always be true
    // due to the loading mechanism, but it's a good safeguard.
    if (_selectedCategoryId == null) {
      return false;
    }
    return true;
  }

  model.Transaction getTransaction() {
    // This method should only be called after `validate()` returns true.
    final amount = double.parse(_amountController.text);
    
    return model.Transaction(
      id: widget.initialTransaction?.id,
      amount: amount,
      merchant: _merchantController.text.trim(),
      type: _selectedType,
      categoryId: _selectedCategoryId!,
      source: widget.initialTransaction?.source ?? 'manual',
      timestamp: _selectedDate,
      remarks: _remarksController.text.trim().isNotEmpty 
          ? _remarksController.text.trim() : null,
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedCategoryId == null && !_isEditing) {
      return const Center(child: CircularProgressIndicator());
    }

    return Form(
      key: _internalFormKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Transaction Type (Expense/Income)
            SegmentedButton<TransactionType>(
              segments: const <ButtonSegment<TransactionType>>[
                ButtonSegment<TransactionType>(
                    value: TransactionType.expense, label: Text('支出'), icon: Icon(Icons.remove)),
                ButtonSegment<TransactionType>(
                    value: TransactionType.income, label: Text('收入'), icon: Icon(Icons.add)),
              ],
              selected: {_selectedType},
              onSelectionChanged: (Set<TransactionType> newSelection) {
                setState(() {
                  _selectedType = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 16),
            // Amount
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: '金额*', border: OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '金额不能为空';
                }
                if (double.tryParse(value) == null) {
                  return '请输入有效的数字';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Merchant
            TextFormField(
              controller: _merchantController,
              decoration: const InputDecoration(labelText: '商家', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            // Category
            if (_selectedCategoryId != null)
              CategoryPicker(
                initialCategoryId: _selectedCategoryId!,
                onCategorySelected: (id) => setState(() => _selectedCategoryId = id),
              ),
            const SizedBox(height: 16),
            // Date
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              leading: const Icon(Icons.calendar_today),
              title: const Text('日期'),
              trailing: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
              onTap: () => _selectDate(context),
            ),
            const SizedBox(height: 16),
            // Remarks
            TextFormField(
              controller: _remarksController,
              decoration: const InputDecoration(labelText: '备注', border: OutlineInputBorder()),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
} 