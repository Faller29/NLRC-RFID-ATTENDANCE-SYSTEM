import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nlrc_rfid_scanner/assets/themeData.dart';
import 'package:nlrc_rfid_scanner/backend/data/fetch_attendance.dart';
import 'package:nlrc_rfid_scanner/backend/data/fetch_data.dart';
import 'package:nlrc_rfid_scanner/backend/data/file_reader.dart';
import 'package:nlrc_rfid_scanner/main.dart';

TextEditingController _titleController = TextEditingController();
TextEditingController _announcementController = TextEditingController();
DateTime _startDate = DateTime.now();
DateTime _endDate = DateTime.now();
String? _currentAnnouncement;
void showManageDialog(BuildContext context) {
  // Initialize PageController
  PageController _pageController = PageController();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(
          'Manage Announcements',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 400,
          height: 400,
          child: FutureBuilder(
            future:
                FirebaseFirestore.instance.collection('announcements').get(),
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

              var announcements = snapshot.data!.docs;

              return Column(
                children: [
                  // PageView with a controller for page switching
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      children: [
                        // First page: Announcement List
                        ListView.builder(
                          itemCount: announcements.length,
                          shrinkWrap: true,
                          itemBuilder: (context, index) {
                            var announcement = announcements[index];
                            var title = announcement['title'];
                            var endDate = announcement['endDate'].toDate();
                            var formattedEndDate =
                                DateFormat('MMM dd yyyy').format(endDate);

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                title: Text(
                                  title,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  'Ends on: $formattedEndDate',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.bold),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit,
                                      ),
                                      color: Colors.greenAccent,
                                      onPressed: () {
                                        // When Edit is clicked, navigate to the second page
                                        _pageController.jumpToPage(
                                            1); // Navigate to edit form
                                        _showEditForm(context, announcement,
                                            announcement.id);
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete),
                                      color: Colors.redAccent,
                                      onPressed: () {
                                        _deleteAnnouncement(
                                            context, announcement.id);
                                        Navigator.pop(context);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // Second page: Edit Announcement Form
                        _buildEditForm(context),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

// Function to build the Edit Form
Widget _buildEditForm(BuildContext context) {
  return StatefulBuilder(
    builder: (BuildContext context, setState) {
      return Column(
        children: [
          const SizedBox(height: 5),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Title',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _announcementController,
            decoration: InputDecoration(
              labelText: 'Announcement',
              alignLabelWithHint: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
            ),
            maxLines: 6,
          ),
          Row(
            children: [
              Text('Start Date: '),
              TextButton(
                child: Row(
                  children: [
                    Icon(Icons.calendar_today),
                    Text(DateFormat('MMM dd yyyy').format(_startDate)),
                  ],
                ),
                onPressed: () async {
                  _startDate = await _selectDate(context, _startDate);
                  setState(() {}); // Trigger rebuild when start date is updated
                },
              ),
            ],
          ),
          Row(
            children: [
              Text('End Date: '),
              TextButton(
                child: Row(
                  children: [
                    Icon(Icons.calendar_today),
                    Text(DateFormat('MMM dd yyyy').format(_endDate)),
                  ],
                ),
                onPressed: () async {
                  _endDate = await _selectDate(context, _endDate);
                  setState(() {}); // Trigger rebuild when end date is updated
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flex(
            direction: Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context)
                      .pop(); // Close the dialog without saving
                },
                child: Text('Cancel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Save the updated announcement data to Firestore
                  await _updateAnnouncement(
                    context,
                    _currentAnnouncement!, // Replace with actual ID
                    _titleController.text,
                    _announcementController.text,
                    _startDate,
                    _endDate,
                  );
                  Navigator.of(context).pop(); // Close the dialog
                },
                child: Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

Future<DateTime> _selectDate(BuildContext context, DateTime currentDate) async {
  DateTime? pickedDate = await showDatePicker(
    context: context,
    initialDate: currentDate,
    firstDate: DateTime(2000),
    lastDate: DateTime(2101),
  );
  return pickedDate ?? currentDate;
}

// Method to navigate to the edit form and populate it with the selected announcement
void _showEditForm(BuildContext context, DocumentSnapshot announcement,
    String announcementId) {
  _titleController.text = announcement['title'];
  _announcementController.text = announcement['announcement'];
  _startDate = announcement['startDate'].toDate();
  _endDate = announcement['endDate'].toDate();
  _currentAnnouncement = announcementId;
}

// Function to update the announcement in Firestore
Future<void> _updateAnnouncement(
    BuildContext context,
    String announcementId,
    String title,
    String announcementText,
    DateTime startDate,
    DateTime endDate) async {
  final updatedAnnouncement = {
    'title': title,
    'announcement': announcementText,
    'startDate': startDate,
    'endDate': endDate,
    'updatedAt': DateTime.now(),
  };

  try {
    await FirebaseFirestore.instance
        .collection('announcements')
        .doc(announcementId) // Use the same document ID to update it
        .update(updatedAnnouncement);
    await fetchAnnouncements();
    adminAnnouncement = await loadAnnouncements();

    ScaffoldMessenger.of(context).showSnackBar(
      snackBarSuccess('Announcement updated successfully', context),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      snackBarFailed('Failed to update announcement', context),
    );
  }
}

// Function to delete an announcement by its ID
void _deleteAnnouncement(BuildContext context, String announcementId) async {
  try {
    await FirebaseFirestore.instance
        .collection('announcements')
        .doc(announcementId)
        .delete();
    await fetchAnnouncements();
    adminAnnouncement = await loadAnnouncements();

    ScaffoldMessenger.of(context).showSnackBar(
      snackBarSuccess(
          'content: Text(' 'Announcement deleted successfully', context),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      snackBarFailed('Failed to delete announcement', context),
    );
  }
}
