import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:iconly/iconly.dart';
import 'package:intl/intl.dart';
import 'package:nlrc_rfid_scanner/assets/themeData.dart';
//import 'package:nlrc_rfid_scanner/assets/data/users.dart';
import 'package:nlrc_rfid_scanner/main.dart';
import 'package:nlrc_rfid_scanner/modals/scanned_modal.dart';
import 'package:nlrc_rfid_scanner/screens/admin_page.dart';
import 'package:nlrc_rfid_scanner/widget/announcement.dart';
import 'package:nlrc_rfid_scanner/widget/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nlrc_rfid_scanner/widget/drawer.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

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
  bool _isReceiveMode = true; //variable for "Receive" vs "Away" mode
  List<String> _awayModeNotifications =
      []; // List to store RFID data in Away mode
  bool announcementIsOn = false;
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    //first approach but later moved to main for much earlier fetch

    /* fetchUsers().then((_) {
      setState(() {
      });
    }); */
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  //first approach but later moved to main for much earlier fetch
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

      // Handle key events only if valid RFID input but removed as it is causing bugs. find end curly at the end of before the funct
      //if (_isRFIDInput(data, timeDifference)) {
      setState(() {
        _rfidData += data; // Accumulate only valid key inputs
      });

      // Start a 30ms timer to enforce expiration
      _startExpirationTimer();

      // Check if Enter key is pressed
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        // Ensure RFID data is not empty and greater than 9 characters before processing
        if (_rfidData.isNotEmpty && _rfidData.length >= 9) {
          String filteredData = _filterRFIDData(_rfidData);
          String loggedUser;
          filteredData = '$filteredData';
          // Check if the scanned RFID exists in the users list
          bool isRFIDExists = _checkRFIDExists(filteredData);

          if (isRFIDExists) {
            loggedUser = getRFID(filteredData);

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
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.symmetric(horizontal: 200, vertical: 10),
                content: Text(
                  'User not found or registered. Check if RFID is registered and Try again',
                  textAlign: TextAlign.center,
                ),
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

  /* bool _checkRFIDExists(String rfid) {
    print(localUsers);
    for (var user in localUsers) {
      if (user['rfid'] == rfid) {
        return true; // RFID exists in the local list
      }
    }
    return false; // RFID does not exist
  } */

// Check if RFID exists in the local users list
  bool _checkRFIDExists(String rfid) {
    // Look through the users list and check if any entry matches the RFID
    for (var user in users) {
      if (user['rfid'] == rfid) {
        return true; // RFID exists in the list
      }
    }
    return false; // RFID does not exist
  }

  String getRFID(String rfid) {
    String loggedUser;

    // Look through the users list and check if any entry matches the RFID
    for (var user in users) {
      if (user['rfid'] == rfid) {
        loggedUser = user['name'];
        return loggedUser; // RFID exists in the list
      }
    }
    return 'No user'; // RFID does not exist
  }

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

    _expirationTimer = Timer(const Duration(milliseconds: 300), () {
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

      // Find the index of the RFID in the awayModeNotifications
      final notificationIndex = _awayModeNotifications
          .indexWhere((notification) => notification.contains(rfidData));

      showDialog(
        context: context,
        barrierDismissible:
            true, // Prevent closing the modal by tapping outside
        builder: (BuildContext context) {
          return ScannedModal(
            rfidData: rfidData,
            timestamp: timestamp,
            userData: matchedUser, // Pass the matched user data
            onRemoveNotification: () {
              // Pass the index to remove the correct notification
              if (notificationIndex != -1) {
                setState(() {
                  _awayModeNotifications.removeAt(
                      notificationIndex); // Remove notification by index
                });
              }
            },
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
  void _addToAwayModeNotifications(String loggedUser) {
    final DateTime currentTime = DateTime.now(); // Record the timestamp

    // Check if the RFID data already exists in the notifications list
    final exists = _awayModeNotifications
        .any((notification) => notification.contains(loggedUser));

    if (!exists) {
      setState(() {
        _awayModeNotifications.add(
            '$loggedUser|$currentTime'); // Add only if not already in the list
      });
    } else {
      debugPrint('RFID data already exists in the notifications list.');
    }
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
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height - 60, maxWidth: 200),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _awayModeNotifications.map((notification) {
              final parts = notification.split('|'); // Split RFID and timestamp
              final rfid = parts[0];
              final timestamp = DateTime.parse(parts[1]); // Parse the timestamp
              final DateFormat timeReceived = DateFormat('hh:mm a');
              // Find the index of the RFID in the awayModeNotifications
              var user = _findUserByRFID(rfid);
              String name = user!['name'];
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
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(
                        top: 20,
                        bottom: 10,
                      ),
                      height: 60,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
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
                      child: Center(
                        child: Text(
                          '${name.toUpperCase()}',
                          style: TextStyle(
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 2),
                        child: Text(
                          '${timeReceived.format(timestamp)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: CustomDrawer(),
      appBar: AppBar(
        foregroundColor: primaryWhite,
        backgroundColor: Color.fromARGB(255, 44, 15, 148),
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
          if (announcementIsOn)
            Positioned(
                child: SizedBox(
                    width: 400,
                    height: MediaQuery.sizeOf(context).height,
                    child: announcement())),
          _buildAwayModeNotifications(),
          KeyboardListener(
            focusNode: _focusNode,
            onKeyEvent: _onKey,
            child: Container(),
          ),
        ],
      ),
      floatingActionButton: adminAnnouncement.length != 0
          ? Stack(
              children: [
                FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      announcementIsOn = !announcementIsOn;
                    });
                  },
                  tooltip: 'Show/Hide Announcement',
                  child: Icon(FontAwesomeIcons.bell),
                  backgroundColor: Color.fromARGB(255, 44, 15, 148),
                  foregroundColor: Colors.white,
                ),
                if (adminAnnouncement.length >
                    0) // Show the badge only if there are announcements
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(6), // Padding for the badge
                      decoration: BoxDecoration(
                        color: Colors.red, // Badge background color
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${adminAnnouncement.length}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : null,
    );
  }

  Widget announcement() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('announcements')
          .snapshots(), // Stream that listens to changes in the 'announcements' collection
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No announcements available.'));
        }

        // Convert Firestore data into the format used by AnnouncementsWidget
        final List<Map<String, dynamic>> announcements =
            snapshot.data!.docs.map((doc) {
          return {
            'title': doc['title'] ?? 'No Title',
            'announcement': doc['announcement'] ?? 'No Announcement',
            'createdAt': doc['createdAt'] != null
                ? DateFormat('MMM dd yyyy - hh:mm a')
                    .format(doc['startDate'].toDate())
                : 'No Start Date',
          };
        }).toList();

        return AnnouncementsWidget(announcements: announcements);
      },
    );
  }
}
