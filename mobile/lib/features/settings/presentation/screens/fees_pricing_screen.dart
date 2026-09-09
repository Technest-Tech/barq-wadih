import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/riyal_text.dart';

/// الرسوم والأسعار — mirrors the web `/fees` page content.
class FeesPricingScreen extends StatelessWidget {
  const FeesPricingScreen({super.key});

  /// Paid commissions — deliberately not the table's blue, so the amount pops.
  static const _amountOrange = Color(0xFFEA580C);
  static const _amountGreen = Color(0xFF16A34A);

  /// Darker partners for the notes under each amount. The badge colours above
  /// are tuned for bold 14px on a tinted chip; reused as-is on white at note
  /// size they fall under the 4.5:1 contrast floor. These clear it.
  static const _noteOrange = Color(0xFF9A3412);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        title: const Text(
          'الرسوم والأسعار',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryBlue, AppTheme.primaryBlueLight],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'الرسوم والأسعار',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'تعرّف على عمولات ما بعد البيع وطرق الدفع على منصة برق واضح. نشر الإعلانات مجاني.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ١. عمولات المنصة
            _buildSection(
              icon: Icons.balance_rounded,
              title: '١. عمولات المنصة ⚖️',
              color: const Color(0xFF0D9488),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تُستحق العمولة في ذمة المعلن فور إتمام عملية البيع.',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.neutralGray700,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildFeesTable(),
                  const SizedBox(height: 10),
                  const Text(
                    'جميع الأسعار أعلاه تشمل ضريبة القيمة المضافة 15%.',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.neutralGray400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ٢. ملاحظات هامة
            _buildSection(
              icon: Icons.sticky_note_2_outlined,
              title: '٢. ملاحظات هامة 📝',
              color: const Color(0xFFF59E0B),
              child: const _BulletList([
                'نشر الإعلان في التطبيق مجاني تماماً لجميع الأقسام.',
                'الإعلان ينتهي تلقائياً بعد 30 يوماً ويمكن للمعلن تجديده مجاناً.',
                'يمكن تجديد الإعلان (تحديثه ورفعه للأعلى) مرة واحدة كل 24 ساعة.',
              ]),
            ),
            const SizedBox(height: 12),

            // ٣. طرق دفع العمولة
            _buildSection(
              icon: Icons.credit_card_rounded,
              title: '٣. طرق دفع العمولة 💳',
              color: AppTheme.primaryBlue,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'طريقة الدفع المتاحة حالياً:',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.neutralGray700,
                      height: 1.7,
                    ),
                  ),
                  SizedBox(height: 8),
                  _BulletList([
                    'تحويل لحساب مؤسسة برق واضح',
                    'إرفاق صورة إيصال التحويل من داخل التطبيق للمراجعة',
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Center(
              child: Text(
                'آخر تحديث: أغسطس 2026',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.neutralGray400,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFeesTable() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Table(
          border: TableBorder.all(color: const Color(0xFFE5E7EB), width: 1),
          columnWidths: const {0: FlexColumnWidth(1.3), 1: FlexColumnWidth(1)},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            const TableRow(
              decoration: BoxDecoration(color: AppTheme.primaryBlue),
              children: [
                _TableCell(
                  child: Text(
                    'القسم',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                _TableCell(
                  child: Text(
                    'العمولة',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            // Amounts mirror CategorySeeder: cars 99 individual / 35 dealer,
            // every other paid section 10, jobs free. Keep them in step with
            // `deferred_commission_individual` / `_dealer` on the category.
            _feeRow(
              category: '🚗 السيارات والمركبات / أفراد',
              amount: '99 ر.س',
              note: '(تُدفع بعد البيع)',
              amountColor: _amountOrange,
              shaded: true,
            ),
            _feeRow(
              category: '🚗 السيارات والمركبات / معارض',
              amount: '35 ر.س',
              note: '(تُدفع بعد البيع)',
              amountColor: _amountOrange,
              shaded: false,
            ),
            _feeRow(
              category: '📱 الجوالات والأقسام الأخرى',
              amount: '10 ر.س',
              note: '(تُدفع بعد البيع)',
              amountColor: _amountOrange,
              shaded: true,
            ),
            _feeRow(
              category: '💼 الوظائف',
              amount: 'مجاني بالكامل',
              amountColor: _amountGreen,
              shaded: false,
            ),
          ],
        ),
      ),
    );
  }

  static TableRow _feeRow({
    required String category,
    required String amount,
    required Color amountColor,
    required bool shaded,
    String? note,
    Color noteColor = _noteOrange,
  }) {
    return TableRow(
      decoration: BoxDecoration(
        color: shaded ? const Color(0xFFFAFAFA) : Colors.white,
      ),
      children: [
        _TableCell(
          child: Text(
            category,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.neutralGray700,
            ),
          ),
        ),
        _TableCell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: amountColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: amountColor.withValues(alpha: 0.35),
                  ),
                ),
                child: RiyalText(
                  amount,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: amountColor,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
              if (note != null) ...[
                const SizedBox(height: 4),
                Text(
                  note,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: noteColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: child,
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList(this.items);

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                textDirection: TextDirection.rtl,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: AppTheme.neutralGray400,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.neutralGray700,
                        height: 1.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
