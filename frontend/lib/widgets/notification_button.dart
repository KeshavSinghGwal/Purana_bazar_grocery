import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/notifications/notifications_screen.dart';
import '../state/notification_provider.dart';
import '../core/localization.dart';

class NotificationButton extends StatelessWidget {
  const NotificationButton({super.key});

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<NotificationProvider>().unread;
    return IconButton(
      tooltip: context.tr('Notifications'),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      ),
      icon: Badge.count(
        count: unread > 99 ? 99 : unread,
        isLabelVisible: unread > 0,
        backgroundColor: const Color(0xFFD32F2F),
        textColor: Colors.white,
        child: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }
}
