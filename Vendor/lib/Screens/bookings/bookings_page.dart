import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? selectedRestaurantId;
  String? selectedRestaurantName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bookings"),
      ),
      body: Column(
        children: [
          // Restaurant Selector
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection("restaurants").snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text("No restaurants available"),
                );
              }

              final restaurants = snapshot.data!.docs;

              return Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<String>(
                  value: selectedRestaurantId,
                  decoration: const InputDecoration(
                    labelText: "Select Restaurant",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.restaurant),
                  ),
                  items: restaurants.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(data['name'] ?? 'Unknown'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    final selected = restaurants.firstWhere((doc) => doc.id == value);
                    final data = selected.data() as Map<String, dynamic>;
                    setState(() {
                      selectedRestaurantId = value;
                      selectedRestaurantName = data['name'];
                    });
                  },
                ),
              );
            },
          ),

          // Bookings Display
          Expanded(
            child: selectedRestaurantId == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.table_restaurant, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          "Select a restaurant to view bookings",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : StreamBuilder<DocumentSnapshot>(
                    stream: _firestore
                        .collection("restaurants")
                        .doc(selectedRestaurantId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return const Center(child: Text("Restaurant not found"));
                      }

                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      final tables = data['tables'] as List<dynamic>? ?? [];
                      final timeSlots = data['timeSlots'] as List<dynamic>? ?? [];

                      if (tables.isEmpty) {
                        return const Center(child: Text("No tables configured"));
                      }

                      return _buildBookingsGrid(tables, timeSlots);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsGrid(List<dynamic> tables, List<dynamic> timeSlots) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selectedRestaurantName ?? "Restaurant",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "${tables.length} Tables • ${timeSlots.length} Time Slots",
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),

          // Legend
          Row(
            children: [
              _buildLegendItem(Colors.green[100]!, "Available"),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.red[100]!, "Booked"),
            ],
          ),
          const SizedBox(height: 16),

          // Tables Grid
          ...tables.map((table) {
            final tableData = table as Map<String, dynamic>;
            final tableId = tableData['tableId'];
            final seats = tableData['seats'];
            final reservations = tableData['reservations'] as List<dynamic>? ?? [];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.table_restaurant, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              "Table $tableId",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Chip(
                          label: Text("$seats seats"),
                          avatar: const Icon(Icons.person, size: 16),
                        ),
                      ],
                    ),
                    const Divider(),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: timeSlots.map((slot) {
                        final isBooked = reservations.any((r) {
                          if (r is Map) {
                            return r['timeSlot'] == slot;
                          }
                          return r == slot;
                        });

                        // Get booking details if booked
                        Map<String, dynamic>? bookingDetails;
                        if (isBooked) {
                          final booking = reservations.firstWhere(
                            (r) {
                              if (r is Map) {
                                return r['timeSlot'] == slot;
                              }
                              return r == slot;
                            },
                            orElse: () => null,
                          );
                          if (booking is Map) {
                            bookingDetails = Map<String, dynamic>.from(booking);
                          }
                        }

                        return GestureDetector(
                          onTap: isBooked
                              ? () => _showBookingDetails(
                                    tableId,
                                    slot.toString(),
                                    bookingDetails,
                                  )
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isBooked ? Colors.red[100] : Colors.green[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isBooked ? Colors.red : Colors.green,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isBooked ? Icons.event_busy : Icons.event_available,
                                  size: 16,
                                  color: isBooked ? Colors.red[800] : Colors.green[800],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  slot.toString(),
                                  style: TextStyle(
                                    color: isBooked ? Colors.red[800] : Colors.green[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (reservations.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        "${reservations.length} booking(s)",
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }

  void _showBookingDetails(int tableId, String timeSlot, Map<String, dynamic>? details) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.event_note),
            const SizedBox(width: 8),
            Text("Table $tableId - $timeSlot"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (details != null) ...[
              if (details['customerName'] != null)
                _buildDetailRow("Customer", details['customerName']),
              if (details['customerPhone'] != null)
                _buildDetailRow("Phone", details['customerPhone']),
              if (details['guests'] != null)
                _buildDetailRow("Guests", details['guests'].toString()),
              if (details['date'] != null)
                _buildDetailRow("Date", details['date']),
              if (details['bookedAt'] != null)
                _buildDetailRow("Booked At", _formatTimestamp(details['bookedAt'])),
            ] else
              const Text("Booking confirmed for this time slot."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    }
    return timestamp.toString();
  }
}
