import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nlrc_rfid_scanner/screens/admin_page.dart';

class CustomDrawer extends StatefulWidget {
  @override
  _CustomDrawerState createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> usersLoggedInToday = [];

  @override
  void initState() {
    super.initState();
    _fetchUsersLoggedInToday();
  }

  // Fetch the users who logged in today
  void _fetchUsersLoggedInToday() async {
    final today = DateTime.now();
    final monthYear = DateFormat('MMM_yyyy').format(today);
    final day = DateFormat('dd').format(today);

    try {
      final attendanceCollection = await firestore
          .collection('attendances')
          .doc(monthYear)
          .collection(day)
          .get();

      final users = attendanceCollection.docs;
      final List<Map<String, dynamic>> loggedInUsers = [];

      for (var doc in users) {
        final userId = doc.id;
        final data = doc.data();
        final timeIn = data['timeIn'] ?? '-';
        final timeOut = data['timeOut'] ?? '-';

        // Add each user to the list
        loggedInUsers.add({
          'name': data['name'] ?? 'Unknown',
          'timeIn':
              timeIn is Timestamp ? _formatTimestamp(timeIn.toDate()) : timeIn,
          'timeOut': timeOut is Timestamp
              ? _formatTimestamp(timeOut.toDate())
              : timeOut,
        });
      }

      setState(() {
        usersLoggedInToday = loggedInUsers;
      });
    } catch (e) {
      debugPrint('Error fetching users: $e');
    }
  }

  // Helper function to format the timestamp to a readable string
  String _formatTimestamp(DateTime timestamp) {
    final DateFormat formatter = DateFormat('hh:mm a');
    return formatter.format(timestamp);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width / 3,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              height: MediaQuery.sizeOf(context).height / 1.5,
              width: double.maxFinite,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 10),
                  Text(
                    "Logged in Today",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 10),
                  // Display the users who logged in today
                  Expanded(
                    child: ListView.builder(
                      itemCount: usersLoggedInToday.length,
                      itemBuilder: (context, index) {
                        final user = usersLoggedInToday[index];
                        return ListTile(
                          title: Text(
                            user['name'],
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Time In: ${user['timeIn']} | Time Out: ${user['timeOut']}',
                            style: TextStyle(
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            //leading: Icon(Icons.admin_panel_settings),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  color: Color.fromARGB(255, 60, 45, 194),
                ),
                SizedBox(
                  width: 10,
                ),
                Text(
                  'Admin Login',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 60, 45, 194),
                  ),
                ),
              ],
            ),
            onTap: () {
              // Navigate to admin login page
              Navigator.pop(context); // Close the drawer
              _navigateToAdminLogin(context);
            },
          ),
        ],
      ),
    );
  }

  // Navigation function for the Admin Login page (implement as needed)
  void _navigateToAdminLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AdminPage(), // Replace with your actual admin login page
      ),
    ).then((value) => setState(() {}));
  }
}
