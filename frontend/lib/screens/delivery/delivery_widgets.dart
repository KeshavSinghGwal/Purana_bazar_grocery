import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

class DeliveryOrderCard extends StatelessWidget {
  const DeliveryOrderCard({
    super.key,
    required this.order,
    this.onAccept,
    this.onAdvance,
    this.busy = false,
  });

  final Order order;
  final VoidCallback? onAccept;
  final VoidCallback? onAdvance;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final distance = _distanceKm(
      order.shop.latitude,
      order.shop.longitude,
      order.deliveryLatitude,
      order.deliveryLongitude,
    );
    final actionLabel = onAccept != null
        ? 'Accept delivery'
        : order.orderStatus == 'READY_FOR_PICKUP'
            ? 'Mark picked up'
            : order.orderStatus == 'OUT_FOR_DELIVERY'
                ? 'Mark delivered'
                : null;
    final action = onAccept ?? onAdvance;

    return AppCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${compactDate(order.createdAt)} · ${distance.toStringAsFixed(1)} km trip',
                      style: const TextStyle(fontSize: 9.5, color: AppColors.soft),
                    ),
                  ],
                ),
              ),
              StatusPill(status: order.orderStatus),
            ],
          ),
          const Divider(height: 20),
          _stop(
            icon: Icons.storefront_rounded,
            color: AppColors.green,
            eyebrow: 'PICK UP',
            title: order.shop.name,
            subtitle: order.shop.address,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 9),
            child: Row(
              children: [
                Container(
                  width: 2,
                  height: 16,
                  color: AppColors.border,
                ),
              ],
            ),
          ),
          _stop(
            icon: Icons.location_on_rounded,
            color: AppColors.orange,
            eyebrow: 'DROP OFF',
            title: order.customerName,
            subtitle: order.deliveryAddress,
            trailing: order.customerPhone,
          ),
          const SizedBox(height: 10),
          Text(
            order.items.map((item) => '${item.productName} × ${item.quantity}').join('  ·  '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, height: 1.45, color: AppColors.muted),
          ),
          if (order.customerNote != null) ...[
            const SizedBox(height: 5),
            Text(
              'Note: ${order.customerNote}',
              style: const TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: AppColors.muted,
              ),
            ),
          ],
          const SizedBox(height: 11),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.paleMint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.paymentMethod == 'COD'
                      ? 'Collect ${rupee(order.totalAmount)}'
                      : 'Prepaid · ${rupee(order.totalAmount)}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkGreen,
                  ),
                ),
              ),
              const Spacer(),
              if (action != null && actionLabel != null)
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: busy ? null : action,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(126, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(actionLabel),
                  ),
                )
              else if (order.orderStatus == 'DELIVERED')
                const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 15, color: AppColors.green),
                    SizedBox(width: 4),
                    Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stop({
    required IconData icon,
    required Color color,
    required String eyebrow,
    required String title,
    required String subtitle,
    String? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 12, color: color),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                  color: color,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Text(
            trailing,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ],
    );
  }

  static double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;
    final dLat = _radians(lat2 - lat1);
    final dLon = _radians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}
