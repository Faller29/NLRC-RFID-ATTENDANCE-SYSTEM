import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:nlrc_rfid_scanner/backend/data/fetch_data.dart';
import 'package:nlrc_rfid_scanner/screens/admin__pages/dashboard_page.dart';
import 'package:nlrc_rfid_scanner/screens/admin__pages/manage_user_page.dart';
import 'package:nlrc_rfid_scanner/screens/admin__pages/report_page.dart';
import 'package:nlrc_rfid_scanner/screens/admin__pages/settings_page.dart';
import 'package:nlrc_rfid_scanner/screens/homepage.dart';

class AdminPage extends StatefulWidget {
  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  // Current index for navigation
  int _selectedIndex = 0;

  // Example menu items for the side navigation bar
  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.dashboard, 'label': 'Dashboard'},
    {'icon': Icons.analytics, 'label': 'Reports'},
    {'icon': Icons.people, 'label': 'User Management'},
    {'icon': Icons.settings, 'label': 'Settings'},
  ];

  // List of pages to navigate to
  final List<Widget> _pages = [
    DashboardPage(),
    ReportPage(),
    ManageUserPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    //fetchDataAndGenerateDartFile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 221, 221, 221),
      body: Row(
        children: [
          // Side Navigation Bar
          Container(
            width: 300,
            color: Colors.blueGrey[800],
            child: Column(
              children: [
                // Header Section
                Container(
                  color: Colors.blueGrey[900],
                  height: 150,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: Stack(
                    children: [
                      Positioned(
                        child: Image.asset(
                          'lib/assets/images/NLRC.jpg',
                          fit: BoxFit.cover,
                          height: 150,
                          width: 250,
                        ),
                      ),
                      Positioned(
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                            child: Container(
                              color: Color.fromARGB(255, 15, 11, 83)
                                  .withOpacity(0.4),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'Admin Panel',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Navigation Menu Items
                Expanded(
                  child: ListView.builder(
                    itemCount: _menuItems.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        leading: Icon(
                          _menuItems[index]['icon'],
                          color: _selectedIndex == index
                              ? Colors.white
                              : Colors.grey[400],
                        ),
                        title: Text(
                          _menuItems[index]['label'],
                          style: TextStyle(
                            color: _selectedIndex == index
                                ? Colors.white
                                : Colors.grey[400],
                          ),
                        ),
                        selected: _selectedIndex == index,
                        selectedTileColor: Colors.blueGrey[700],
                        onTap: () {
                          setState(() {
                            _selectedIndex = index;
                          });
                        },
                      );
                    },
                  ),
                ),
                // Logout Button
                Container(
                  padding: const EdgeInsets.all(10.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.logout, color: Colors.white),
                    label: Text(
                      'Logout',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main Content Area
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }
}
