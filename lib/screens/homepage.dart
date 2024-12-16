import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:nlrc_rfid_scanner/assets/themeData.dart';
import 'package:nlrc_rfid_scanner/assets/data/users.dart';
import 'package:nlrc_rfid_scanner/main.dart';
import 'package:nlrc_rfid_scanner/modals/scanned_modal.dart';
import 'package:nlrc_rfid_scanner/screens/admin_page.dart';
import 'package:nlrc_rfid_scanner/widget/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nlrc_rfid_scanner/widget/drawer.dart';

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    }); /* fetchUsers().then((_) {
      setState(() {
        // Notify the UI that users have been fetched
      });
    }); */
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /* Future<void> fetchUsers() async {
    // Simulating fetching users from Firebase Firestore
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    localUsers = snapshot.docs.map((doc) {
      return {
        'rfid': doc['rfid'],
        'name': doc['name'],
        'position': doc['position'],
      };
    }).toList();
  } */
  void _onKey(KeyEvent event) async {
    if (event is KeyDownEvent) {
      // Skip handling modifier keys (like Alt, Ctrl, Shift) or empty key labels
      if (event.logicalKey.keyLabel.isEmpty) return;

      final String data =
          event.logicalKey.keyLabel; // Use keyLabel instead of debugName
      print(data);

      final DateTime currentTime = DateTime.now();
      final Duration timeDifference = currentTime.difference(_lastKeypressTime);

      // Handle key events only if valid RFID input
      //if (_isRFIDInput(data, timeDifference)) {
      setState(() {
        _rfidData += data; // Accumulate only valid key inputs
        //debugPrint('Accumulated RFID Data: $_rfidData');
      });

      // Start a 20ms timer to enforce expiration
      _startExpirationTimer();

      // Check if Enter key is pressed
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        // Ensure RFID data is not empty and greater than 7 characters before processing
        if (_rfidData.isNotEmpty && _rfidData.length >= 9) {
          String filteredData = _filterRFIDData(_rfidData);
          filteredData = '$filteredData'; // Add prefix '0' to the filtered data

          // Check if the scanned RFID exists in the users list
          bool isRFIDExists = _checkRFIDExists(filteredData);

          if (isRFIDExists) {
            if (_isReceiveMode) {
              // Add to notification list and show modal immediately in receive mode
              _addToAwayModeNotifications(filteredData);
              _showRFIDModal(filteredData, currentTime);
            } else {
              // Only add to the notification list in away mode
              _addToAwayModeNotifications(filteredData);
            }
          } else {
            // Handle case where RFID does not exist
            debugPrint('RFID not found in users list.');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('User not found or registered'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }

          setState(() {
            _rfidData = ''; // Clear RFID data after processing
          });
        } else {
          debugPrint('RFID data is empty or insufficient on Enter key event.');
        }
      }
      //}

      _lastKeypressTime = currentTime; // Update the last keypress time
    }
  }

  bool _checkRFIDExists(String rfid) {
    for (var user in localUsers) {
      if (user['rfid'] == rfid) {
        return true; // RFID exists in the local list
      }
    }
    return false; // RFID does not exist
  }

// Check if RFID exists in the local users list
  /* bool _checkRFIDExists(String rfid) {
    // Look through the users list and check if any entry matches the RFID
    for (var user in users) {
      if (user['rfid'] == rfid) {
        return true; // RFID exists in the list
      }
    }
    return false; // RFID does not exist
  } */

  bool _isRFIDInput(String data, Duration timeDifference) {
    // Check if the input is part of an RFID scan
    return timeDifference.inMilliseconds < 30 && data.length >= 1;
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
  // Find the user by RFID and pass their details to the modal
  void _showRFIDModal(String rfidData, DateTime timestamp,
      {VoidCallback? onRemoveNotification}) {
    // Find the user data by RFID
    var matchedUser = _findUserByRFID(rfidData);

    if (matchedUser != null) {
      setState(() {
        _isModalOpen = true; // Track that modal is open
      });

      showDialog(
        context: context,
        barrierDismissible:
            false, // Prevent closing the modal by tapping outside
        builder: (BuildContext context) {
          return ScannedModal(
            rfidData: rfidData,
            timestamp: timestamp,
            userData: matchedUser, // Pass the matched user data
            onRemoveNotification: onRemoveNotification, // Pass callback
          );
        },
      ).then((_) {
        setState(() {
          _isModalOpen = false; // Modal is closed, allow key events again
        });
      });
    }
  }

// Find the user in the list by RFID
  Map<String, dynamic>? _findUserByRFID(String rfid) {
    // Loop through the users list and return the user with the matching RFID
    return users.firstWhere((user) => user['rfid'] == rfid, orElse: () => {});
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
        children: _awayModeNotifications.map((notification) {
          final parts = notification.split('|'); // Split RFID and timestamp
          final rfid = parts[0];
          final timestamp = DateTime.parse(parts[1]); // Parse the timestamp
          final DateFormat timeReceived = DateFormat('hh:mm');
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
            child: Stack(
              children: [
                Container(
                  height: 50,
                  width: 130,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Text(
                      '${timeReceived.format(timestamp)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 22,
                  left: 25,
                  child: Text(
                    rfid,
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                )
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: CustomDrawer(),
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
              color: Color.fromARGB(255, 15, 11, 83).withOpacity(0.5),
              height: MediaQuery.sizeOf(context).height,
              width: MediaQuery.sizeOf(context).width,
            ),
          ),
          Center(
            child: ClockWidget(),
          ),
          _buildAwayModeNotifications(),
          KeyboardListener(
            focusNode: _focusNode,
            onKeyEvent: _onKey,
            child: Container(),
          ),
        ],
      ),
    );
  }

// Navigate to the admin login page
  void _navigateToAdminLogin(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
          builder: (context) =>
              AdminPage()), // Replace with your initial screen
      (Route<dynamic> route) => false, // Removes all the previous routes
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AdminPage(), // Replace with your actual admin login page
      ),
    ).then((value) => setState(() {}));
  }
}
