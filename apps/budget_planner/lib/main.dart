import 'dart:convert';

import 'package:ad_manager/ad_manager.dart';
import 'package:common_ui/common_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const navy = Color(0xFF102A56);
const blue = Color(0xFF1D4ED8);
const yellow = Color(0xFFFACC15);
const green = Color(0xFF15803D);
const red = Color(0xFFDC2626);
const budgetPlannerBannerAdUnitId = 'ca-app-pub-6855248878156856/3153512956';
const transactionsKey = 'budget_planner_transactions_v1';
const budgetKey = 'budget_planner_monthly_budget_v1';
const currencyKey = 'budget_planner_currency_v1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Ads must never prevent the budgeting app from opening.
  try {
    await AdService.initialize();
  } catch (error) {
    debugPrint('AdMob initialization failed; continuing without ads: $error');
  }
  runApp(const BudgetPlannerApp());
}

class MoneyEntry {
  const MoneyEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.isIncome,
    required this.date,
  });

  final String id;
  final String title;
  final String category;
  final double amount;
  final bool isIncome;
  final DateTime date;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'isIncome': isIncome,
        'date': date.toIso8601String(),
      };

  factory MoneyEntry.fromJson(Map<String, dynamic> json) => MoneyEntry(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        amount: (json['amount'] as num).toDouble(),
        isIncome: json['isIncome'] as bool,
        date: DateTime.parse(json['date'] as String),
      );
}

class BudgetPlannerApp extends StatelessWidget {
  const BudgetPlannerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Budget Planner by SVSystem',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light().copyWith(
          scaffoldBackgroundColor: const Color(0xFFF4F7FC),
          colorScheme: AppTheme.light().colorScheme.copyWith(
                primary: blue,
                secondary: yellow,
              ),
          appBarTheme: const AppBarTheme(
            backgroundColor: navy,
            foregroundColor: Colors.white,
          ),
        ),
        home: const BudgetHomePage(),
      );
}

class BudgetHomePage extends StatefulWidget {
  const BudgetHomePage({super.key});

  @override
  State<BudgetHomePage> createState() => _BudgetHomePageState();
}

class _BudgetHomePageState extends State<BudgetHomePage> {
  SharedPreferences? prefs;
  List<MoneyEntry> entries = [];
  double monthlyBudget = 2000;
  String currency = 'USD';
  int tab = 0;
  bool ready = false;
  String? loadError;

  String get symbol => currency == 'GBP' ? '£' : r'$';
  NumberFormat get money => NumberFormat.currency(
        locale: currency == 'GBP' ? 'en_GB' : 'en_US',
        symbol: symbol,
        decimalDigits: 2,
      );

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final store = await SharedPreferences.getInstance();
      final raw = store.getString(transactionsKey);
      final data = raw == null ? <dynamic>[] : jsonDecode(raw) as List<dynamic>;
      final loadedEntries = data
          .map((item) => MoneyEntry.fromJson(item as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      final savedBudget = store.getDouble(budgetKey) ?? 2000;
      final savedCurrency = store.getString(currencyKey) ?? 'USD';
      if (!mounted) return;
      setState(() {
        prefs = store;
        entries = loadedEntries;
        monthlyBudget = savedBudget.isFinite && savedBudget > 0 ? savedBudget : 2000;
        currency = savedCurrency == 'GBP' ? 'GBP' : 'USD';
        loadError = null;
        ready = true;
      });
    } catch (error) {
      debugPrint('Unable to load saved budget data: $error');
      if (!mounted) return;
      setState(() {
        loadError = 'Saved budget data could not be read. Your stored data has not been deleted.';
        ready = true;
      });
    }
  }

  Future<void> saveData() async {
    await prefs?.setString(
      transactionsKey,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
    await prefs?.setDouble(budgetKey, monthlyBudget);
    await prefs?.setString(currencyKey, currency);
  }

  bool isCurrentMonth(MoneyEntry entry) =>
      entry.date.year == DateTime.now().year &&
      entry.date.month == DateTime.now().month;

  double get income => entries
      .where((entry) => entry.isIncome && isCurrentMonth(entry))
      .fold<double>(0, (sum, entry) => sum + entry.amount);

  double get spent => entries
      .where((entry) => !entry.isIncome && isCurrentMonth(entry))
      .fold<double>(0, (sum, entry) => sum + entry.amount);

  double get remaining => monthlyBudget - spent;

  Future<void> addEntry() async {
    final result = await showDialog<MoneyEntry>(
      context: context,
      builder: (_) => EntryDialog(currencySymbol: symbol),
    );
    if (result == null) return;
    setState(() {
      entries.insert(0, result);
      tab = 1;
    });
    await saveData();
  }

  Future<void> editBudget() async {
    final controller = TextEditingController(text: monthlyBudget.toStringAsFixed(2));
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Monthly spending budget'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Budget amount',
            prefixText: '$symbol ',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed != null && parsed.isFinite && parsed > 0) Navigator.pop(dialogContext, parsed);
            },
            child: const Text('Save budget'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    setState(() => monthlyBudget = value);
    await saveData();
  }

  Future<void> deleteEntry(MoneyEntry entry) async {
    setState(() => entries.removeWhere((item) => item.id == entry.id));
    await saveData();
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (loadError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 44, color: red),
                const SizedBox(height: 12),
                Text(loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    setState(() => ready = false);
                    loadData();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: blue,
                borderRadius: BorderRadius.circular(11),
              ),
              clipBehavior: Clip.antiAlias,
              child: SvgPicture.asset('assets/brand/budget_planner_mark.svg', fit: BoxFit.cover),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Budget Planner',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                Text('by SVSystem',
                    style: TextStyle(fontSize: 10, color: yellow)),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currency,
                dropdownColor: navy,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                iconEnabledColor: Colors.white,
                items: const [
                  DropdownMenuItem(value: 'USD', child: Text('USD')),
                  DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                ],
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() => currency = value);
                  await saveData();
                },
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(child: tab == 2 ? budgetPage() : overviewPage()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addEntry,
        backgroundColor: blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add transaction'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Activity'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), label: 'Budget'),
        ],
      ),
    );
  }

  Widget overviewPage() {
    final visible = tab == 1 ? entries : entries.where(isCurrentMonth).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
      children: [
        Text(DateFormat('MMMM yyyy').format(DateTime.now()),
            style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        balanceCard(),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: smallStat('Income', income, green, Icons.south_west)),
            const SizedBox(width: 12),
            Expanded(child: smallStat('Spent', spent, red, Icons.north_east)),
          ],
        ),
        const SizedBox(height: 14),
        if (tab == 0) advertisementSlot(),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: navy)),
            TextButton(onPressed: () => setState(() => tab = 1), child: const Text('See all')),
          ],
        ),
        if (visible.isEmpty)
          emptyState()
        else
          ...activityListItems(visible.take(tab == 1 ? visible.length : 5).toList()),
        if (tab == 1 && visible.length <= 5) advertisementSlot(),
        if (tab == 0) ...[
          const SizedBox(height: 20),
          const Center(
            child: Text('Your money. Your plan. Your progress.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget balanceCard() {
    final progress = (spent / monthlyBudget).clamp(0.0, 1.0);
    final over = spent > monthlyBudget;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [navy, blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Budget remaining', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          Text(money.format(remaining),
              style: const TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Monthly spending', style: TextStyle(color: Colors.white70)),
              Text('${(progress * 100).round()}%',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation(over ? yellow : Colors.white),
            ),
          ),
          const SizedBox(height: 9),
          Text('${money.format(spent)} spent of ${money.format(monthlyBudget)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget smallStat(String label, double amount, Color color, IconData icon) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5EAF2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(money.format(amount),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: navy)),
            ),
          ],
        ),
      );

  Widget budgetPage() {
    final categories = <String, double>{};
    for (final entry in entries.where((item) => !item.isIncome && isCurrentMonth(item))) {
      categories.update(entry.category, (value) => value + entry.amount,
          ifAbsent: () => entry.amount);
    }
    final maxValue = categories.values.fold<double>(0, (a, b) => a > b ? a : b);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
      children: [
        const Text('Your monthly budget',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: navy)),
        const SizedBox(height: 14),
        balanceCard(),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const CircleAvatar(
                backgroundColor: Color(0xFFEFF6FF),
                child: Icon(Icons.edit_outlined, color: blue)),
            title: const Text('Monthly spending limit'),
            subtitle: Text(money.format(monthlyBudget)),
            trailing: TextButton(onPressed: editBudget, child: const Text('Edit')),
          ),
        ),
        const SizedBox(height: 14),
        advertisementSlot(),
        const SizedBox(height: 18),
        const Text('Spending by category',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: navy)),
        const SizedBox(height: 8),
        if (categories.isEmpty)
          emptyState()
        else
          ...categories.entries.map((item) {
            final fraction = maxValue == 0 ? 0.0 : item.value / maxValue;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(money.format(item.value)),
                      ],
                    ),
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE8EEF8),
                        color: blue,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget advertisementSlot() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text('ADVERTISEMENT',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 9,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  )),
            ),
            Center(child: BannerAdSlot(adUnitId: budgetPlannerBannerAdUnitId)),
          ],
        ),
      );

  List<Widget> activityListItems(List<MoneyEntry> visible) {
    final items = <Widget>[];
    for (var index = 0; index < visible.length; index++) {
      items.add(entryTile(visible[index]));
      if (tab == 1 && index == 4 && visible.length > 5) {
        items.add(advertisementSlot());
      }
    }
    return items;
  }

  Widget entryTile(MoneyEntry entry) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: PageStorageKey<String>('transaction-${entry.id}'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: CircleAvatar(
            backgroundColor: entry.isIncome ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
            child: Icon(entry.isIncome ? Icons.south_west : Icons.north_east,
                color: entry.isIncome ? green : red),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Text(
                '${entry.isIncome ? '+' : '−'}${money.format(entry.amount)}',
                style: TextStyle(
                  color: entry.isIncome ? green : red,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          subtitle: Text('${entry.category} · ${DateFormat.yMMMd().format(entry.date)}'),
          children: [
            const Divider(height: 12),
            _detailRow('Transaction type', entry.isIncome ? 'Income' : 'Expense'),
            _detailRow('Description', entry.title),
            _detailRow('Category', entry.category),
            _detailRow('Date', DateFormat.yMMMMd().format(entry.date)),
            _detailRow('Amount', money.format(entry.amount), valueColor: entry.isIncome ? green : red),
            _detailRow('Transaction ID', entry.id),
            Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                tooltip: 'Transaction options',
                onSelected: (value) {
                  if (value == 'delete') deleteEntry(entry);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: red),
                        SizedBox(width: 8),
                        Text('Delete transaction'),
                      ],
                    ),
                  ),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline, size: 18),
                      SizedBox(width: 6),
                      Text('Delete transaction'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _detailRow(String label, String value, {Color? valueColor}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 112,
              child: Text(label, style: const TextStyle(color: Color(0xFF64748B))),
            ),
            Expanded(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: TextStyle(fontWeight: FontWeight.w600, color: valueColor ?? navy)),
            ),
          ],
        ),
      );

  Widget emptyState() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5EAF2)),
        ),
        child: const Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 38, color: Color(0xFF94A3B8)),
            SizedBox(height: 10),
            Text('No transactions yet', style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text('Add your first income or expense to start planning.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      );
}

class EntryDialog extends StatefulWidget {
  const EntryDialog({super.key, required this.currencySymbol});
  final String currencySymbol;

  @override
  State<EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<EntryDialog> {
  final titleController = TextEditingController();
  final amountController = TextEditingController();
  bool income = false;
  String category = 'Food';
  DateTime date = DateTime.now();

  static const expenseCategories = [
    'Food', 'Housing', 'Transport', 'Shopping', 'Bills', 'Health', 'Entertainment', 'Other'
  ];
  static const incomeCategories = ['Salary', 'Business', 'Freelance', 'Investment', 'Other'];

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(income ? 'Add income' : 'Add expense'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Expense'), icon: Icon(Icons.north_east)),
                  ButtonSegment(value: true, label: Text('Income'), icon: Icon(Icons.south_west)),
                ],
                selected: {income},
                onSelectionChanged: (value) => setState(() {
                  income = value.first;
                  category = income ? 'Salary' : 'Food';
                }),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '${widget.currencySymbol} ',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: (income ? incomeCategories : expenseCategories)
                    .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (value) => setState(() => category = value ?? category),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Date'),
                subtitle: Text(DateFormat.yMMMd().format(date)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => date = picked);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text.trim());
              final title = titleController.text.trim();
              if (title.isEmpty || amount == null || !amount.isFinite || amount <= 0) return;
              Navigator.pop(
                context,
                MoneyEntry(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  title: title,
                  category: category,
                  amount: amount,
                  isIncome: income,
                  date: date,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      );
}
