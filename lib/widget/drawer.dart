import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nlrc_rfid_scanner/main.dart';
import 'package:nlrc_rfid_scanner/widget/login.dart';

class CustomDrawer extends StatefulWidget {
  @override
  _CustomDrawerState createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  List<Map<String, dynamic>> usersLoggedInToday = [];

  @override
  void initState() {
    super.initState();
    _fetchUsersLoggedInToday();
  }

  void dispose() {
    super.dispose();
  }

  // Use local data to get users logged in today
  void _fetchUsersLoggedInToday() async {
    try {
      final loggedInUsers = attendance.map((user) {
        final timeIn = user['timeIn'] ?? '-';
        final timeOut = user['timeOut'] ?? '-';

        // Format the timeIn and timeOut (if needed)
        return {
          'name': user['name'] ?? 'Unknown',
          'timeIn': _formatTimestamp(timeIn),
          'timeOut': _formatTimestamp(timeOut),
          'officeType': user['officeType'] ?? 'Unknown',
        };
      }).toList();

      setState(() {
        usersLoggedInToday = loggedInUsers;
      });
    } catch (e) {
      debugPrint('Error processing users: $e');
    }
  }

  // Helper function to format the time (if needed)
  String _formatTimestamp(String timestamp) {
    // If you need to convert time from string to a readable format
    try {
      final parsedTime = DateFormat('HH:mm:ss').parse(timestamp);
      final formattedTime = DateFormat('hh:mm a').format(parsedTime);
      return formattedTime;
    } catch (e) {
      return timestamp;
    }
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
                            '${user['name']} | ${user['officeType']}',
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
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  color: Color.fromARGB(255, 60, 45, 194),
                ),
                SizedBox(width: 10),
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
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return LoginWidget();
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
