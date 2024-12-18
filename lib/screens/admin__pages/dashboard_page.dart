import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> users = []; // List to store user data
  Map<String, double> workHours = {}; // Map to store work hours for each user
  int loggedUsersCount = 0; // Count of users logged in today

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _fetchLoggedUsers(); // Fetch logged users count for today
  }

  // Fetch user data from Firebase
  Future<void> _fetchUsers() async {
    try {
      final usersRef = firestore.collection('users');
      final snapshot = await usersRef.get();
      final fetchedUsers = snapshot.docs.map((doc) {
        return {
          'rfid': doc['rfid'],
          'name': doc['name'],
          'office': doc['office'],
          'position': doc['position'],
        };
      }).toList();

      setState(() {
        users = fetchedUsers;
      });

      // Fetch attendance data for each user
      _fetchAttendanceData();
    } catch (e) {
      debugPrint('Error fetching users: $e');
    }
  }

  // Fetch logged users count for today
  Future<void> _fetchLoggedUsers() async {
    try {
      final today = DateTime.now();
      final monthYear = DateFormat('MMM_yyyy').format(today);
      final day = DateFormat('dd').format(today);

      final attendanceRef =
          firestore.collection('attendances').doc(monthYear).collection(day);

      final snapshot = await attendanceRef.get();

      // Count how many users have logged in today (those who have a timeIn)
      int count = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final timeIn = (data['timeIn'] as Timestamp?)?.toDate();
        if (timeIn != null) {
          count++;
        }
      }

      setState(() {
        loggedUsersCount = count;
      });
    } catch (e) {
      debugPrint('Error fetching logged users: $e');
    }
  }

  // Fetch attendance data for each user and calculate hours worked
  Future<void> _fetchAttendanceData() async {
    try {
      final today = DateTime.now();
      final monthYear = DateFormat('MMM_yyyy').format(today);
      final day = DateFormat('dd').format(today);

      for (var user in users) {
        final userId = user['rfid'];
        final attendanceRef = firestore
            .collection('attendances')
            .doc(monthYear)
            .collection(day)
            .doc(userId);

        final attendanceDoc = await attendanceRef.get();
        if (attendanceDoc.exists) {
          final data = attendanceDoc.data();
          final timeIn = (data?['timeIn'] as Timestamp?)?.toDate();
          final timeOut = (data?['timeOut'] as Timestamp?)?.toDate();

          if (timeIn != null && timeOut != null) {
            final workedHours = timeOut.difference(timeIn).inHours.toDouble();
            setState(() {
              workHours[userId] = workedHours;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching attendance data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(
                width: 40,
              ),
              _buildStatCard(
                "Logged Users",
                "$loggedUsersCount",
                Icons.people,
                Colors.blue,
              ),
              _buildStatCard(
                "Workers",
                "${users.length}",
                Icons.work,
                Colors.green,
              ),
              Flexible(
                fit: FlexFit.tight,
                flex: 1,
                child: Card(
                  color: Color.fromARGB(255, 60, 45, 194),
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: SizedBox(
                      height: 100,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "National Labor Relations Commission",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 26),
                          ),
                          Text(
                            "Dashboard",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                            textAlign: TextAlign.start,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 40,
              )
            ],
          ),
        ),
        Card(
          margin: EdgeInsets.symmetric(horizontal: 50),
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Performance Metrics",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                AspectRatio(
                  aspectRatio: 4,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${_getWorkerName(group.x)}\n',
                              TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              children: [
                                TextSpan(
                                  text: '${rod.toY.toString()} hours',
                                  style: TextStyle(
                                    color: Colors.yellowAccent,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          axisNameWidget: null,
                          sideTitles:
                              SideTitles(showTitles: true, reservedSize: 50),
                        ),
                        bottomTitles: AxisTitles(
                          axisNameWidget: null,
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: _getBottomTitles,
                          ),
                        ),
                        topTitles: AxisTitles(drawBelowEverything: false),
                        rightTitles: AxisTitles(
                          drawBelowEverything: false,
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: Colors.grey, width: 1),
                      ),
                      barGroups: _getHourlyBarData(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Labels for each worker (bottom axis)
  Widget _getBottomTitles(double value, TitleMeta meta) {
    final style = TextStyle(
      color: Color(0xff68737d),
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(
        _getWorkerName(value.toInt()),
        style: style,
      ),
    );
  }

  // Worker names for the X-axis
  String _getWorkerName(int workerIndex) {
    if (workerIndex < users.length) {
      return users[workerIndex]['name'] ?? 'Unknown';
    } else {
      return 'Unknown';
    }
  }

  // Generate bar chart data based on fetched work hours
  List<BarChartGroupData> _getHourlyBarData() {
    return List.generate(users.length, (index) {
      final userId = users[index]['rfid'];
      final workedHours = workHours[userId] ?? 0;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: workedHours,
            color: Colors.greenAccent,
            width: 20,
          ),
        ],
      );
    });
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color iconColor) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Container(
          width: 150,
          height: 100,
          child: Column(
            children: [
              Icon(
                icon,
                color: iconColor,
                size: 32,
              ),
              SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
