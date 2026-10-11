/// Formats a coin amount the same way in every language: `1,200`, and `−150` (a true minus sign) for a debit.
/// Grouping is a fixed `,` so one balance reads identically in English, French and Pidgin.
String formatCoins(int amount) {
  final grouped = amount.abs().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return amount < 0 ? '−$grouped' : grouped;
}
