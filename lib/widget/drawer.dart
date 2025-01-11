import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:iconly/iconly.dart';
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
    double screenWidth = MediaQuery.of(context).size.width;

    // Adjust margins based on screen width
    double cardMargin;
    if (screenWidth > 1500 && screenWidth < 1700) {
      cardMargin = 430;
    } else if (screenWidth > 1700) {
      cardMargin = 430;
    } else if (screenWidth < 1500) {
      cardMargin = 430;
    } else {
      cardMargin = 430;
    }

    return Drawer(
      elevation: 20,
      width: cardMargin,
      backgroundColor: Color.fromARGB(255, 226, 225, 228),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Card(
                color: Colors.white,
                elevation: 8,
                shadowColor: Color.fromARGB(255, 44, 15, 148),
                surfaceTintColor: Colors.white,
                child: Container(
                  height: MediaQuery.sizeOf(context).height / 1.2,
                  width: double.maxFinite,
                  decoration: BoxDecoration(
                    color: const Color(0xffffffff),
                    boxShadow: [
                      BoxShadow(
                        blurStyle: BlurStyle.outer,
                        blurRadius: 10.0,
                        color: Color(0xff4b39ef).withOpacity(0.8),
                        offset: Offset(
                          0.0,
                          2.0,
                        ),
                      )
                    ],
                    borderRadius: BorderRadius.circular(15.0),
                    shape: BoxShape.rectangle,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: 10),
                      Text(
                        "Logged in Today",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 26,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 10),
                      if (usersLoggedInToday.isEmpty)
                        const Center(
                          child: Text(
                            "No worker logged in",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                        )
                      else // Display the users who logged in today
                        Expanded(
                          child: ListView.builder(
                            itemCount: usersLoggedInToday.length,
                            itemBuilder: (context, index) {
                              usersLoggedInToday.sort((a, b) => a['name']
                                  .toString()
                                  .compareTo(b['name'].toString()));

                              final user = usersLoggedInToday[index];
                              return Column(
                                children: [
                                  ListTile(
                                    title: Row(
                                      children: [
                                        Icon(
                                          FontAwesomeIcons.user,
                                          size: 15,
                                        ),
                                        SizedBox(
                                          width: 10,
                                        ),
                                        Text(
                                          '${user['name']}',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          ' - ',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          '${user['officeType']}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                user['officeType'] == 'Office'
                                                    ? Colors.green
                                                    : Colors.blueAccent,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Row(
                                      children: [
                                        SizedBox(
                                          width: 25,
                                        ),
                                        Text(
                                          'Time In: ${user['timeIn']}          Time Out: ${user['timeOut'] == '' ? '--' : user['timeOut']}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            height: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 300,
                                    child: Divider(
                                      height: 10,
                                    ),
                                  )
                                ],
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  shadowColor: Color.fromARGB(255, 44, 15, 148),
                  elevation: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    FontAwesomeIcons.unlock,
                    color: Color.fromARGB(255, 60, 45, 194),
                    size: 15,
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  Text(
                    'Sign in',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 60, 45, 194),
                        fontSize: 18),
                  ),
                ],
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  barrierColor: Colors.black38,
                  builder: (BuildContext context) {
                    return Dialog(
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        backgroundColor: Colors.transparent,
                        child: LoginWidget());
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
