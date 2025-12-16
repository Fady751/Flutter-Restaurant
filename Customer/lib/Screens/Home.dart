import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Auth/login.dart';
import 'bookings/my_bookings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";
  String? _selectedCategory;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.toLowerCase();
      });
    });
  }

  Future<void> _loadCategories() async {
    final result = await firestore.collection("categories").get();
    setState(() {
      _categories = result.docs.isEmpty
          ? ["All", "Fast Food", "Fine Dining", "Cafe", "Italian", "Asian"]
          : ["All", ...result.docs.map((e) => e['name'] as String)];
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
    );
  }

  void goToRestaurantDetails(DocumentSnapshot restaurant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantDetailsPage(restaurantId: restaurant.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Discover",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outlined, color: Colors.deepOrange),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyBookingsPage()),
              );
            },
            tooltip: "My Bookings",
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black54),
            onPressed: _logout,
            tooltip: "Logout",
          ),
        ],
      ),
      body: Column(
        children: [
          // Modern Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: "Search restaurants...",
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ),
          ),

          // Category Filter
          if (_categories.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category ||
                      (_selectedCategory == null && category == "All");
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = category == "All" ? null : category;
                        });
                      },
                      selectedColor: Colors.orange,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? Colors.orange : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 8),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: firestore.collection("restaurants").snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          "No restaurants found.",
                          style: TextStyle(color: Colors.grey[500], fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                final restaurants = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? "").toString().toLowerCase();
                  final categories = data['categories'] as List<dynamic>? ?? [];
                  
                  // Search filter
                  final matchesSearch = name.contains(_searchText);
                  
                  // Category filter
                  final matchesCategory = _selectedCategory == null ||
                      categories.contains(_selectedCategory);
                  
                  return matchesSearch && matchesCategory;
                }).toList();

                if (restaurants.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          "No restaurants match your search.",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: restaurants.length,
                  itemBuilder: (context, index) {
                    final restaurant = restaurants[index];
                    final data = restaurant.data() as Map<String, dynamic>;
                    final categories = data['categories'] as List<dynamic>? ?? [];

                    return GestureDetector(
                      onTap: () => goToRestaurantDetails(restaurant),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              spreadRadius: 0,
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Image Section
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                              child: Stack(
                                children: [
                                  data['photoUrl'] != null
                                      ? Image.network(
                                          data['photoUrl'],
                                          height: 200,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              Container(
                                            height: 200,
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.restaurant,
                                                size: 50, color: Colors.grey),
                                          ),
                                        )
                                      : Container(
                                          height: 200,
                                          color: Colors.grey[200],
                                          child: const Icon(Icons.restaurant,
                                              size: 50, color: Colors.grey),
                                        ),
                                  // Gradient Overlay
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.1),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Info Section
                            Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          data['name'] ?? "Unknown Restaurant",
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.star,
                                                size: 16, color: Colors.orange),
                                            SizedBox(width: 4),
                                            Text(
                                              "4.5",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.orange),
                                            ),
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (categories.isNotEmpty)
                                    Text(
                                      categories.join(' • '),
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  else
                                    Text(
                                      "Restaurant",
                                      style: TextStyle(
                                          color: Colors.grey[600], fontSize: 15),
                                    ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on_outlined,
                                          size: 18, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          "1.2 km away", // Placeholder
                                          style: TextStyle(color: Colors.grey[500]),
                                        ),
                                      ),
                                      Text(
                                        "20-30 min",
                                        style: TextStyle(
                                            color: Colors.grey[500],
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class RestaurantDetailsPage extends StatelessWidget {
  final String restaurantId;

  const RestaurantDetailsPage({super.key, required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300.0,
                floating: false,
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    data['name'] ?? 'Restaurant',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 10)],
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      data['photoUrl'] != null
                          ? Image.network(
                              data['photoUrl'],
                              fit: BoxFit.cover,
                            )
                          : Container(color: Colors.grey),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Categories
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categories
                            .map((cat) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    cat.toString(),
                                    style: const TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 24),

                      const Text("About",
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(
                        data['description'] ?? 'No description available.',
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            height: 1.6),
                      ),
                      const SizedBox(height: 32),

                      // Book a Table Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange.shade400, Colors.deepOrange.shade400],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.table_restaurant, color: Colors.white, size: 40),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Book a Table",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Reserve your spot now!",
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BookingPage(
                                      restaurantId: restaurantId,
                                      restaurantName: data['name'] ?? 'Restaurant',
                                      tables: tables,
                                      timeSlots: timeSlots,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.deepOrange,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                              ),
                              child: const Text("Book Now",
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),

                      const Text("Available Times",
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      if (timeSlots.isNotEmpty)
                        SizedBox(
                          height: 50,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: timeSlots.length,
                            itemBuilder: (context, index) {
                              return Container(
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: Colors.blue.withOpacity(0.2))),
                                child: Center(
                                    child: Text(timeSlots[index].toString(),
                                        style: const TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold))),
                              );
                            },
                          ),
                        )
                      else
                        Text("No time slots available",
                            style: TextStyle(color: Colors.grey[500])),
                      const SizedBox(height: 32),

                      const Text("Tables",
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      if (tables.isNotEmpty)
                        ...tables.map((table) {
                          final t = table as Map<String, dynamic>;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade100),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.grey.shade100,
                                      blurRadius: 10,
                                      offset: const Offset(0, 4))
                                ]),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.table_restaurant,
                                      color: Colors.black54),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Table ${t['tableId']}",
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text("${t['seats']} Seats",
                                        style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 14)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList()
                      else
                        Text("No tables available",
                            style: TextStyle(color: Colors.grey[500])),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Booking Page with seat selection, date picker, and real-time slot availability
class BookingPage extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;
  final List<dynamic> tables;
  final List<dynamic> timeSlots;

  const BookingPage({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    required this.tables,
    required this.timeSlots,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  int _selectedSeats = 2;
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  Map<String, dynamic>? _selectedTable;
  bool _isLoading = false;

  // Real-time stream for reservations
  Stream<DocumentSnapshot>? _restaurantStream;

  @override
  void initState() {
    super.initState();
    _restaurantStream = FirebaseFirestore.instance
        .collection("restaurants")
        .doc(widget.restaurantId)
        .snapshots();
  }

  // Get available tables for selected seats
  List<Map<String, dynamic>> _getAvailableTables(List<dynamic> tables) {
    return tables
        .where((t) => (t as Map<String, dynamic>)['seats'] >= _selectedSeats)
        .map((t) => t as Map<String, dynamic>)
        .toList();
  }

  // Check if a time slot is already booked for a table on a specific date
  bool _isSlotBooked(Map<String, dynamic> table, String dateStr, String timeSlot) {
    final reservations = table['reservations'] as List<dynamic>? ?? [];
    for (var reservation in reservations) {
      if (reservation is Map<String, dynamic>) {
        if (reservation['date'] == dateStr && reservation['timeSlot'] == timeSlot) {
          return true;
        }
      } else if (reservation is String) {
        // Legacy format: "2025-01-15 10:00 - CustomerName"
        if (reservation.startsWith("$dateStr $timeSlot")) {
          return true;
        }
      }
    }
    return false;
  }

  // Get available time slots for a specific table and date
  List<String> _getAvailableTimeSlots(Map<String, dynamic> table, String dateStr) {
    return widget.timeSlots
        .map((slot) => slot.toString())
        .where((slot) => !_isSlotBooked(table, dateStr, slot))
        .toList();
  }

  Future<void> _confirmBooking() async {
    if (_selectedDate == null || _selectedTimeSlot == null || _selectedTable == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all booking details")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login to book a table")),
      );
      setState(() => _isLoading = false);
      return;
    }

    final dateStr = "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
    
    try {
      final docRef = FirebaseFirestore.instance
          .collection("restaurants")
          .doc(widget.restaurantId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception("Restaurant not found");
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final tables = List<Map<String, dynamic>>.from(
            (data['tables'] as List<dynamic>).map((t) => Map<String, dynamic>.from(t)));

        final tableIndex = tables.indexWhere(
            (t) => t['tableId'] == _selectedTable!['tableId']);

        if (tableIndex == -1) {
          throw Exception("Table not found");
        }

        final targetTable = tables[tableIndex];
        
        // Check if slot is still available (real-time conflict check)
        if (_isSlotBooked(targetTable, dateStr, _selectedTimeSlot!)) {
          throw Exception("This time slot has just been booked by another customer. Please select a different time.");
        }

        final reservations = List<Map<String, dynamic>>.from(
            (targetTable['reservations'] as List<dynamic>?)?.map((r) {
              if (r is Map<String, dynamic>) return r;
              // Convert legacy string format
              return {'legacy': r.toString()};
            }) ?? []);

        // Add new reservation with all details
        reservations.add({
          'date': dateStr,
          'timeSlot': _selectedTimeSlot,
          'seats': _selectedSeats,
          'userId': user.uid,
          'userEmail': user.email,
          'bookedAt': DateTime.now().toIso8601String(),
        });

        targetTable['reservations'] = reservations;
        tables[tableIndex] = targetTable;

        transaction.update(docRef, {'tables': tables});
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Table booked successfully for $dateStr at $_selectedTimeSlot!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst("Exception: ", "")),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        title: Text(
          "Book at ${widget.restaurantName}",
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _restaurantStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          List<dynamic> currentTables = widget.tables;
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            currentTables = data['tables'] as List<dynamic>? ?? widget.tables;
          }

          final availableTables = _getAvailableTables(currentTables);
          final dateStr = _selectedDate != null
              ? "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}"
              : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step 1: Number of Seats
                _buildSectionTitle("1. Number of Seats", Icons.people),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        "$_selectedSeats",
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                      const Text("seats", style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildSeatButton(
                            icon: Icons.remove,
                            onPressed: _selectedSeats > 1
                                ? () => setState(() {
                                      _selectedSeats--;
                                      _selectedTable = null;
                                      _selectedTimeSlot = null;
                                    })
                                : null,
                          ),
                          const SizedBox(width: 24),
                          _buildSeatButton(
                            icon: Icons.add,
                            onPressed: _selectedSeats < 6
                                ? () => setState(() {
                                      _selectedSeats++;
                                      _selectedTable = null;
                                      _selectedTimeSlot = null;
                                    })
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Maximum 6 seats per booking",
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Step 2: Select Date
                _buildSectionTitle("2. Reservation Date", Icons.calendar_today),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Colors.deepOrange,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      setState(() {
                        _selectedDate = date;
                        _selectedTimeSlot = null;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _selectedDate != null
                            ? Colors.deepOrange
                            : Colors.grey.shade300,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          color: _selectedDate != null
                              ? Colors.deepOrange
                              : Colors.grey,
                          size: 28,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          _selectedDate != null
                              ? "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}"
                              : "Tap to select date",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: _selectedDate != null
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _selectedDate != null
                                ? Colors.black
                                : Colors.grey,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_forward_ios,
                            size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Step 3: Select Table
                if (_selectedDate != null) ...[
                  _buildSectionTitle("3. Select Table", Icons.table_restaurant),
                  const SizedBox(height: 16),
                  if (availableTables.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "No tables available for $_selectedSeats seats. Try selecting fewer seats.",
                              style: const TextStyle(color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...availableTables.map((table) {
                      final isSelected = _selectedTable?['tableId'] == table['tableId'];
                      final availableSlots = _getAvailableTimeSlots(table, dateStr!);
                      final isFullyBooked = availableSlots.isEmpty;

                      return GestureDetector(
                        onTap: isFullyBooked
                            ? null
                            : () => setState(() {
                                  _selectedTable = table;
                                  _selectedTimeSlot = null;
                                }),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isFullyBooked
                                ? Colors.grey[200]
                                : isSelected
                                    ? Colors.deepOrange.withOpacity(0.1)
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.deepOrange
                                  : Colors.grey.shade200,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isFullyBooked
                                      ? Colors.grey
                                      : isSelected
                                          ? Colors.deepOrange
                                          : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.table_restaurant,
                                  color: isFullyBooked || isSelected
                                      ? Colors.white
                                      : Colors.black54,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Table ${table['tableId']}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isFullyBooked
                                            ? Colors.grey
                                            : Colors.black,
                                      ),
                                    ),
                                    Text(
                                      "${table['seats']} seats capacity",
                                      style: TextStyle(
                                        color: isFullyBooked
                                            ? Colors.grey
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isFullyBooked)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    "Fully Booked",
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  "${availableSlots.length} slots",
                                  style: TextStyle(
                                    color: Colors.green[600],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 32),
                ],

                // Step 4: Select Time Slot
                if (_selectedTable != null && dateStr != null) ...[
                  _buildSectionTitle("4. Select Time Slot", Icons.access_time),
                  const SizedBox(height: 16),
                  Builder(builder: (context) {
                    final availableSlots = _getAvailableTimeSlots(_selectedTable!, dateStr);
                    
                    if (availableSlots.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "All time slots are booked for this table. Please select another table.",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: widget.timeSlots.map((slot) {
                        final slotStr = slot.toString();
                        final isAvailable = availableSlots.contains(slotStr);
                        final isSelected = _selectedTimeSlot == slotStr;

                        return GestureDetector(
                          onTap: isAvailable
                              ? () => setState(() => _selectedTimeSlot = slotStr)
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            decoration: BoxDecoration(
                              color: !isAvailable
                                  ? Colors.grey[300]
                                  : isSelected
                                      ? Colors.deepOrange
                                      : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.deepOrange
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              slotStr,
                              style: TextStyle(
                                color: !isAvailable
                                    ? Colors.grey[500]
                                    : isSelected
                                        ? Colors.white
                                        : Colors.black,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                decoration: !isAvailable
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }),
                  const SizedBox(height: 8),
                  Text(
                    "Crossed-out times are already booked",
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(height: 32),
                ],

                // Booking Summary & Confirm Button
                if (_selectedDate != null &&
                    _selectedTable != null &&
                    _selectedTimeSlot != null) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Booking Summary",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSummaryRow("Restaurant", widget.restaurantName),
                        _buildSummaryRow("Date", "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}"),
                        _buildSummaryRow("Time", _selectedTimeSlot!),
                        _buildSummaryRow("Table", "Table ${_selectedTable!['tableId']}"),
                        _buildSummaryRow("Seats", "$_selectedSeats"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Confirm Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_selectedDate != null &&
                            _selectedTable != null &&
                            _selectedTimeSlot != null &&
                            !_isLoading)
                        ? _confirmBooking
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      disabledBackgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Confirm Booking",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.deepOrange, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSeatButton({required IconData icon, VoidCallback? onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: onPressed != null ? Colors.deepOrange : Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        iconSize: 28,
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

