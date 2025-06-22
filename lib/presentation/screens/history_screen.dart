import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart' as tx_model;
import '../../models/transaction_data.dart';
import '../../services/transaction_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _transactionService = TransactionService();
  final _searchController = TextEditingController();
  
  late Future<List<tx_model.Transaction>> _transactionsFuture;
  TransactionType? _selectedType;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadTransactions();
  }

  void _loadTransactions() {
    setState(() {
      _transactionsFuture = _transactionService.getFilteredTransactions(
        type: _selectedType,
        keyword: _searchController.text,
        month: _selectedMonth,
      );
    });
  }

  void _onSearchChanged() {
    _loadTransactions();
  }

  void _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null && (picked.year != _selectedMonth.year || picked.month != _selectedMonth.month)) {
      setState(() {
        _selectedMonth = picked;
      });
      _loadTransactions();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史账单'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectMonth,
            tooltip: '选择月份',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildTransactionList()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索商户名称...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
            ),
          ),
          const SizedBox(height: 8),
          ToggleButtons(
            isSelected: [
              _selectedType == null,
              _selectedType == TransactionType.income,
              _selectedType == TransactionType.expense,
            ],
            onPressed: (index) {
              setState(() {
                if (index == 0) _selectedType = null;
                if (index == 1) _selectedType = TransactionType.income;
                if (index == 2) _selectedType = TransactionType.expense;
              });
              _loadTransactions();
            },
            borderRadius: BorderRadius.circular(8),
            children: const [
              Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('全部')),
              Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('收入')),
              Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('支出')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return FutureBuilder<List<tx_model.Transaction>>(
      future: _transactionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('加载失败: ${snapshot.error}'));
        }
        final transactions = snapshot.data ?? [];
        if (transactions.isEmpty) {
          return const Center(child: Text('没有符合条件的交易记录'));
        }

        final groupedTransactions = _groupTransactionsByDay(transactions);
        final sortedKeys = groupedTransactions.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          itemCount: sortedKeys.length,
          itemBuilder: (context, index) {
            final date = sortedKeys[index];
            final dailyTransactions = groupedTransactions[date]!;
            return _buildDailySection(date, dailyTransactions);
          },
        );
      },
    );
  }

  Map<DateTime, List<tx_model.Transaction>> _groupTransactionsByDay(List<tx_model.Transaction> transactions) {
    final Map<DateTime, List<tx_model.Transaction>> grouped = {};
    for (var tx in transactions) {
      final dateKey = DateTime(tx.timestamp.year, tx.timestamp.month, tx.timestamp.day);
      if (grouped[dateKey] == null) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(tx);
    }
    return grouped;
  }
  
  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (date == today) return '今天';
    if (date == yesterday) return '昨天';
    return DateFormat('M月d日 EEEE', 'zh_CN').format(date);
  }

  Widget _buildDailySection(DateTime date, List<tx_model.Transaction> transactions) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                child: Text(
                  _formatDateHeader(date),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              ...transactions.map((tx) {
                final isExpense = tx.type == TransactionType.expense;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isExpense ? Colors.red.shade100 : Colors.green.shade100,
                    child: Icon(
                      isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isExpense ? Colors.red.shade800 : Colors.green.shade800,
                    ),
                  ),
                  title: Text(tx.merchant),
                  subtitle: Text(DateFormat('HH:mm').format(tx.timestamp)),
                  trailing: Text(
                    '${isExpense ? '-' : '+'} ¥${tx.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: isExpense ? Colors.red.shade800 : Colors.green.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }
} 