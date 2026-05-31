import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/notification_model.dart';
import 'auth_service.dart';

class NotificationService extends ChangeNotifier {
  final Dio _dio;
  
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  NotificationService(AuthService authService) : _dio = authService.dio; // Reuse Dio from AuthService

  Future<void> fetchNotifications({bool refresh = false}) async {
    if (_isLoading && !refresh) return;
    
    _isLoading = true;
    if (refresh) notifyListeners(); // Only notify if full refresh to show spinner

    try {
      final response = await _dio.get(
        ApiConstants.notifications, 
        queryParameters: {'limit': 20}
      );

      if (response.statusCode == 200 && response.data['ok']) {
         final List list = response.data['data'];
         _notifications = list.map((e) => NotificationModel.fromJson(e)).toList();
         _unreadCount = response.data['unread_count'] ?? 0;
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      // Optimistic Update
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1 && !_notifications[index].isRead) {
        _notifications[index] = NotificationModel(
          id: _notifications[index].id,
          title: _notifications[index].title,
          message: _notifications[index].message,
          type: _notifications[index].type,
          isRead: true,
          createdAt: _notifications[index].createdAt,
        );
        _unreadCount = (_unreadCount - 1).clamp(0, 999);
        notifyListeners();
      }

      await _dio.put(ApiConstants.notificationMarkRead.replaceAll(':id', notificationId.toString()));
    } catch (e) {
       debugPrint('Error marking notification read: $e');
       // Revert on failure if needed (skipped for simplicity)
    }
  }

  Future<void> markAllAsRead() async {
     try {
       // Optimistic Update
       _notifications = _notifications.map((n) => NotificationModel(
          id: n.id,
          title: n.title,
          message: n.message,
          type: n.type,
          isRead: true, 
          createdAt: n.createdAt,
       )).toList();
       
       _unreadCount = 0;
       notifyListeners();

       await _dio.put(ApiConstants.notificationsReadAll);
     } catch (e) {
       debugPrint('Error marking all notifications read: $e');
     }
  }
}
