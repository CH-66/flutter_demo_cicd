import 'package:flutter/material.dart';
import '../../models/transaction.dart' as model;
import '../../services/transaction_service.dart';
import '../widgets/transaction_form.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<TransactionFormState>();
  final _transactionService = TransactionService();
  bool _isSaving = false;

  Future<void> _saveTransaction() async {
    final formState = _formKey.currentState;
    if (formState == null) return;
    
    // Use the robust, built-in form validation
    if (!formState.validate()) {
      return; // Validation failed, errors will be displayed on the form automatically
    }

    setState(() => _isSaving = true);

    try {
      // getTransaction is now guaranteed to return a valid transaction
      final transactionData = formState.getTransaction();
      await _transactionService.insertTransaction(transactionData);
      
      if (mounted) {
        Navigator.of(context).pop(true); // Pop with success result
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('记一笔'),
      ),
      body: TransactionForm(
        formKey: _formKey,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveTransaction,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('保存'),
        ),
      ),
    );
  }
} 