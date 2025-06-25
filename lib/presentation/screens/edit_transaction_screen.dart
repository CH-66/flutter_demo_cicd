import 'package:flutter/material.dart';
import '../../models/transaction.dart' as model;
import '../../services/transaction_service.dart';
import '../widgets/transaction_form.dart';

class EditTransactionScreen extends StatefulWidget {
  final model.Transaction transaction;

  const EditTransactionScreen({super.key, required this.transaction});

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  final _formKey = GlobalKey<TransactionFormState>();
  final _transactionService = TransactionService();
  bool _isSaving = false;

  Future<void> _saveTransaction() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return; // Validation failed, errors will be displayed automatically.
    }
    
    setState(() => _isSaving = true);

    try {
      final updatedTransaction = formState.getTransaction();
      await _transactionService.updateTransaction(updatedTransaction);
      if (mounted) {
        Navigator.of(context).pop(true); // Pop with success result
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑账单'),
      ),
      body: TransactionForm(
        formKey: _formKey,
        initialTransaction: widget.transaction,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveTransaction,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('保存更改'),
        ),
      ),
    );
  }
} 