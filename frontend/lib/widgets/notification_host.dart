import 'dart:async';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../theme.dart';

class NotificationHost extends StatefulWidget {
  final Widget child;
  const NotificationHost({super.key, required this.child});

  @override
  State<NotificationHost> createState() => NotificationHostState();
}

class NotificationHostState extends State<NotificationHost> {
  final List<_ActiveNotification> _notifications = [];
  static const int _maxVisible = 3;
  static const Duration _defaultDuration = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    NotificationService().register(addNotification);
  }

  @override
  void dispose() {
    NotificationService().unregister(addNotification);
    for (final n in _notifications) {
      n.timer?.cancel();
    }
    super.dispose();
  }

  // Called by NotificationService singleton; analyzer cannot detect indirect usage.
  void addNotification(NotificationData data) {
    if (_notifications.length >= _maxVisible) {
      final oldest = _notifications.first;
      oldest.timer?.cancel();
      _remove(oldest);
    }

    final active = _ActiveNotification(data: data);
    setState(() => _notifications.add(active));

    active.timer = Timer(_defaultDuration, () {
      if (mounted) _remove(active);
    });
  }

  void _remove(_ActiveNotification active) {
    active.timer?.cancel();
    if (!mounted) return;
    setState(() => _notifications.remove(active));
  }

  IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return Icons.check_circle_outline;
      case NotificationType.error:
        return Icons.error_outline;
      case NotificationType.warning:
        return Icons.warning_amber_outlined;
      case NotificationType.info:
        return Icons.info_outline;
    }
  }

  Color _colorFor(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return AppTheme.success;
      case NotificationType.error:
        return AppTheme.danger;
      case NotificationType.warning:
        return AppTheme.warning;
      case NotificationType.info:
        return AppTheme.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 20,
          right: 20,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _notifications.map((active) {
                return _NotificationItem(
                  data: active.data,
                  icon: _iconFor(active.data.type),
                  color: _colorFor(active.data.type),
                  onDismiss: () => _remove(active),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActiveNotification {
  final NotificationData data;
  Timer? timer;
  _ActiveNotification({required this.data});
}

class _NotificationItem extends StatelessWidget {
  final NotificationData data;
  final IconData icon;
  final Color color;
  final VoidCallback onDismiss;

  const _NotificationItem({
    required this.data,
    required this.icon,
    required this.color,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            color: AppTheme.bgElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Life track
                Container(
                  height: 3,
                  color: color.withValues(alpha: 0.25),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 1.0, end: 0.0),
                        duration: const Duration(seconds: 4),
                        builder: (context, value, child) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: constraints.maxWidth * value,
                              height: 3,
                              color: color,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: color, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              data.title,
                              style: const TextStyle(
                                color: AppTheme.text,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                            if (data.detail != null && data.detail!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                data.detail!,
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: onDismiss,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close, color: AppTheme.textMuted, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
