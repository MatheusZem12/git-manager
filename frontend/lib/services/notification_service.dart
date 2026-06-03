enum NotificationType { success, error, warning, info }

class NotificationData {
  final String title;
  final String? detail;
  final NotificationType type;
  final DateTime createdAt;

  NotificationData({
    required this.title,
    this.detail,
    required this.type,
  }) : createdAt = DateTime.now();
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  void Function(NotificationData)? _onAdd;

  void register(void Function(NotificationData) callback) => _onAdd = callback;
  void unregister(void Function(NotificationData) callback) {
    if (_onAdd == callback) _onAdd = null;
  }

  void showSuccess(String title, {String? detail}) =>
      _show(title: title, detail: detail, type: NotificationType.success);
  void showError(String title, {String? detail}) =>
      _show(title: title, detail: detail, type: NotificationType.error);
  void showWarning(String title, {String? detail}) =>
      _show(title: title, detail: detail, type: NotificationType.warning);
  void showInfo(String title, {String? detail}) =>
      _show(title: title, detail: detail, type: NotificationType.info);

  void _show({
    required String title,
    String? detail,
    required NotificationType type,
  }) {
    _onAdd?.call(NotificationData(
      title: title,
      detail: detail,
      type: type,
    ));
  }
}
