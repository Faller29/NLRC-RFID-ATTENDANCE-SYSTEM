import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:nlrc_rfid_scanner/assets/themeData.dart';
import 'package:nlrc_rfid_scanner/modals/scanned_modal.dart';
import 'package:nlrc_rfid_scanner/screens/admin_page.dart';
import 'package:nlrc_rfid_scanner/widget/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  String _rfidData = '';
  final FocusNode _focusNode = FocusNode();
  bool _isRFIDScanning = false;
  DateTime _lastKeypressTime = DateTime.now();
  Timer? _expirationTimer;
  bool _isModalOpen = false;
  bool _isReceiveMode = true; // New variable for "Receive" vs "Away" mode
  List<String> _awayModeNotifications =
      []; // List to store RFID data in Away mode

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Skip handling modifier keys (like Alt, Ctrl, Shift)
      if (event.logicalKey.keyLabel.isEmpty) return;

      final String data = event.logicalKey.debugName ?? '';
      final DateTime currentTime = DateTime.now();
      final Duration timeDifference = currentTime.difference(_lastKeypressTime);

      // Handle key events only if valid RFID input
      if (data.isNotEmpty && _isRFIDInput(data, timeDifference)) {
        setState(() {
          _rfidData += data; // Accumulate scanned data
        });

        // Start a 20ms timer to enforce expiration
        _startExpirationTimer();
        print(event.character);
        if (event.logicalKey == LogicalKeyboardKey.enter) {
          // Ensure RFID data is not empty and greater than 7 characters before processing
          if (_rfidData.isNotEmpty && _rfidData.length >= 9) {
            String filteredData = _filterRFIDData(_rfidData);

            if (_isReceiveMode) {
              // Add to notification list and show modal immediately in receive mode
              _addToAwayModeNotifications(filteredData);
              _showRFIDModal(filteredData, currentTime);
            } else {
              // Only add to the notification list in away mode
              _addToAwayModeNotifications(filteredData);
            }

            setState(() {
              _rfidData = '';
            });
          } else {
            debugPrint('RFID data is empty on Enter key event.');
          }
        }
      }

      _lastKeypressTime = currentTime;
    }
  }

  bool _isRFIDInput(String data, Duration timeDifference) {
    // Check if the input is part of an RFID scan
    return timeDifference.inMilliseconds < 30 && data.length >= 5;
  }

// Filter non-numeric characters from RFID data
  String _filterRFIDData(String data) {
    return data.replaceAll(RegExp(r'[^0-9]'), '');
  }

// Start a timer that clears RFID data if Enter key is not pressed within 20ms
  void _startExpirationTimer() {
    if (_expirationTimer != null) {
      _expirationTimer!.cancel(); // Cancel any existing timer
    }

    _expirationTimer = Timer(const Duration(milliseconds: 30), () {
      if (_rfidData.isNotEmpty) {
        debugPrint('Expiration timer triggered: Clearing RFID data.');
        setState(() {
          _rfidData = '';
        });
      }
    });
  }

  // Display the modal for "Receive" mode
  void _showRFIDModal(String rfidData, DateTime timestamp,
      {VoidCallback? onRemoveNotification}) {
    setState(() {
      _isModalOpen = true; // Track that modal is open
    });

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing the modal by tapping outside
      builder: (BuildContext context) {
        return ScannedModal(
          rfidData: rfidData,
          timestamp: timestamp,
          onRemoveNotification: onRemoveNotification, // Pass callback
        );
      },
    ).then((_) {
      setState(() {
        _isModalOpen = false; // Modal is closed, allow key events again
      });
    });
  }

  // Add RFID data to notifications list in "Away" mode
  void _addToAwayModeNotifications(String rfidData) {
    final DateTime currentTime = DateTime.now(); // Record the timestamp
    setState(() {
      _awayModeNotifications
          .add('$rfidData|$currentTime'); // Combine RFID and timestamp
    });
  }

  // Switch mode between "Receive" and "Away"
  void _toggleMode(bool value) {
    setState(() {
      _isReceiveMode = value;
    });
  }

  // Show notifications for "Away" mode in the top-right corner
  Widget _buildAwayModeNotifications() {
    if (_awayModeNotifications.isEmpty) return SizedBox.shrink();

    return Positioned(
      top: 10,
      right: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _awayModeNotifications.map((notification) {
          final parts = notification.split('|'); // Split RFID and timestamp
          final rfid = parts[0];
          final timestamp = DateTime.parse(parts[1]); // Parse the timestamp

          return InkWell(
            onTap: () {
              final notificationIndex =
                  _awayModeNotifications.indexOf(notification);

              _showRFIDModal(
                rfid,
                timestamp,
                onRemoveNotification: () {
                  setState(() {
                    _awayModeNotifications
                        .removeAt(notificationIndex); // Remove notification
                  });
                },
              );
            },
            child: Container(
              width: 110,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 2)),
                ],
              ),
              child: Text(
                rfid,
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            /* DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blueAccent,
              ),
              child: Stack(
                /* crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end, */
                children: [
                  Text(
                    'Menu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ), */

            Padding(
              padding: const EdgeInsets.all(8.0),
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
                    SizedBox(
                      height: 10,
                    ),
                    Text(
                      "Logged in Today",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: primaryBlack,
                      ),
                    )
                  ],
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 20,
              ),
              leading: Icon(Icons.admin_panel_settings),
              title: Text(
                'Admin Login',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {
                // Navigate to admin login page
                Navigator.pop(context); // Close the drawer
                _navigateToAdminLogin(context);
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        foregroundColor: primaryWhite,
        backgroundColor: Color.fromARGB(255, 60, 45, 194),
        title: Container(
          child: Row(
            children: [
              /* Image.asset(
                'lib/assets/images/NLRC.png',
                fit: BoxFit.cover,
                height: 50,
                width: 50,
              ),
              SizedBox(
                width: 10,
              ), */
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "National Labor Relations Commission",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  /* Text(
                    "Relations Commission",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ) */
                ],
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Text(
                  "Modes: ",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Switch(
                      value: _isReceiveMode,
                      onChanged: _toggleMode,
                      activeTrackColor: Colors.green,
                      activeColor: Colors.white,
                    ),
                  ],
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    _isReceiveMode ? "Receive" : "Away",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: Container(
              height: MediaQuery.sizeOf(context).height,
              width: MediaQuery.sizeOf(context).width,
              child: Image.asset(
                'lib/assets/images/NLRC.jpg',
                fit: BoxFit.cover,
                height: MediaQuery.sizeOf(context).height / 1.2,
                width: MediaQuery.sizeOf(context).width / 1.2,
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
            child: Container(
              color: Colors.blue.withOpacity(0.1),
              height: MediaQuery.sizeOf(context).height,
              width: MediaQuery.sizeOf(context).width,
            ),
          ),
          Center(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: primaryBlack.withOpacity(0.8),
              ),
              padding: EdgeInsets.all(5),
              height: MediaQuery.sizeOf(context).height / 2,
              width: MediaQuery.sizeOf(context).width / 1.5,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: primaryWhite,
                ),
                height: MediaQuery.sizeOf(context).height,
                width: MediaQuery.sizeOf(context).width,
              ),
            ),
          ),
          Center(
            child: clockWidget(),
          ),
          _buildAwayModeNotifications(),
          KeyboardListener(
            focusNode: _focusNode,
            onKeyEvent: _onKey,
            child: Container(),
          ),

          /* Positioned(
            top: 20,
            left: 20,
            child: Container(
              child: Row(
                children: [
                  Image.asset(
                    'lib/assets/images/NLRC.jpg',
                    fit: BoxFit.cover,
                    height: 100,
                    width: 100,
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "National Labor",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                      ),
                      Text(
                        "Relations Commission",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ), */
        ],
      ),
    );
  }

// Navigate to the admin login page
  void _navigateToAdminLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AdminPage(), // Replace with your actual admin login page
      ),
    );
  }
}
