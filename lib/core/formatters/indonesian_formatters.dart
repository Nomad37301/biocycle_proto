import 'package:intl/intl.dart';

abstract final class IndonesianFormatters {
  static final NumberFormat _decimal0 = NumberFormat.decimalPatternDigits(
    locale: 'id_ID',
    decimalDigits: 0,
  );
  static final NumberFormat _decimal1 = NumberFormat.decimalPatternDigits(
    locale: 'id_ID',
    decimalDigits: 1,
  );
  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  static String number(double value, {int decimalDigits = 1}) {
    if (decimalDigits == 0) return _decimal0.format(value);
    if (decimalDigits == 1) return _decimal1.format(value);
    return NumberFormat.decimalPatternDigits(
      locale: 'id_ID',
      decimalDigits: decimalDigits,
    ).format(value);
  }

  static String currency(num value) => _currency.format(value);

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static String dateTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${_months[local.month - 1]} ${local.year}, $hour.$minute';
  }

  static String time(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}.${local.minute.toString().padLeft(2, '0')}';
  }

  static String relativeAge(DateTime value, DateTime now) {
    final age = now.difference(value);
    if (age.isNegative || age.inSeconds < 5) return 'baru saja';
    if (age.inSeconds < 60) return '${age.inSeconds} detik lalu';
    if (age.inMinutes < 60) return '${age.inMinutes} menit lalu';
    if (age.inHours < 24) return '${age.inHours} jam lalu';
    return dateTime(value);
  }
}
