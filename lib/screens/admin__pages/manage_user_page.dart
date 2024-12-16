import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nlrc_rfid_scanner/assets/themeData.dart';
import 'package:nlrc_rfid_scanner/backend/data/fetch.dart';
//import 'package:nlrc_rfid_scanner/backend/data/users.dart';

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
  String? _userIdToEdit;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

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
      stream: _firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final user = docs[index].data() as Map<String, dynamic>;
            return Card(
              margin: EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.greenAccent,
                  child:
                      Text(user['name'][0]), // Use the first letter of the name
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
    showDialog(
      context: context,
      builder: (context) {
        return _buildUserFormDialog('Add New User', _saveUser);
      },
    );
  }

  // Show Edit User Modal
  void _showEditUserModal(String userId, Map<String, dynamic> user) {
    _userIdToEdit = userId;
    _rfidController.text = user['rfid'];
    _nameController.text = user['name'];
    _positionController.text = user['position'];
    _officeController.text = user['office'];

    showDialog(
      context: context,
      builder: (context) {
        return _buildUserFormDialog('Edit User', _updateUser);
      },
    );
  }

  // User Form Dialog
  Widget _buildUserFormDialog(String title, VoidCallback onSave) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 400),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            _buildTextField('RFID Number', _rfidController),
            _buildTextField('Name', _nameController),
            _buildTextField('Position', _positionController),
            _buildTextField('Office', _officeController),
            SizedBox(height: 20),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.close),
                    label: Text('Close'),
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.save),
                    label: Text('Save'),
                    onPressed: onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Text Field Widget
  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: label == 'RFID Number'
              ? 'Scan the RFID to get RFID Number'
              : null,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  // Save User to Firestore and Update the list
  void _saveUser() {
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

    // Check if user with this RFID already exists
    _firestore.collection('users').doc(rfid).get().then((docSnapshot) {
      if (docSnapshot.exists) {
        // User with this RFID already exists, update it
        _firestore.collection('users').doc(rfid).update({
          'name': name,
          'position': position,
          'office': office,
        }).then((_) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            snackBarSuccess('User updated successfully!', context),
          );
          setState(() {
            // Refresh the list after updating the user
            //fetchUsersFromFirebase(); // Ensure this fetches updated data
          });
        }).catchError((error) {
          ScaffoldMessenger.of(context).showSnackBar(
            snackBarFailed(error, context),
          );
        });
      } else {
        // User with this RFID doesn't exist, add new user
        _firestore.collection('users').doc(rfid).set({
          'rfid': rfid,
          'name': name,
          'position': position,
          'office': office,
        }).then((_) {
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
            snackBarFailed(error, context),
          );
        });
      }
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        snackBarFailed(error, context),
      );
    });

    _clearFormFields();
  }

  // Update User in Firestore and Refresh the list
  void _updateUser() {
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

    _firestore.collection('users').doc(rfid).update({
      'rfid': rfid,
      'name': name,
      'position': position,
      'office': office,
    }).then((_) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        snackBarSuccess('User updated successfully!', context),
      );
      setState(() {
        // Refresh the list after updating a user
        //fetchUsersFromFirebase(); // Ensure this fetches updated data
      });
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        snackBarFailed('$error', context),
      );
    });
  }

// Delete User from Firestore and Refresh the list
  void _deleteUser(String rfid) {
    _firestore.collection('users').doc(rfid).delete().then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        snackBarFailed('User deleted successfully!', context),
      );
      setState(() {
        // Refresh the list after deleting a user
        //fetchUsersFromFirebase(); // Ensure this fetches updated data
      });
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        snackBarFailed(error, context),
      );
    });
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
  }
}
