/// Formats integer naira the same way in every language: `₦1,250,000`, and `−₦3,000` (a true minus sign) for debits.
/// Grouping is a fixed `,` on purpose: the figures are currency amounts the server computed, and a locale-dependent
/// separator would make the same balance read differently in English, French and Pidgin.
String formatNaira(int amount) {
  final grouped = amount.abs().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return amount < 0 ? '−₦$grouped' : '₦$grouped';
}
