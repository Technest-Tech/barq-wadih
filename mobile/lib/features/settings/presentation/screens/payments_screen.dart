import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';

// ── Local models ──────────────────────────────────────────────────────────────

class SubscriptionPlan {
  final String id;
  final String nameAr;
  final double price;
  final String period;
  final int maxAds;
  final int boostCredits;
  final bool hasTrustedPurchase;
  final bool hasPrioritySupport;
  final bool isRecommended;

  const SubscriptionPlan({
    required this.id,
    required this.nameAr,
    required this.price,
    required this.period,
    required this.maxAds,
    required this.boostCredits,
    required this.hasTrustedPurchase,
    required this.hasPrioritySupport,
    this.isRecommended = false,
  });
}

class PaymentRecord {
  final String id;
  final String planName;
  final double amount;
  final DateTime date;
  final String status; // 'completed' | 'pending' | 'refunded'

  const PaymentRecord({
    required this.id,
    required this.planName,
    required this.amount,
    required this.date,
    required this.status,
  });
}

// ── Mock data — replace with API calls when backend is ready ──────────────────
const _mockPlans = [
  SubscriptionPlan(
    id: 'free',
    nameAr: 'المجاني',
    price: 0,
    period: '',
    maxAds: 3,
    boostCredits: 0,
    hasTrustedPurchase: false,
    hasPrioritySupport: false,
  ),
  SubscriptionPlan(
    id: 'basic',
    nameAr: 'الأساسي',
    price: 49,
    period: 'شهرياً',
    maxAds: 10,
    boostCredits: 3,
    hasTrustedPurchase: false,
    hasPrioritySupport: true,
    isRecommended: true,
  ),
  SubscriptionPlan(
    id: 'pro',
    nameAr: 'الاحترافي',
    price: 129,
    period: 'شهرياً',
    maxAds: 999,
    boostCredits: 15,
    hasTrustedPurchase: true,
    hasPrioritySupport: true,
  ),
];

// ── Provider ──────────────────────────────────────────────────────────────────

class PaymentsState {
  final String currentPlanId;
  final List<SubscriptionPlan> plans;
  final List<PaymentRecord> history;

  const PaymentsState({
    required this.currentPlanId,
    required this.plans,
    required this.history,
  });
}

class PaymentsNotifier extends AsyncNotifier<PaymentsState> {
  @override
  Future<PaymentsState> build() async {
    // TODO: Replace with actual API calls when backend is ready:
    // final current = await ref.read(dioProvider).get('/subscriptions/current');
    // final plans   = await ref.read(dioProvider).get('/subscriptions/plans');
    // final history = await ref.read(dioProvider).get('/payments/history');
    await Future.delayed(const Duration(milliseconds: 400));
    return const PaymentsState(
      currentPlanId: 'free',
      plans: _mockPlans,
      history: [],
    );
  }
}

final paymentsProvider =
    AsyncNotifierProvider<PaymentsNotifier, PaymentsState>(
  PaymentsNotifier.new,
);

// ── Screen ────────────────────────────────────────────────────────────────────

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paymentsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        appBar: AppBar(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          title: const Text('الدفع والاشتراكات',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          elevation: 0,
          centerTitle: true,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'الاشتراكات'),
              Tab(text: 'رسوم المنصة'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppTheme.colorError),
                    const SizedBox(height: 12),
                    const Text('تعذّر تحميل بيانات الاشتراك'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(paymentsProvider),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
              data: (data) => _PaymentsBody(data: data),
            ),
            const _FeeCalculatorBody(),
          ],
        ),
      ),
    );
  }
}

class _PaymentsBody extends StatelessWidget {
  final PaymentsState data;

  const _PaymentsBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final currentPlan =
        data.plans.firstWhere((p) => p.id == data.currentPlanId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCurrentPlanBanner(currentPlan),
          const SizedBox(height: 20),
          _buildSectionTitle('اختر الباقة المناسبة'),
          const SizedBox(height: 12),
          for (final plan in data.plans) ...[
            _PlanCard(
              plan: plan,
              isCurrent: plan.id == data.currentPlanId,
            ),
            const SizedBox(height: 10),
          ],
          if (data.history.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildSectionTitle('سجل المدفوعات'),
            const SizedBox(height: 10),
            _buildHistorySection(),
          ] else ...[
            const SizedBox(height: 8),
            _buildEmptyHistory(),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanBanner(SubscriptionPlan plan) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryBlue, AppTheme.primaryBlueLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('باقتك الحالية',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  'الباقة ${plan.nameAr}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800),
                ),
                if (plan.id != 'free') ...[
                  const SizedBox(height: 4),
                  const Text('تنتهي في: ٣١ ديسمبر ٢٠٢٥',
                      style:
                          TextStyle(color: Colors.white60, fontSize: 11)),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  plan.price == 0 ? 'مجاناً' : '${plan.price.toStringAsFixed(0)} ر.س',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800),
                ),
                if (plan.period.isNotEmpty)
                  Text(plan.period,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.neutralGray800));
  }

  Widget _buildHistorySection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: data.history.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (_, i) => _buildHistoryTile(data.history[i]),
      ),
    );
  }

  Widget _buildHistoryTile(PaymentRecord record) {
    final statusColor = switch (record.status) {
      'completed' => AppTheme.colorSuccess,
      'pending' => AppTheme.colorWarning,
      'refunded' => AppTheme.colorError,
      _ => AppTheme.neutralGray500,
    };
    final statusLabel = switch (record.status) {
      'completed' => 'مكتمل',
      'pending' => 'معلق',
      'refunded' => 'مسترد',
      _ => record.status,
    };

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      title: Text(record.planName,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${record.date.day}/${record.date.month}/${record.date.year}',
        style: const TextStyle(fontSize: 11, color: AppTheme.neutralGray500),
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${record.amount.toStringAsFixed(0)} ر.س',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(statusLabel,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 48, color: AppTheme.neutralGray300),
          SizedBox(height: 10),
          Text('لا توجد مدفوعات سابقة',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.neutralGray500)),
          SizedBox(height: 4),
          Text('ستظهر هنا مدفوعاتك بعد الاشتراك في إحدى الباقات',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: AppTheme.neutralGray400)),
        ],
      ),
    );
  }
}

// ── Plan Card ─────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isCurrent;

  const _PlanCard({required this.plan, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    final isRecommended = plan.isRecommended;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRecommended
              ? AppTheme.accentGold
              : isCurrent
                  ? AppTheme.primaryBlue
                  : AppTheme.neutralGray200,
          width: isRecommended || isCurrent ? 2 : 1,
        ),
        boxShadow: isRecommended ? AppTheme.elevatedShadow : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPlanHeader(isRecommended),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFeatureRow(
                    Icons.list_alt_rounded,
                    'الإعلانات النشطة',
                    plan.maxAds >= 999 ? 'غير محدود' : '${plan.maxAds} إعلان'),
                _buildFeatureRow(
                    Icons.trending_up_rounded,
                    'رصيد التعزيز',
                    plan.boostCredits > 0
                        ? '${plan.boostCredits} مرة/شهر'
                        : 'غير متاح',
                    available: plan.boostCredits > 0),
                _buildFeatureRow(
                    Icons.verified_rounded,
                    'الشراء الموثوق',
                    plan.hasTrustedPurchase ? 'متاح' : 'غير متاح',
                    available: plan.hasTrustedPurchase),
                _buildFeatureRow(
                    Icons.support_agent_rounded,
                    'دعم مميز',
                    plan.hasPrioritySupport ? 'متاح' : 'الدعم العام',
                    available: plan.hasPrioritySupport),
                const SizedBox(height: 12),
                if (isCurrent)
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Center(
                      child: Text('باقتك الحالية',
                          style: TextStyle(
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ),
                  )
                else if (plan.id != 'free')
                  ElevatedButton(
                    onPressed: () {
                      // TODO: integrate payment gateway
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRecommended
                          ? AppTheme.accentGold
                          : AppTheme.primaryBlue,
                      minimumSize: const Size(double.infinity, 44),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    child: Text('اشترك في الباقة ${plan.nameAr}'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanHeader(bool isRecommended) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isRecommended
              ? [AppTheme.accentGold, const Color(0xFFE8960A)]
              : [AppTheme.primaryBlue, AppTheme.primaryBlueLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('الباقة ${plan.nameAr}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    if (isRecommended) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('الأكثر طلباً',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                plan.price == 0 ? 'مجاناً' : '${plan.price.toStringAsFixed(0)} ر.س',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800),
              ),
              if (plan.period.isNotEmpty)
                Text(plan.period,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String label, String value,
      {bool available = true}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: available ? AppTheme.primaryBlue : AppTheme.neutralGray400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.neutralGray700)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: available
                      ? AppTheme.neutralGray800
                      : AppTheme.neutralGray400)),
        ],
      ),
    );
  }
}

// ── Fee Calculator ────────────────────────────────────────────────────────────

class _FeeCalculatorBody extends StatefulWidget {
  const _FeeCalculatorBody();

  @override
  State<_FeeCalculatorBody> createState() => _FeeCalculatorBodyState();
}

class _FeeCalculatorBodyState extends State<_FeeCalculatorBody> {
  final _priceController = TextEditingController();
  double _itemPrice = 0;
  static const double _feeRate = 0.05;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  double get _appFee => _itemPrice * _feeRate;
  double get _total => _itemPrice + _appFee;

  void _showApplePaySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ApplePaySheet(
        total: _total,
        onConfirm: () {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('تمت عملية الدفع بنجاح'),
                ],
              ),
              backgroundColor: AppTheme.colorSuccess,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppTheme.primaryBlue.withValues(alpha: .25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppTheme.primaryBlue, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('كيف تُحسب رسوم المنصة؟',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppTheme.primaryBlue)),
                      const SizedBox(height: 4),
                      Text(
                        'يتم احتساب 5% من قيمة المنتج كرسوم منصة تُضاف على إجمالي الدفع.',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryBlue
                                .withValues(alpha: .75)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Price input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('أدخل سعر المنتج',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.neutralGray800)),
                const SizedBox(height: 12),
                TextField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  textAlign: TextAlign.start,
                  decoration: InputDecoration(
                    hintText: '0.00',
                    suffixText: 'ر.س',
                    suffixStyle: const TextStyle(
                        color: AppTheme.neutralGray600,
                        fontWeight: FontWeight.w600),
                    filled: true,
                    fillColor: AppTheme.neutralGray50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.neutralGray200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.neutralGray200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.primaryBlue, width: 2),
                    ),
                  ),
                  onChanged: (v) {
                    setState(() {
                      _itemPrice = double.tryParse(v) ?? 0;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Breakdown summary
          if (_itemPrice > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('ملخص الدفع',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppTheme.neutralGray800)),
                  const SizedBox(height: 14),
                  _buildSummaryRow('سعر المنتج', _itemPrice),
                  const SizedBox(height: 10),
                  _buildSummaryRow('رسوم المنصة (5%)', _appFee),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: AppTheme.neutralGray200),
                  ),
                  _buildSummaryRow('الإجمالي', _total, isTotal: true),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ] else
            const SizedBox(height: 4),

          // Apple Pay button
          ElevatedButton.icon(
            onPressed: _itemPrice > 0 ? _showApplePaySheet : null,
            icon: const Icon(Icons.apple, size: 22),
            label: const Text('الدفع عبر Apple Pay'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              disabledBackgroundColor: AppTheme.neutralGray300,
              disabledForegroundColor: AppTheme.neutralGray500,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount,
      {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: isTotal ? 14 : 13,
                fontWeight:
                    isTotal ? FontWeight.w700 : FontWeight.w400,
                color: isTotal
                    ? AppTheme.neutralGray800
                    : AppTheme.neutralGray600)),
        Text(
          '${amount.toStringAsFixed(2)} ر.س',
          style: TextStyle(
              fontSize: isTotal ? 15 : 13,
              fontWeight: FontWeight.w700,
              color: isTotal
                  ? AppTheme.primaryBlue
                  : AppTheme.neutralGray700),
        ),
      ],
    );
  }
}

// ── Mock Apple Pay Sheet ──────────────────────────────────────────────────────

class _ApplePaySheet extends StatelessWidget {
  final double total;
  final VoidCallback onConfirm;

  const _ApplePaySheet({required this.total, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Apple logo + title
          const Icon(Icons.apple, size: 44, color: Colors.black),
          const SizedBox(height: 2),
          const Text('Apple Pay',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5)),
          const SizedBox(height: 24),

          // Payment details card
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildDetailRow('المبلغ',
                    '${total.toStringAsFixed(2)} ر.س',
                    valueStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: Colors.black)),
                const SizedBox(height: 12),
                _buildDetailRow('الجهة', 'برق واضح'),
                const SizedBox(height: 12),
                _buildDetailRow('الطريقة', 'Apple Pay'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Confirm button
          ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app_rounded, size: 20),
                SizedBox(width: 8),
                Text('انقر مرتين للتأكيد'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Cancel
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء',
                style: TextStyle(
                    color: AppTheme.neutralGray600, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {TextStyle? valueStyle}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.neutralGray600, fontSize: 14)),
        Text(value,
            style: valueStyle ??
                const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black)),
      ],
    );
  }
}
