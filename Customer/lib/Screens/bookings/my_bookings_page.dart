import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyBookingsPage extends StatefulWidget {
  const MyBookingsPage({super.key});

  @override
  State<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _bookings = [];

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final restaurantsSnapshot = await _firestore.collection("restaurants").get();
      
      List<Map<String, dynamic>> allBookings = [];

      for (var restaurantDoc in restaurantsSnapshot.docs) {
        final restaurantData = restaurantDoc.data();
        final restaurantName = restaurantData['name'] ?? 'Unknown Restaurant';
        final tables = restaurantData['tables'] as List<dynamic>? ?? [];

        for (var table in tables) {
          if (table is Map<String, dynamic>) {
            final reservations = table['reservations'] as List<dynamic>? ?? [];
            final tableId = table['tableId'] ?? 'Unknown';
            final seats = table['seats'] ?? 0;

            for (var reservation in reservations) {
              if (reservation is Map<String, dynamic>) {
                if (reservation['userId'] == user.uid) {
                  allBookings.add({
                    'restaurantId': restaurantDoc.id,
                    'restaurantName': restaurantName,
                    'tableId': tableId,
                    'tableSeats': seats,
                    'date': reservation['date'],
                    'timeSlot': reservation['timeSlot'],
                    'seats': reservation['seats'] ?? seats,
                    'bookedAt': reservation['bookedAt'],
                  });
                }
              }
            }
          }
        }
      }

      // Sort by date (newest first)
      allBookings.sort((a, b) {
        final dateA = a['date'] as String? ?? '';
        final dateB = b['date'] as String? ?? '';
        final comparison = dateB.compareTo(dateA);
        if (comparison != 0) return comparison;
        final timeA = a['timeSlot'] as String? ?? '';
        final timeB = b['timeSlot'] as String? ?? '';
        return timeA.compareTo(timeB);
      });

      setState(() {
        _bookings = allBookings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading bookings: $e")),
        );
      }
    }
  }

  Future<void> _deleteBooking(Map<String, dynamic> booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Booking"),
        content: Text(
          "Are you sure you want to cancel your booking at ${booking['restaurantName']} on ${booking['date']} at ${booking['timeSlot']}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Yes, Cancel"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final docRef = _firestore.collection("restaurants").doc(booking['restaurantId']);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception("Restaurant not found");
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final tables = List<Map<String, dynamic>>.from(
            (data['tables'] as List<dynamic>).map((t) => Map<String, dynamic>.from(t)));

        final tableIndex = tables.indexWhere(
            (t) => t['tableId'] == booking['tableId']);

        if (tableIndex == -1) {
          throw Exception("Table not found");
        }

        final targetTable = tables[tableIndex];
        final reservations = List<Map<String, dynamic>>.from(
            (targetTable['reservations'] as List<dynamic>?)?.map((r) {
              if (r is Map<String, dynamic>) return Map<String, dynamic>.from(r);
              return {'legacy': r.toString()};
            }) ?? []);

        // Remove the reservation matching this booking
        reservations.removeWhere((r) =>
            r['userId'] == user.uid &&
            r['date'] == booking['date'] &&
            r['timeSlot'] == booking['timeSlot']);

        targetTable['reservations'] = reservations;
        tables[tableIndex] = targetTable;

        transaction.update(docRef, {'tables': tables});
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Booking cancelled successfully"),
            backgroundColor: Colors.green,
          ),
        );
        _loadBookings(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error cancelling booking: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _isUpcoming(String? dateStr) {
    if (dateStr == null) return false;
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return false;
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      return !date.isBefore(todayDate);
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "My Bookings",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            onPressed: _loadBookings,
            tooltip: "Refresh",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No bookings yet",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Book a table at your favorite restaurant!",
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBookings,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _bookings.length,
                    itemBuilder: (context, index) {
                      final booking = _bookings[index];
                      final isUpcoming = _isUpcoming(booking['date']);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 5,
                            ),
                          ],
                          border: isUpcoming
                              ? Border.all(color: Colors.deepOrange.withOpacity(0.3), width: 2)
                              : null,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      booking['restaurantName'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isUpcoming
                                          ? Colors.green[100]
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isUpcoming ? "Upcoming" : "Past",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isUpcoming
                                            ? Colors.green[700]
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Date and time
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    booking['date'] ?? 'Unknown date',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    booking['timeSlot'] ?? 'Unknown time',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Table info
                              Row(
                                children: [
                                  Icon(
                                    Icons.table_restaurant,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Table ${booking['tableId']}",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.people,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${booking['seats']} seats",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Cancel button (only for upcoming)
                              if (isUpcoming)
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _deleteBooking(booking),
                                    icon: const Icon(Icons.cancel_outlined, size: 18),
                                    label: const Text("Cancel Booking"),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
