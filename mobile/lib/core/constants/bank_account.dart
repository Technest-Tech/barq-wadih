/// Static bank-transfer details for paying the after-sale commission while the
/// payment gateways are not yet live. The QR asset encodes the same details for
/// scan-to-pay from a banking app.
class BankAccount {
  static const String bankName = 'مصرف الراجحي';
  static const String accountName = 'مؤسسة برق واضح';
  static const String accountNumber = '433000010006086240365';
  static const String iban = 'SA9080000433608016240365';
  static const String qrAsset = 'assets/images/bank_account.jpeg';
}
