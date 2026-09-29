class CurrencyFormatter {
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  static String formatRupiah(num amount) {
    final int value = amount.round();
    final String str = value.abs().toString();
    final StringBuffer buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    final formatted = buffer.toString().split('').reversed.join('');
    final prefix = amount < 0 ? '-Rp ' : 'Rp ';
    return '$prefix$formatted';
  }

  static String formatKg(double weight) {
    if (weight % 1 == 0) {
      return '${weight.toInt()} kg';
    }
    return '${weight.toStringAsFixed(1)} kg';
  }

  static String formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = _months[date.month - 1];
    final String year = date.year.toString();
    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$minute';
  }

  static String formatDateShort(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = _months[date.month - 1];
    final String year = date.year.toString();
    return '$day $month $year';
  }
}
