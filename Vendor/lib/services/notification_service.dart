import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Listen to booking changes for a restaurant
  Stream<List<Map<String, dynamic>>> listenToBookings(String restaurantId) {
    return _firestore
        .collection("restaurants")
        .doc(restaurantId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return [];
      
      final data = snapshot.data() as Map<String, dynamic>;
      final tables = data['tables'] as List<dynamic>? ?? [];
      
      List<Map<String, dynamic>> allBookings = [];
      
      for (var table in tables) {
        final tableData = table as Map<String, dynamic>;
        final reservations = tableData['reservations'] as List<dynamic>? ?? [];
        
        for (var reservation in reservations) {
          if (reservation is Map<String, dynamic>) {
            allBookings.add({
              ...reservation,
              'tableId': tableData['tableId'],
              'seats': tableData['seats'],
            });
          }
        }
      }
      
      return allBookings;
    });
  }

  // Get all notifications for vendor
  Stream<QuerySnapshot> getNotifications() {
    return _firestore
        .collection("vendor_notifications")
        .orderBy("createdAt", descending: true)
        .limit(50)
        .snapshots();
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection("vendor_notifications")
        .doc(notificationId)
        .update({'isRead': true});
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    final notifications = await _firestore
        .collection("vendor_notifications")
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (var doc in notifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // Delete old notifications (cleanup)
  Future<void> deleteOldNotifications({int daysOld = 30}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
    
    final oldNotifications = await _firestore
        .collection("vendor_notifications")
        .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
        .get();

    final batch = _firestore.batch();
    for (var doc in oldNotifications.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
