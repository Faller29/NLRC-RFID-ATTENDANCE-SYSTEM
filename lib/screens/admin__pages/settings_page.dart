import 'dart:convert'; // For hashing
import 'package:crypto/crypto.dart'; // For SHA-256 hashing
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:nlrc_rfid_scanner/assets/themeData.dart';
import 'package:nlrc_rfid_scanner/backend/data/announcement.dart';
import 'package:nlrc_rfid_scanner/backend/data/fetch_data.dart';
import 'package:nlrc_rfid_scanner/backend/data/file_reader.dart';
import 'package:nlrc_rfid_scanner/main.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailController = TextEditingController();

  final _titleController = TextEditingController();
  final _announcementController = TextEditingController();
  String _selectedDomain = '@gmail.com'; // Default domain
  List<String> _emailDomains = [
    '@gmail.com',
    '@yahoo.com',
    '@outlook.com',
    '@hotmail.com'
  ];

  DateTime? _startDate;
  DateTime? _endDate;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String globalPassword = '';

  @override
  void initState() {
    super.initState();
    getData();
  }

  void getData() async {
    try {
      DocumentReference adminDoc =
          _firestore.collection('admin').doc('account');
      DocumentSnapshot snapshot = await adminDoc.get();

      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

        // Initialize controllers with the data from Firestore
        _usernameController.text = data['username'] ?? '';
        _emailController.text = data['email'] ?? '';
        globalPassword = data['password'] ?? '';
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          snackBarFailed('Admin account data not found!', context),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        snackBarFailed('$e', context),
      );
    }
  }

  // Method to hash the password
  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  // Method to update admin account in Firestore
  Future<void> _updateAdminAccount(
      String username, String hashedPassword, String email) async {
    try {
      // Assuming the admin document is stored at `admin/accounts`
      DocumentReference adminDoc =
          _firestore.collection('admin').doc('account');

      await adminDoc.update({
        'username': username,
        'password': hashedPassword,
        'email': email,
      });

      await fetchAdminLogin();
      adminData = await loadAdmin();

      ScaffoldMessenger.of(context).showSnackBar(
        snackBarSuccess('Account updated successfully!', context),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        snackBarFailed('$e', context),
      );
    }
  }

// Function to handle the date picking logic
  Future<void> _pickDate(BuildContext context,
      {required bool isStartDate}) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selectedDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = selectedDate;
        } else {
          _endDate = selectedDate;
        }
      });
    }
  }

  void _clearFields() {
    _titleController.clear();
    _announcementController.clear();
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Row(
            children: [
              Flexible(
                flex: 1,
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height / 1.1,
                  child: Card(
                    margin: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 20.0, horizontal: 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              "Update Account",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(height: 30),
                          Text(
                            'Email',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 10),
                          TextField(
                            controller: _emailController,
                            decoration: InputDecoration(
                                labelText: 'Enter your email',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                suffix: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  child: DropdownButton<String>(
                                    isDense: true,
                                    borderRadius: BorderRadius.circular(20),
                                    focusColor: Colors.transparent,
                                    underline: Container(),
                                    value: _selectedDomain,
                                    icon: Icon(Icons.arrow_drop_down),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        _selectedDomain = newValue!;
                                      });
                                    },
                                    items: _emailDomains
                                        .map<DropdownMenuItem<String>>(
                                            (String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 20)),
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                _emailController.text = value + _selectedDomain;
                              }
                            },
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Username',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 10),
                          TextField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                                labelText: 'Enter new username',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 20)),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Update Password',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 10),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                                labelText: 'Enter new password',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 20)),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          SizedBox(height: 16),
                          TextField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            decoration: InputDecoration(
                                labelText: 'Confirm password',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 20)),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          SizedBox(height: 32),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: ElevatedButton(
                              onPressed: () async {
                                String username = _usernameController.text;
                                String password = _passwordController.text;
                                String confirmPassword =
                                    _confirmPasswordController.text;
                                String email = _emailController.text;

                                // Validation logic
                                if (email.isEmpty ||
                                    !RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$")
                                        .hasMatch(email)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    snackBarFailed(
                                        'Please enter a valid email address',
                                        context),
                                  );
                                  return;
                                }
                                if (username.isEmpty ||
                                    !RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$")
                                        .hasMatch(email)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    snackBarFailed(
                                        'Please enter a valid username',
                                        context),
                                  );
                                  return;
                                }

                                if (password != confirmPassword) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    snackBarSuccess(
                                        'Passwords do not match!', context),
                                  );
                                  return;
                                }

                                // Hash the password
                                String hashedPassword = _hashPassword(password);
                                if (password.isEmpty) {
                                  hashedPassword = globalPassword;
                                }
                                // Update the Firestore document
                                await _updateAdminAccount(
                                    username, hashedPassword, email);
                              },
                              child: Text('Save Changes'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Flexible(
                flex: 1,
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height / 1.1,
                  child: Card(
                    margin: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              "Create Announcement",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(height: 30),
                          TextField(
                            controller: _titleController,
                            keyboardType: TextInputType.text,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              labelText: 'Title',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _announcementController,
                            maxLines: 11,
                            decoration: InputDecoration(
                              labelText: 'Announcement',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text('View date:'),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    _pickDate(context, isStartDate: true),
                                child: Text(
                                  "Start Date: ${_startDate != null ? _startDate!.toLocal().toString().split(' ')[0] : 'Select'}",
                                ),
                              ),
                              Text('To'),
                              TextButton(
                                onPressed: () =>
                                    _pickDate(context, isStartDate: false),
                                child: Text(
                                  "End Date: ${_endDate != null ? _endDate.toString().split(' ')[0] : 'Select'}",
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Flex(
                            direction: Axis.horizontal,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Align(
                                alignment: Alignment.bottomLeft,
                                child: ElevatedButton(
                                  onPressed: () {
                                    showManageDialog(context);
                                  },
                                  child: Text('Manage'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: ElevatedButton(
                                  onPressed: _postAnnouncement,
                                  child: Text('Post Announcement'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.greenAccent,
                                    foregroundColor: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _postAnnouncement() async {
    if (_titleController.text.isEmpty || _announcementController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        snackBarFailed('Please fill all fields', context),
      );
      return;
    }
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        snackBarFailed('Please select a date range', context),
      );
      return;
    }

    if (_startDate!.isAfter(_endDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        snackBarFailed('Start date cannot be after end date', context),
      );
      return;
    }

    // Helper function to convert a string to sentence case
    String toSentenceCase(String input) {
      if (input.isEmpty) return input;
      return input[0].toUpperCase() + input.substring(1).toLowerCase();
    }

    // Format the inputs to sentence case
    String formattedTitle = toSentenceCase(_titleController.text.trim());
    String formattedAnnouncement =
        toSentenceCase(_announcementController.text.trim());

    // Save to Firestore with generated ID
    final announcement = {
      'title': formattedTitle,
      'announcement': formattedAnnouncement,
      'startDate': _startDate,
      'endDate': _endDate,
      'createdAt': DateTime.now(),
    };

    try {
      // Add the announcement with a generated ID
      await FirebaseFirestore.instance
          .collection('announcements')
          .add(announcement); // Add document with generated ID

      ScaffoldMessenger.of(context).showSnackBar(
        snackBarSuccess('Announcement posted successfully!', context),
      );
      _clearFields();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        snackBarFailed('Failed to post announcement', context),
      );
    }
  }
}
