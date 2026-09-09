import 'package:flutter/material.dart';

class DealerVehicleCommissionNotice extends StatelessWidget {
  const DealerVehicleCommissionNotice({super.key});

  @override
  Widget build(BuildContext context) {
    const foreground = Color(0xFF7A4100);
    return Semantics(
      container: true,
      label:
          'توضيح عمولة المعرض. عمولة السيارات والمركبات للمعارض ٣٥ ريالًا بعد إتمام البيع، وتكون في الذمة.',
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: const Color(0xFFFFF7E6),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 22,
              color: foreground,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'توضيح للمعرض: عمولة السيارات والمركبات ٣٥ ريالًا بعد إتمام البيع، وتكون في الذمة.',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: foreground,
                  fontSize: 14,
                  height: 1.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
