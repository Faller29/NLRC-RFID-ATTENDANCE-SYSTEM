import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:iconly/iconly.dart';
import 'package:nlrc_rfid_scanner/assets/themeData.dart';
import 'package:nlrc_rfid_scanner/backend/data/fetch_attendance.dart';
import 'package:nlrc_rfid_scanner/backend/data/fetch_data.dart';
import 'package:nlrc_rfid_scanner/backend/data/file_reader.dart';
import 'package:nlrc_rfid_scanner/main.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
//import 'package:nlrc_rfid_scanner/backend/data/users.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ManageUserPage extends StatefulWidget {
  @override
  _ManageUserPageState createState() => _ManageUserPageState();
}

class _ManageUserPageState extends State<ManageUserPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _rfidController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _officeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  String? _userIdToEdit;
  DateTime _lastKeypressTime = DateTime.now();
  String _rfidData = '';
  Timer? _expirationTimer;
  final FocusNode _focusNode = FocusNode();
  File? _selectedImage;
  String? _currentImagePath; // Holds the path to the current image for editing
  bool pickedImage = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _focusNode.dispose();
  }

  void _onKey(KeyEvent event) async {
    if (event is KeyDownEvent) {
      // Skip handling modifier keys (like Alt, Ctrl, Shift) or empty key labels
      if (event.logicalKey.keyLabel.isEmpty) return;

      final String data =
          event.logicalKey.keyLabel; // Use keyLabel instead of debugName

      final DateTime currentTime = DateTime.now();
      final Duration timeDifference = currentTime.difference(_lastKeypressTime);

      setState(() {
        _rfidData += data; // Accumulate only valid key inputs
      });

      // Start a 30ms timer to enforce expiration
      _startExpirationTimer();

      // Check if Enter key is pressed
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        // Ensure RFID data is not empty and greater than 9 characters before processing
        if (_rfidData.isNotEmpty && _rfidData.length >= 9) {
          print(_rfidData.length);
          String filteredData = _filterRFIDData(_rfidData);
          filteredData = '$filteredData';
          print(filteredData.length);
          if (filteredData.length >= 9) {
            bool isRFIDExists = _checkRFIDExists(filteredData);
            Navigator.pop(context);

            if (isRFIDExists) {
              ScaffoldMessenger.of(context).showSnackBar(
                snackBarFailed('RFID Already exists', context),
              );
            } else {
              setState(() {
                _rfidController.text = filteredData;
              });

              showDialog(
                context: context,
                builder: (context) {
                  return _buildUserFormDialog('Add User', _saveUser);
                },
              );
            }

            setState(() {
              _rfidData = ''; // Clear RFID data after processing
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(snackBarFailed(
                'There must be something wrong with the RFID Scanned. Please try again',
                context));
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              snackBarFailed('RFID data is empty. Please try again', context));
        }
      }

      _lastKeypressTime = currentTime; // Update the last keypress time
    }
  }

  String _filterRFIDData(String data) {
    return data.replaceAll(RegExp(r'[^0-9]'), '');
  }

  void _startExpirationTimer() {
    if (_expirationTimer != null) {
      _expirationTimer!.cancel(); // Cancel any existing timer
    }

    _expirationTimer = Timer(const Duration(milliseconds: 100), () {
      if (_rfidData.isNotEmpty) {
        //debugPrint('Expiration timer triggered: Clearing RFID data.');
        setState(() {
          _rfidData = '';
        });
      }
    });
  }

  bool _checkRFIDExists(String rfid) {
    // Look through the users list and check if any entry matches the RFID
    for (var user in users) {
      if (user['rfid'] == rfid) {
        return true; // RFID exists in the list
      }
    }
    return false; // RFID does not exist
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 10),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchText = value.toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Search Employee',
                  hintText: 'Enter a name, position, office or RFID',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _buildUserList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.greenAccent,
        onPressed: _showAddUserModal,
        child: Icon(Icons.add),
        tooltip: 'Add New User',
      ),
    );
  }

  // User List Display
  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        // Sort documents by name
        docs.sort(
          (a, b) => a['name'].toString().compareTo(b['name'].toString()),
        );

        // Filter documents based on search text
        final filteredDocs = docs.where((doc) {
          final user = doc.data() as Map<String, dynamic>;
          final name = user['name'].toString().toLowerCase();
          final position = user['position'].toString().toLowerCase();
          final office = user['office'].toString().toLowerCase();
          final rfid = user['rfid'].toString();

          return name.contains(_searchText) ||
              rfid.contains(_searchText) ||
              position.contains(_searchText) ||
              office.contains(_searchText);
        }).toList();

        return ListView.builder(
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final user = filteredDocs[index].data() as Map<String, dynamic>;
            return Card(
              elevation: 4,
              shadowColor: Color.fromARGB(255, 44, 15, 148),
              margin: EdgeInsets.symmetric(vertical: 8, horizontal: 50),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tileColor: Colors.white,
                dense: false,
                contentPadding: EdgeInsets.all(10),
                leading: CircleAvatar(
                  backgroundColor: Colors.greenAccent,
                  child: Text(user['name'][0]),
                ),
                title: Text(user['name']),
                subtitle: Text('${user['position']} at ${user['office']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.blueAccent),
                      onPressed: () => _showEditUserModal(user['rfid'], user),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _deleteUser(user['rfid']),
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

  // Show Add User Modal
  void _showAddUserModal() {
    _clearFormFields();
    setState(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    });
    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (context) {
          return Card(
            margin: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width * 0.33,
              vertical: MediaQuery.sizeOf(context).height * 0.3,
            ),
            elevation: 10.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Shimmer(
              colorOpacity: 0.8,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Add User',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Please scan your RFID to proceed.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                      child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        FontAwesomeIcons.rss,
                        size: MediaQuery.sizeOf(context).height / 10,
                        color: Colors.blueAccent,
                      ),
                    ),
                  )),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 30),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _clearFormFields();

                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.cancel, color: Colors.white),
                        label: Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.0),
                          ),
                        ),
                      ),
                    ),
                  ),
                  KeyboardListener(
                    focusNode: _focusNode,
                    onKeyEvent: _onKey,
                    child: Container(),
                  ),
                ],
              ),
            ),
          );
        });
  }

  // Show Edit User Modal
  _showEditUserModal(String userId, Map<String, dynamic> user) {
    _userIdToEdit = userId;
    _rfidController.text = user['rfid'];
    _nameController.text = user['name'];
    _positionController.text = user['position'];
    _officeController.text = user['office'];
    _currentImagePath = user['imagePath'];
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _buildUserFormDialog('Edit User', _updateUser);
      },
    );
  }

  // User Form Dialog
  Widget _buildUserFormDialog(String title, Future<void> Function() onSave) {
    return StatefulBuilder(
      builder: (BuildContext context, void Function(void Function()) setState) {
        return Stack(
          children: [
            AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              title: Center(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              content: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /* Text(
                      'Profile Picture:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ), */
                    CircleAvatar(
                      radius: 75,
                      backgroundColor: Colors.black45,
                      child: _selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(100),
                              child: Image.file(
                                _selectedImage!, // Show the selected image
                                width: 150,
                                height: 150,
                                fit: BoxFit.cover,
                                key: ValueKey<File>(_selectedImage!),
                              ),
                            )
                          : _currentImagePath != null &&
                                  File(_currentImagePath!).existsSync()
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(100),
                                  child: Image.file(
                                    File(_currentImagePath!),
                                    width: 150,
                                    height: 150,
                                    fit: BoxFit.fill,
                                  ),
                                )
                              : ClipRRect(
                                  child: Image.asset(
                                    'lib/assets/images/NLRC-WHITE.png', // Default image asset
                                    width: 150,
                                    height: 150,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 44, 15, 148),
                        ),
                        onPressed: () async {
                          final picker = ImagePicker();
                          final pickedFile = await picker.pickImage(
                              source: ImageSource.gallery);

                          if (pickedFile != null) {
                            final directory =
                                await getApplicationDocumentsDirectory();
                            final filePath =
                                '${directory.path}/${pickedFile.name}';
                            final savedImage =
                                await File(pickedFile.path).copy(filePath);

                            setState(() {
                              _selectedImage = savedImage;
                            });
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Upload Image',
                              style: TextStyle(color: Colors.white),
                            )
                          ],
                        )),
                    SizedBox(height: 30),

                    _buildTextField('RFID Number', _rfidController),
                    _buildTextField('Name', _nameController),
                    _buildTextField('Position', _positionController),
                    _buildTextField('Office', _officeController),
                    SizedBox(height: 10),

                    // Action Buttons
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            child: Text(
                              'Close',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () {
                              _clearFormFields();

                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                            ),
                          ),
                          ElevatedButton(
                            child: Text(
                              'Save',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () async {
                              setState(() {
                                isLoading = true;
                              });
                              await onSave();
                              setState(() {
                                isLoading = false;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isLoading)
              Positioned.fill(
                  child: Container(
                color: Color.fromARGB(255, 37, 26, 196).withOpacity(0.3),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Colors.white,
                          ),
                          SizedBox(
                            height: 10,
                          ),
                          Text(
                            'Processing...',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18),
                          ),
                          Text(
                            'Taking too long? check your network connection and hit the Close button',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              height: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 20,
                      top: 20,
                      child: Tooltip(
                        message:
                            'Closes the dialog and let the system process it later when internet reconnects',
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              setState(
                                () {
                                  Navigator.pop(context);
                                  isLoading = false;
                                },
                              );
                            },
                            child: Text('Close')),
                      ),
                    )
                  ],
                ),
              ))
          ],
        );
      },
    );
  }

  // Text Field Widget
  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 20,
      ),
      child: SizedBox(
        width: 400,
        child: TextField(
          controller: controller,
          readOnly: /* label == 'RFID Number'
              ? true
              : */
              false, //this will make the text field read only if it is an rfid
          keyboardType: label == 'RFID Number'
              ? TextInputType.number
              : TextInputType.text,
          inputFormatters: label == 'RFID Number'
              ? [FilteringTextInputFormatter.digitsOnly]
              : [],
          decoration: InputDecoration(
              labelText: label,
              hintText: label == 'RFID Number'
                  ? 'Scan the RFID to get RFID Number'
                  : null,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 38, 15, 119)),
        ),
      ),
    );
  }

// Save User to Firestore and Update the list
  Future<void> _saveUser() async {
    final rfid = _rfidController.text.trim();
    final name = _nameController.text.trim();
    final position = _positionController.text.trim();
    final office = _officeController.text.trim();

    if (rfid.isEmpty || name.isEmpty || position.isEmpty || office.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        snackBarFailed('Please fill in all fields.', context),
      );
      return;
    }

    final imagePath = _selectedImage?.path ?? '';

    // Query the database to check if a user with this RFID already exists
    _firestore
        .collection('users')
        .where('rfid', isEqualTo: rfid)
        .get()
        .then((querySnapshot) {
      if (querySnapshot.docs.isNotEmpty) {
        // User with this RFID already exists, show a snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          snackBarFailed('User with this RFID already exists.', context),
        );
      } else {
        // User with this RFID does not exist, add new user
        _firestore.collection('users').add({
          'rfid': rfid,
          'name': name,
          'position': position,
          'office': office,
          'imagePath': imagePath,
        }).then((docRef) async {
          await fetchUsers();

          await fetchDataAndGenerateDartFile();
          users = await loadUsers();

          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            snackBarSuccess('User added successfully!', context),
          );
          setState(() {
            // Refresh the list after adding a new user
            //fetchUsersFromFirebase(); // Ensure this fetches updated data
          });
        }).catchError((error) {
          ScaffoldMessenger.of(context).showSnackBar(
            snackBarFailed(error.toString(), context),
          );
          print(error);
        });
      }
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        snackBarFailed(error.toString(), context),
      );
    });

    _clearFormFields();
  }

  Future<void> _updateUser() async {
    final rfid = _rfidController.text.trim();
    final name = _nameController.text.trim();
    final position = _positionController.text.trim();
    final office = _officeController.text.trim();

    if (rfid.isEmpty || name.isEmpty || position.isEmpty || office.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        snackBarFailed('Please fill in all fields.', context),
      );
      return;
    }

    // Query the database to find the user by old RFID
    final querySnapshot = await _firestore
        .collection('users')
        .where('rfid', isEqualTo: _userIdToEdit)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final docId =
          querySnapshot.docs.first.id; // Get the document ID of the user
      final userData = querySnapshot.docs.first.data();
      final currentImagePath = userData['imagePath'];
      final imagePath = _selectedImage?.path ?? currentImagePath;

      // Handle image file update
      if (_selectedImage != null &&
          currentImagePath != null &&
          currentImagePath != imagePath) {
        // Delete old image if it exists
        final oldImageFile = File(currentImagePath);
        if (await oldImageFile.exists()) {
          await oldImageFile.delete();
        }
      }

      // Update user information in Firestore
      await _firestore.collection('users').doc(docId).update({
        'rfid': rfid,
        'name': name,
        'position': position,
        'office': office,
        'imagePath': imagePath,
      });

      // Update all attendance records for this user in user_attendance collection
      final userAttendanceSnapshot = await _firestore
          .collection('user_attendance')
          .where('rfid', isEqualTo: _userIdToEdit)
          .get();

      for (var doc in userAttendanceSnapshot.docs) {
        await doc.reference.update({
          'rfid': rfid,
          'name': name,
        });
      }

      // Update total hours in user_total_hours collection
      final userTotalHoursSnapshot = await _firestore
          .collection('user_total_hours')
          .where('rfid', isEqualTo: _userIdToEdit)
          .get();

      for (var doc in userTotalHoursSnapshot.docs) {
        await doc.reference.update({'rfid': rfid});
      }
      await fetchAttendance();
      attendance = await loadAttendance();

      await fetchDataAndGenerateDartFile();
      users = await loadUsers();

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        snackBarSuccess('User updated successfully!', context),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        snackBarFailed('User not found!', context),
      );
    }
    _clearFormFields();
  }

  // Delete User from Firestore and Refresh the list
  void _deleteUser(String rfid) {
    // Show a confirmation dialog before deleting
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Delete User',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete this user? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                _clearFormFields();
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.lightGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                Navigator.pop(context);

                // Query the database to find the user by RFID
                final querySnapshot = await _firestore
                    .collection('users')
                    .where('rfid', isEqualTo: rfid)
                    .get();

                if (querySnapshot.docs.isNotEmpty) {
                  final docId = querySnapshot.docs.first.id;
                  final userData = querySnapshot.docs.first.data();
                  final imagePath = userData['imagePath'];

                  // Delete the image file if it exists
                  if (imagePath != null) {
                    final imageFile = File(imagePath);
                    if (await imageFile.exists()) {
                      await imageFile.delete();
                    }
                  }

                  // Delete the user document
                  await _firestore.collection('users').doc(docId).delete();

                  // Delete attendance records for the user's RFID
                  final attendanceQuerySnapshot = await _firestore
                      .collection('user_attendance')
                      .where('rfid', isEqualTo: rfid)
                      .get();

                  for (final doc in attendanceQuerySnapshot.docs) {
                    await _firestore
                        .collection('user_attendance')
                        .doc(doc.id)
                        .delete();
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    snackBarSuccess(
                        'User and attendance records deleted successfully!',
                        context),
                  );

                  await fetchUsers();
                  await fetchLoggedUsers();

                  await fetchDataAndGenerateDartFile();
                  users = await loadUsers();

                  //fetchUsersFromFirebase(); // Uncomment if needed
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    snackBarFailed('User not found!', context),
                  );
                }
              },
              child: Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Fetch users from Firebase and update the list
  Future<void> fetchUsersFromFirebase() async {
    await fetchDataAndGenerateDartFile(); // Calls your existing function to update the users.dart file
    setState(() {
      // No need to fetch from Firestore again; `users.dart` is updated
    });
  }

  // Clear Form Fields
  void _clearFormFields() {
    _rfidController.clear();
    _nameController.clear();
    _positionController.clear();
    _officeController.clear();
    _userIdToEdit = null;
    _selectedImage = null;
    _currentImagePath = null;
  }
}
