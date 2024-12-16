

/* import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const RFIDApp());
}

class RFIDApp extends StatelessWidget {
  const RFIDApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RFID Listener',
      home: const RFIDListenerPage(),
    );
  }
}

class RFIDListenerPage extends StatefulWidget {
  const RFIDListenerPage({Key? key}) : super(key: key);

  @override
  State<RFIDListenerPage> createState() => _RFIDListenerPageState();
}

class _RFIDListenerPageState extends State<RFIDListenerPage> {
  String _rfidData = '';
  final FocusNode _focusNode = FocusNode();
  bool _isRFIDScanning = false;
  DateTime _lastKeypressTime = DateTime.now();

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

  // Handle key press event
  void _onKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      final String data = event.logicalKey.debugName ?? '';
      final DateTime currentTime = DateTime.now();
      final Duration timeDifference = currentTime.difference(_lastKeypressTime);

      if (data.isNotEmpty && _isRFIDInput(data, timeDifference)) {
        setState(() {
          _rfidData += data; // Accumulate scanned data
        });

        if (event.logicalKey == LogicalKeyboardKey.enter) {
          // RFID scan is complete when the Enter key is pressed as it is also in the type of stroke sa RFID
          String filteredData = _filterRFIDData(_rfidData);
          _showRFIDModal(filteredData);
          setState(() {
            _rfidData = '';
          });
        }
      }

      _lastKeypressTime = currentTime;
    }
  }

  bool _isRFIDInput(String data, Duration timeDifference) {
    //making other approach
    return timeDifference.inMilliseconds < 10 && data.length > 3;
  }

  // Use a regular expression para idelete yung non numeric characters o letters
  String _filterRFIDData(String data) {
    final filteredData = data.replaceAll(RegExp(r'[^0-9]'), '');
    return filteredData;
  }

  void _showRFIDModal(String rfidData) {
    print(rfidData);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('RFID Detected'),
        content: Text('Scanned RFID: $rfidData'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Testing backend'),
      ),
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _onKey,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Listening for RFID'),
              const SizedBox(height: 20),
              Text('RFID: $_rfidData'),
            ],
          ),
        ),
      ),
    );
  }
}








void _onKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      final String data = event.logicalKey.debugName ?? '';
      final DateTime currentTime = DateTime.now();
      final Duration timeDifference = currentTime.difference(_lastKeypressTime);

      if (data.isNotEmpty && _isRFIDInput(data, timeDifference)) {
        setState(() {
          _rfidData += data; // Accumulate scanned data
        });

        if (event.logicalKey == LogicalKeyboardKey.enter) {
          // RFID scan is complete when Enter key is pressed
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
        }
      }

      _lastKeypressTime = currentTime;
    }
  }







 */


/* 


import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ManageUserPage extends StatefulWidget {
  @override
  _ManageUserPageState createState() => _ManageUserPageState();
}

class _ManageUserPageState extends State<ManageUserPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Controllers for user fields
  final TextEditingController _rfidController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _officeController = TextEditingController();

  String _rfidData = '';
  String _rfidFirstScan = '';
  String _rfidSecondScan = '';
  bool _isSecondScan = false;
  Timer? _expirationTimer;
  DateTime _lastKeypressTime = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Management',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800],
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: _buildUserList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueGrey[800],
        onPressed: _showAddUserScanModal, // Opens the scan modal to add a user
        child: Icon(Icons.add),
        tooltip: 'Add New User',
      ),
    );
  }

  // Builds the list of users retrieved from Firestore
  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index].data() as Map<String, dynamic>;
            return Card(
              margin: EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blueGrey[800],
                  child: Text(user['name'][0]),
                ),
                title: Text(user['name']),
                subtitle: Text('${user['position']} at ${user['office']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.blue),
                      onPressed: () =>
                          _showEditUserModal(users[index].id, user),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteUser(users[index].id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Displays a modal for adding a new user by scanning the RFID
  void _showAddUserScanModal() {
    _rfidFirstScan = '';
    _rfidSecondScan = '';
    _isSecondScan = false;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Scan the RFID Card to be added',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  _isSecondScan
                      ? 'Scan the RFID again to Verify'
                      : 'Please scan the RFID card.',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        );
      },
    );

    _startRFIDScan();
  }

  // Initiates the RFID scan
  void _startRFIDScan() {
  _rfidData = ''; // Reset any previous scan data

  // Create a focus node and request focus
  FocusNode focusNode = FocusNode();
  FocusScope.of(context).requestFocus(focusNode);

  // Use RawKeyboardListener to listen for key events
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Scan the RFID Card to be added',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              Text(
                _isSecondScan
                    ? 'Scan the RFID again to Verify'
                    : 'Please scan the RFID card.',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    },
  );

  // Using RawKeyboardListener to capture key events
  return RawKeyboardListener(
    focusNode: focusNode,
    onKey: _onKey,
    child: Container(),
  );
}



  // Handles the key events when an RFID scan is performed
  // Handles the key events when an RFID scan is performed
void _onKey(RawKeyEvent event) {
  if (event is RawKeyDownEvent) {
    // Skip modifier keys like Alt, Ctrl, and Shift
    if (event.logicalKey.keyLabel.isEmpty) return;

    final String data = event.logicalKey.debugName ?? '';
    final DateTime currentTime = DateTime.now();
    final Duration timeDifference = currentTime.difference(_lastKeypressTime);
    print(data);

    // Only process valid RFID input based on timing and data length
    if (data.isNotEmpty && _isRFIDInput(data, timeDifference)) {
      setState(() {
        _rfidData += data; // Append scanned data
      });

      // Start a timer to handle expiration of the scan
      _startExpirationTimer();

      if (event.logicalKey == LogicalKeyboardKey.enter) {
        // Process RFID only if data is valid (non-empty, long enough)
        if (_rfidData.isNotEmpty && _rfidData.length >= 9) {
          String filteredData = _filterRFIDData(_rfidData);

          if (!_isSecondScan) {
            setState(() {
              _rfidFirstScan = filteredData;
              _isSecondScan = true;
            });
            Navigator.pop(context); // Close the first scan modal
            _showAddUserScanModal(); // Reopen modal for second scan
          } else {
            setState(() {
              _rfidSecondScan = filteredData;
            });

            // Check if both RFID scans match
            if (_rfidFirstScan == _rfidSecondScan) {
              Navigator.pop(context); // Close verification modal
              _showAddUserForm(); // Open the form to add a new user
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('RFID doesn\'t match. Try again.')),
              );
            }
          }
        }
      }
    }

    _lastKeypressTime = currentTime;
  }
}


  // Checks if the input qualifies as a valid RFID scan
  bool _isRFIDInput(String data, Duration timeDifference) {
    return timeDifference.inMilliseconds < 30 && data.length >= 5;
  }

  // Filters out non-numeric characters from the RFID data
  String _filterRFIDData(String data) {
    return data.replaceAll(RegExp(r'[^0-9]'), '');
  }

  // Starts a timer that expires if no key is pressed within 20ms
  void _startExpirationTimer() {
    if (_expirationTimer != null) {
      _expirationTimer!.cancel(); // Cancel any previous timer
    }

    _expirationTimer = Timer(const Duration(milliseconds: 30), () {
      if (_rfidData.isNotEmpty) {
        setState(() {
          _rfidData = ''; // Clear RFID data if expiration occurs
        });
      }
    });
  }

  // Displays the form to add a user once the second RFID scan matches
  void _showAddUserForm() {
    _rfidController.text = _rfidFirstScan; // Pre-fill RFID field

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add New User',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                _buildTextField('RFID Number', _rfidController, false),
                _buildTextField('Name', _nameController, true),
                _buildTextField('Position', _positionController, true),
                _buildTextField('Office', _officeController, true),
                SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: Icon(Icons.save),
                  label: Text('Save'),
                  onPressed: _saveUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Builds a TextField widget with customizable label and controller
  Widget _buildTextField(
      String label, TextEditingController controller, bool enabled) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  // Saves the new user to Firestore
  void _saveUser() {
    final rfid = _rfidController.text.trim();
    final name = _nameController.text.trim();
    final position = _positionController.text.trim();
    final office = _officeController.text.trim();

    if (rfid.isEmpty || name.isEmpty || position.isEmpty || office.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    _firestore.collection('users').add({
      'rfid': rfid,
      'name': name,
      'position': position,
      'office': office,
    }).then((_) {
      Navigator.pop(context); // Close the modal after saving
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User added successfully.')),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add user.')),
      );
    });
  }

  // Deletes the user from Firestore
  void _deleteUser(String userId) {
    _firestore.collection('users').doc(userId).delete().then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User deleted successfully.')),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete user.')),
      );
    });
  }

  // Displays a modal to edit the user's information
  void _showEditUserModal(String userId, Map<String, dynamic> user) {
    _rfidController.text = user['rfid']; // Pre-fill RFID field
    _nameController.text = user['name']; // Pre-fill Name field
    _positionController.text = user['position']; // Pre-fill Position field
    _officeController.text = user['office']; // Pre-fill Office field

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Edit User',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                _buildTextField('RFID Number', _rfidController, false),
                _buildTextField('Name', _nameController, true),
                _buildTextField('Position', _positionController, true),
                _buildTextField('Office', _officeController, true),
                SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: Icon(Icons.save),
                  label: Text('Save Changes'),
                  onPressed: () => _saveEditedUser(userId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Saves the edited user's information to Firestore
  Future<void> _saveEditedUser(String userId) async {
    final rfid = _rfidController.text.trim();
    final name = _nameController.text.trim();
    final position = _positionController.text.trim();
    final office = _officeController.text.trim();

    if (rfid.isEmpty || name.isEmpty || position.isEmpty || office.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    try {
      // Ensures the update operation happens asynchronously
      await Future.delayed(Duration.zero, () async {
        await _firestore.collection('users').doc(userId).update({
          'rfid': rfid,
          'name': name,
          'position': position,
          'office': office,
        });
      });

      Navigator.pop(context); // Close the modal after saving
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User details updated successfully.')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update user details.')),
      );
    }
  }
}


 */