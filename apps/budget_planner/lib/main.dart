import 'dart:convert';
import 'dart:ui' as ui;

import 'package:ad_manager/ad_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const navy = Color(0xFF061A43);
const blue = Color(0xFF2563EB);
const violet = Color(0xFF7C3AED);
const cyan = Color(0xFF38BDF8);
const yellow = Color(0xFFFACC15);
const green = Color(0xFF34D399);
const red = Color(0xFFFB7185);
const glassBorder = Color(0x66FFFFFF);
const mutedText = Color(0xFFB8C8E8);
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
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: navy,
          colorScheme: ColorScheme.fromSeed(
            seedColor: blue,
            brightness: Brightness.dark,
            surface: const Color(0xFF102B60),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: const Color(0xFF102B60),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.07),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
      extendBody: true,
      backgroundColor: navy,
      appBar: AppBar(
        toolbarHeight: 76,
        title: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [blue, violet]),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: glassBorder),
                boxShadow: const [BoxShadow(color: Color(0x5538BDF8), blurRadius: 18)],
              ),
              clipBehavior: Clip.antiAlias,
              child: SvgPicture.asset('assets/brand/budget_planner_mark.svg', fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Budget Planner',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                Text('by SVSystem',
                    style: TextStyle(fontSize: 11, color: yellow, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: glassBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: currency,
                  dropdownColor: const Color(0xFF102B60),
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
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: PremiumBackdrop()),
          SafeArea(child: tab == 2 ? budgetPage() : overviewPage()),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [cyan, blue, violet]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
          boxShadow: const [BoxShadow(color: Color(0x663B82F6), blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: FloatingActionButton.extended(
          onPressed: addEntry,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded, size: 25),
          label: const Text('Add transaction', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
      bottomNavigationBar: PremiumNavigationBar(
        selectedIndex: tab,
        onSelected: (value) => setState(() => tab = value),
      ),
    );
  }

  Widget overviewPage() {
    final visible = tab == 1 ? entries : entries.where(isCurrentMonth).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
      children: [
        Text(DateFormat('MMMM yyyy').format(DateTime.now()),
            style: const TextStyle(color: mutedText, fontWeight: FontWeight.w700)),
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
            const Text('Recent Activity',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.4)),
            TextButton(onPressed: () => setState(() => tab = 1), child: const Text('See all →', style: TextStyle(color: cyan, fontWeight: FontWeight.w700))),
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
    return GlassPanel(
      radius: 30,
      padding: const EdgeInsets.all(21),
      gradient: const [Color(0xCC1254A6), Color(0xAA102B60), Color(0x887C3AED)],
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 17, color: cyan),
                    const SizedBox(width: 8),
                    Text(DateFormat('MMMM yyyy').format(DateTime.now()),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Budget remaining', style: TextStyle(color: mutedText, fontSize: 13)),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(money.format(remaining),
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 9,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation(over ? yellow : cyan),
                  ),
                ),
                const SizedBox(height: 8),
                Text('${money.format(spent)} spent of ${money.format(monthlyBudget)}',
                    style: const TextStyle(color: mutedText, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(over ? yellow : cyan),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${(progress * 100).round()}%',
                        style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                    const Text('used', style: TextStyle(color: mutedText, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget smallStat(String label, double amount, Color color, IconData icon) => GlassPanel(
        radius: 22,
        padding: const EdgeInsets.all(15),
        gradient: [color.withValues(alpha: 0.25), Colors.white.withValues(alpha: 0.07)],
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.45)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.30), blurRadius: 14)],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: mutedText, fontSize: 12)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(money.format(amount),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ],
              ),
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
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(height: 8),
        if (categories.isEmpty)
          emptyState()
        else
          ...categories.entries.map((item) {
            final fraction = maxValue == 0 ? 0.0 : item.value / maxValue;
            return GlassPanel(
              radius: 18,
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item.key, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                        Text(money.format(item.value), style: const TextStyle(color: cyan, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 8,
                        backgroundColor: Colors.white12,
                        color: cyan,
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
                    color: mutedText,
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

  Widget entryTile(MoneyEntry entry) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: GlassPanel(
          radius: 22,
          padding: EdgeInsets.zero,
          gradient: entry.isIncome
              ? const [Color(0x6634D399), Color(0x331D4ED8)]
              : const [Color(0x66FB7185), Color(0x331D4ED8)],
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              splashColor: Colors.white10,
              highlightColor: Colors.white10,
            ),
            child: ExpansionTile(
              key: PageStorageKey<String>('transaction-${entry.id}'),
              tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              iconColor: cyan,
              collapsedIconColor: Colors.white70,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: entry.isIncome ? [green, const Color(0xFF059669)] : [red, const Color(0xFFBE123C)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: (entry.isIncome ? green : red).withValues(alpha: 0.25), blurRadius: 12)],
                ),
                child: Icon(entry.isIncome ? Icons.north_east_rounded : Icons.south_east_rounded, color: Colors.white),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(entry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${entry.isIncome ? '+' : '−'}${money.format(entry.amount)}',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: entry.isIncome ? green : red,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Text('${entry.category} · ${DateFormat.yMMMd().format(entry.date)}',
                  style: const TextStyle(color: mutedText, fontSize: 12)),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    children: [
                      _detailRow('Type', entry.isIncome ? 'Income' : 'Expense'),
                      _detailRow('Description', entry.title),
                      _detailRow('Category', entry.category),
                      _detailRow('Date', DateFormat.yMMMMd().format(entry.date)),
                      _detailRow('Amount', money.format(entry.amount), valueColor: entry.isIncome ? green : red),
                      _detailRow('Transaction ID', entry.id),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFF8DA1),
                            side: const BorderSide(color: Color(0x99FB7185)),
                            backgroundColor: const Color(0x22FB7185),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => deleteEntry(entry),
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: const Text('Delete transaction'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _detailRow(String label, String value, {Color? valueColor}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 112,
              child: Text(label, style: const TextStyle(color: mutedText)),
            ),
            Expanded(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: TextStyle(fontWeight: FontWeight.w700, color: valueColor ?? Colors.white)),
            ),
          ],
        ),
      );

  Widget emptyState() => GlassPanel(
        radius: 22,
        padding: const EdgeInsets.all(24),
        child: const Column(
          children: [
            Icon(Icons.receipt_long_rounded, size: 40, color: cyan),
            SizedBox(height: 10),
            Text('No transactions yet',
                style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
            SizedBox(height: 4),
            Text('Add your first income or expense to start planning.',
                textAlign: TextAlign.center,
                style: TextStyle(color: mutedText)),
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

class PremiumBackdrop extends StatelessWidget {
  const PremiumBackdrop({super.key});

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF061638), Color(0xFF0B2E70), Color(0xFF101B55)],
              ),
            ),
          ),
          Positioned(
            top: -120,
            left: -90,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 65, sigmaY: 65),
              child: Container(
                width: 270,
                height: 270,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Color(0xAA0EA5E9), Colors.transparent]),
                ),
              ),
            ),
          ),
          Positioned(
            top: 280,
            right: -120,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 75, sigmaY: 75),
              child: Container(
                width: 300,
                height: 300,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Color(0x887C3AED), Colors.transparent]),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 75, sigmaY: 75),
              child: Container(
                width: 320,
                height: 320,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Color(0xAA2563EB), Colors.transparent]),
                ),
              ),
            ),
          ),
        ],
      );
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final List<Color>? gradient;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient ??
                    [Colors.white.withValues(alpha: 0.19), Colors.white.withValues(alpha: 0.07)],
              ),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: glassBorder, width: 1),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 9)),
                BoxShadow(color: Color(0x2238BDF8), blurRadius: 18, spreadRadius: -8),
              ],
            ),
            child: child,
          ),
        ),
      );
}

class PremiumNavigationBar extends StatelessWidget {
  const PremiumNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const items = [
    (Icons.grid_view_rounded, 'Overview'),
    (Icons.receipt_long_rounded, 'Activity'),
    (Icons.donut_large_rounded, 'Budget'),
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: GlassPanel(
            radius: 30,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            gradient: const [Color(0xAA397BC4), Color(0x99304A86), Color(0xAA142C5C)],
            child: Row(
              children: List.generate(items.length, (index) {
                final selected = selectedIndex == index;
                final item = items[index];
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: item.$2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => onSelected(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          gradient: selected
                              ? const LinearGradient(colors: [Color(0xCC0EA5E9), Color(0xCC2563EB), Color(0xAA7C3AED)])
                              : null,
                          borderRadius: BorderRadius.circular(22),
                          border: selected ? Border.all(color: Colors.white70) : null,
                          boxShadow: selected
                              ? const [BoxShadow(color: Color(0x6638BDF8), blurRadius: 18)]
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(item.$1, color: Colors.white, size: 23),
                            const SizedBox(height: 4),
                            Text(item.$2,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      );
}
