import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import 'app_theme.dart';
import 'localization.dart';

String rupee(num value) => '₹${money(value.toDouble())}';

String compactDate(DateTime? date) {
  if (date == null) return '';
  return DateFormat('d MMM, h:mm a').format(date);
}

String fullDate(DateTime? date) {
  if (date == null) return '—';
  return DateFormat('d MMM yyyy, h:mm a').format(date);
}

String friendlyTime(String raw) {
  final parts = raw.split(':');
  if (parts.length < 2) return raw;
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = int.tryParse(parts[1]) ?? 0;
  final date = DateTime(2026, 1, 1, hour, minute);
  return DateFormat('h:mm a').format(date);
}

String statusLabel(String status) {
  final label = status
      .toLowerCase()
      .split('_')
      .map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
  return AppLocalizations.current.tr(label);
}

Color statusColor(String status) {
  switch (status) {
    case 'DELIVERED':
    case 'PAID':
    case 'APPROVED':
    case 'ACTIVE':
      return AppColors.green;
    case 'PENDING':
    case 'PENDING_APPROVAL':
    case 'PAYMENT_PENDING':
      return const Color(0xFFB26A00);
    case 'REJECTED':
    case 'CANCELLED':
    case 'FAILED':
    case 'PAYMENT_FAILED':
    case 'SUSPENDED':
    case 'TEMPORARILY_CLOSED':
      return AppColors.red;
    case 'ACCEPTED':
    case 'PREPARING':
    case 'READY_FOR_PICKUP':
      return const Color(0xFF1565C0);
    case 'OUT_FOR_DELIVERY':
      return AppColors.orange;
    case 'REFUNDED':
      return const Color(0xFF6A1B9A);
    default:
      return AppColors.muted;
  }
}

Color statusBackground(String status) => statusColor(status).withValues(alpha: 0.10);

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: error ? AppColors.red : AppColors.ink,
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: AppText(message)),
          ],
        ),
      ),
    );
}

String orderItemSummary(Order order) {
  if (order.items.isEmpty) return AppLocalizations.current.tr('No items');
  final first = order.items.first.productName;
  if (order.items.length == 1) return first;
  return AppLocalizations.current
      .tr('$first + ${order.items.length - 1} more');
}

String initials(String name) {
  final pieces = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (pieces.isEmpty) return 'PB';
  if (pieces.length == 1) return pieces.first.substring(0, 1).toUpperCase();
  return '${pieces.first[0]}${pieces.last[0]}'.toUpperCase();
}
