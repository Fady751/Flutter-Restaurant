import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RestaurantDetailsPage extends StatelessWidget {
  final String restaurantId;

  const RestaurantDetailsPage({super.key, required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Restaurant Details")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("restaurants")
            .doc(restaurantId)
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
          final categories = data['categories'] as List<dynamic>? ?? [];
          final location = data['location'] as Map<String, dynamic>?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo
                if (data['photoUrl'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      data['photoUrl'],
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Center(child: Icon(Icons.image, size: 50)),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Name
                Text(
                  data['name'] ?? 'No name',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // Categories
                if (categories.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: categories.map((cat) => Chip(
                      label: Text(cat.toString()),
                      backgroundColor: Colors.orange[100],
                    )).toList(),
                  ),
                const SizedBox(height: 16),

                // Description
                if (data['description'] != null && data['description'].toString().isNotEmpty) ...[
                  const Text(
                    "Description",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['description'],
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                ],

                // Location with Google Map
                if (location != null && location['lat'] != null && location['lng'] != null) ...[
                  const Text(
                    "Sales Point Location",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                      color: Colors.blue[50],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_on, size: 40, color: Colors.red),
                          const SizedBox(height: 8),
                          Text(
                            'Lat: ${(location['lat'] as num).toStringAsFixed(6)}',
                            style: TextStyle(color: Colors.grey[700], fontSize: 12),
                          ),
                          Text(
                            'Lng: ${(location['lng'] as num).toStringAsFixed(6)}',
                            style: TextStyle(color: Colors.grey[700], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (location['address'] != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.red),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location['address'].toString(),
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                ],

                // Time slots
                const Text(
                  "Time Slots",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (timeSlots.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: timeSlots.map((slot) => Chip(
                      avatar: const Icon(Icons.access_time, size: 16),
                      label: Text(slot.toString()),
                    )).toList(),
                  )
                else
                  const Text("No time slots available"),
                const SizedBox(height: 16),

                // Tables & bookings
                const Text(
                  "Tables & Bookings",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (tables.isNotEmpty)
                  ...tables.map((table) {
                    final t = table as Map<String, dynamic>;
                    final reservations = t['reservations'] as List<dynamic>? ?? [];
                    final bookedCount = reservations.length;
                    final totalSlots = timeSlots.length;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ExpansionTile(
                        leading: const Icon(Icons.table_restaurant),
                        title: Text("Table ${t['tableId']} - ${t['seats']} Seats"),
                        subtitle: Text(
                          bookedCount > 0 
                              ? "$bookedCount/$totalSlots slots booked" 
                              : "All slots available",
                          style: TextStyle(
                            color: bookedCount > 0 ? Colors.orange : Colors.green,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Reservations:", style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                if (reservations.isEmpty)
                                  const Text("No bookings yet")
                                else
                                  ...reservations.map((r) {
                                    if (r is Map) {
                                      return ListTile(
                                        dense: true,
                                        leading: const Icon(Icons.event, size: 20),
                                        title: Text("Time: ${r['timeSlot'] ?? 'N/A'}"),
                                        subtitle: r['customerName'] != null
                                            ? Text("Customer: ${r['customerName']}")
                                            : null,
                                      );
                                    }
                                    return Text("• $r");
                                  }).toList(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList()
                else
                  const Text("No tables available"),
              ],
            ),
          );
        },
      ),
    );
  }
}
