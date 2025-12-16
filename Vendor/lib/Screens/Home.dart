import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import './restaurant/restaurant_page.dart';
import './restaurant/edit_restaurant_page.dart';
import './restaurant/restaurant_details_page.dart';
import './category/category_page.dart';
import './bookings/bookings_page.dart';
import './notifications/notifications_page.dart';
import '../services/s3_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  int _currentIndex = 0;

  // ---------------- Navigations ---------------- //

  void goToAddRestaurant() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddRestaurantPage()),
    ).then((_) {
      setState(() {});
    });
  }

  void goToEditRestaurant(DocumentSnapshot restaurant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditRestaurantPage(
          id: restaurant.id,
          data: restaurant.data() as Map<String, dynamic>,
        ),
      ),
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

  void goToCategories() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CategoryPage()),
    );
  }

  void goToBookings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BookingsPage()),
    );
  }

  void goToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  }

  // ---------------- Delete ---------------- //

  Future<void> deleteRestaurant(String docId, String imageUrl) async {
    try {
      // 1. Extract file name from URL
      final fileName = imageUrl.split('/').last;

      // 2. Delete from S3
      final s3 = S3Service();
      await s3.deleteImage(fileName);

      // 3. Delete Firestore document
      await FirebaseFirestore.instance.collection("restaurants").doc(docId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Restaurant deleted")),
      );
    } catch (e) {
      print("Error deleting restaurant: $e");
    }
  }

  // ---------------- UI ---------------- //

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vendor Dashboard"),
        actions: [
          // Notification bell with badge
          StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection("vendor_notifications")
                .where('isRead', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: goToNotifications,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant),
            label: 'Restaurants',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: 'Categories',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.table_restaurant),
            label: 'Bookings',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: goToAddRestaurant,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildRestaurantsList();
      case 1:
        return const CategoryPage();
      case 2:
        return const BookingsPage();
      default:
        return _buildRestaurantsList();
    }
  }

  Widget _buildRestaurantsList() {
    return StreamBuilder<QuerySnapshot>(
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
                const Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  "No restaurants added yet",
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: goToAddRestaurant,
                  icon: const Icon(Icons.add),
                  label: const Text("Add Restaurant"),
                ),
              ],
            ),
          );
        }

        final restaurants = snapshot.data!.docs;

        return ListView.builder(
          itemCount: restaurants.length,
          padding: const EdgeInsets.all(8),
          itemBuilder: (context, index) {
            final restaurant = restaurants[index];
            final data = restaurant.data() as Map<String, dynamic>;
            final categories = data['categories'] as List<dynamic>? ?? [];

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                leading: data['photoUrl'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          data['photoUrl'],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[300],
                            child: const Icon(Icons.restaurant),
                          ),
                        ),
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.restaurant),
                      ),
                title: Text(
                  data['name'] ?? "No Name",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (categories.isNotEmpty)
                      Text(
                        categories.join(', '),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    Text(
                      "${(data['tables'] as List?)?.length ?? 0} tables",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      goToEditRestaurant(restaurant);
                    } else if (value == 'delete') {
                      deleteRestaurant(restaurant.id, data['photoUrl'] ?? '');
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 10),
                          Text("Edit")
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 10),
                          Text("Delete")
                        ],
                      ),
                    ),
                  ],
                ),
                onTap: () => goToRestaurantDetails(restaurant),
              ),
            );
          },
        );
      },
    );
  }
}
