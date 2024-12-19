import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:iconly/iconly.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> users = [];
  Map<String, double> workHours = {};
  Map<String, double> weeklyWorkHours = {}; // For weekly aggregation
  Map<String, double> monthlyWorkHours = {}; // For monthly aggregation
  int loggedUsersCount = 0;
  String nlrc = "National Labor Relations Commission";
  PageController _pageController = PageController();
  String selectedTimeRange = "Today"; // Default value
  bool isLoading = true;
  String selectedSorting = "Alphabetical"; // Default sorting option

  @override
  void initState() {
    super.initState();
    _fetchDatas();
  }

  @override
  void dispose() {
    super.dispose();
  }

  String getFormattedDate() {
    final now = DateTime.now();
    final formattedDate =
        DateFormat('EEEE, MMMM d, yyyy').format(now).toUpperCase();
    return formattedDate;
  }

  Future<void> _fetchDatas() async {
    await fetchUsers();
    await fetchLoggedUsers();
    await fetchYearlyAttendanceData();
  }

  // Fetch user data from Firebase
  Future<void> fetchUsers() async {
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
      fetchAttendanceData();
    } catch (e) {
      debugPrint('Error fetching users: $e');
    }
  }

  // Fetch logged users count for today
  Future<void> fetchLoggedUsers() async {
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
  Future<void> fetchAttendanceData() async {
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
            final workedDuration = timeOut.difference(timeIn);
            final workedHours = workedDuration.inHours +
                (workedDuration.inMinutes.remainder(60) / 60);
            setState(() {
              workHours[userId] = workedHours;
            });
          }
        }
      }
      _fetchWeeklyAttendanceData();
      _fetchMonthlyAttendanceData();
    } catch (e) {
      debugPrint('Error fetching attendance data: $e');
    }
  }

  // Fetch attendance data for the week
  Future<void> _fetchWeeklyAttendanceData() async {
    try {
      final today = DateTime.now();
      final weekStart = today.subtract(
          Duration(days: today.weekday - 1)); // Start of the week (Monday)

      for (var user in users) {
        final userId = user['rfid'];
        double totalWeeklyHours = 0;

        // Iterate over the last 7 days
        for (int i = 0; i < 7; i++) {
          final day = weekStart.add(Duration(days: i));
          final monthYear = DateFormat('MMM_yyyy').format(day);
          final dayString = DateFormat('dd').format(day);

          final attendanceRef = firestore
              .collection('attendances')
              .doc(monthYear)
              .collection(dayString)
              .doc(userId);

          final attendanceDoc = await attendanceRef.get();
          if (attendanceDoc.exists) {
            final data = attendanceDoc.data();
            final timeIn = (data?['timeIn'] as Timestamp?)?.toDate();
            final timeOut = (data?['timeOut'] as Timestamp?)?.toDate();

            if (timeIn != null && timeOut != null) {
              final workedDuration = timeOut.difference(timeIn);
              final workedHours = workedDuration.inHours +
                  (workedDuration.inMinutes.remainder(60) / 60);
              totalWeeklyHours += workedHours;
            }
          }
        }

        setState(() {
          weeklyWorkHours[userId] = totalWeeklyHours;
        });
      }
    } catch (e) {
      debugPrint('Error fetching weekly attendance data: $e');
    }
  }

  // Fetch attendance data for the month
  Future<void> _fetchMonthlyAttendanceData() async {
    try {
      final today = DateTime.now();
      final startOfMonth =
          DateTime(today.year, today.month, 1); // Start of the month

      for (var user in users) {
        final userId = user['rfid'];
        double totalMonthlyHours = 0;

        // Iterate over the days in the current month
        for (int i = 0; i < DateTime(today.year, today.month + 1, 0).day; i++) {
          final day = startOfMonth.add(Duration(days: i));
          final monthYear = DateFormat('MMM_yyyy').format(day);
          final dayString = DateFormat('dd').format(day);

          final attendanceRef = firestore
              .collection('attendances')
              .doc(monthYear)
              .collection(dayString)
              .doc(userId);

          final attendanceDoc = await attendanceRef.get();
          if (attendanceDoc.exists) {
            final data = attendanceDoc.data();
            final timeIn = (data?['timeIn'] as Timestamp?)?.toDate();
            final timeOut = (data?['timeOut'] as Timestamp?)?.toDate();

            if (timeIn != null && timeOut != null) {
              final workedDuration = timeOut.difference(timeIn);
              final workedHours = workedDuration.inHours +
                  (workedDuration.inMinutes.remainder(60) / 60);
              totalMonthlyHours += workedHours;
            }
          }
        }

        setState(() {
          monthlyWorkHours[userId] = totalMonthlyHours;
        });
      }
    } catch (e) {
      debugPrint('Error fetching monthly attendance data: $e');
    }
  }

  // Fetch attendance data for the year
  Future<void> fetchYearlyAttendanceData() async {
    try {
      final today = DateTime.now(); // Current date

      for (var user in users) {
        final userId = user['rfid'];
        double totalYearlyHours = 0;

        // Iterate over each month of the current year
        for (int month = 1; month <= 12; month++) {
          final monthDate = DateTime(today.year, month, 1);
          final monthYear = DateFormat('MMM_yyyy').format(monthDate);

          final attendanceRef = firestore
              .collection('attendances')
              .doc(monthYear)
              .collection(
                  DateFormat('dd').format(today)) // All days of the month
              .doc(userId);

          final attendanceDoc = await attendanceRef.get();
          if (attendanceDoc.exists) {
            final data = attendanceDoc.data();
            final timeIn = (data?['timeIn'] as Timestamp?)?.toDate();
            final timeOut = (data?['timeOut'] as Timestamp?)?.toDate();

            if (timeIn != null && timeOut != null) {
              final workedDuration = timeOut.difference(timeIn);
              final workedHours = workedDuration.inHours +
                  (workedDuration.inMinutes.remainder(60) / 60);
              totalYearlyHours += workedHours;
            }
          }
        }

        setState(() {
          workHours[userId] = totalYearlyHours;
        });
      }
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching yearly attendance data: $e');
    }
  }

  List<BarChartGroupData> _getSortedBarData(List<BarChartGroupData> barData) {
    switch (selectedSorting) {
      case "Highest":
        barData.sort((a, b) => b.barRods[0].toY.compareTo(a.barRods[0].toY));
        break;
      case "Lowest":
        barData.sort((a, b) => a.barRods[0].toY.compareTo(b.barRods[0].toY));
        break;
      case "Alphabetical":
      default:
        barData.sort((a, b) => a.x.toString().compareTo(b.x.toString()));
        break;
    }
    return barData;
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
              const SizedBox(
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
                  color: const Color.fromARGB(255, 60, 45, 194),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                    child: SizedBox(
                      height: 100,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                " ${getFormattedDate()}",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.start,
                              ),
                              const Text(
                                "Dashboard",
                                style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 0.8,
                                ),
                                textAlign: TextAlign.start,
                              ),
                              Text(
                                " ${nlrc.toUpperCase()}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Image.asset(
                            'lib/assets/images/NLRC.png',
                            fit: BoxFit.scaleDown,
                            width: 150,
                            height: 150,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(
                width: 40,
              )
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 50),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      "Workers Hour Metrics",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              if (selectedTimeRange == "Today") {
                                selectedTimeRange = "This Year";
                              } else if (selectedTimeRange == "This Week") {
                                selectedTimeRange = "Today";
                              } else if (selectedTimeRange == "This Month") {
                                selectedTimeRange = "This Week";
                              } else if (selectedTimeRange == "This Year") {
                                selectedTimeRange = "This Month";
                              } else {
                                selectedTimeRange = "Today";
                              }
                            });
                          },
                          icon: Icon(IconlyBold.arrow_left_2),
                        ),
                        Text(
                          selectedTimeRange,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              if (selectedTimeRange == "Today") {
                                selectedTimeRange = "This Week";
                              } else if (selectedTimeRange == "This Week") {
                                selectedTimeRange = "This Month";
                              } else if (selectedTimeRange == "This Month") {
                                selectedTimeRange = "This Year";
                              } else if (selectedTimeRange == "This Year") {
                                selectedTimeRange = "Today";
                              } else {
                                selectedTimeRange = "Today";
                              }
                            });
                          },
                          icon: Icon(IconlyBold.arrow_right_2),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 20,
                    ),
                    isLoading
                        ? Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(
                                height: 20,
                              ),
                              Text(
                                'Fetching Data from Database. Please wait',
                                style: TextStyle(
                                  color: Color(0xff68737d),
                                ),
                              )
                            ],
                          )
                        : Column(
                            children: [
                              AspectRatio(
                                aspectRatio: 4,
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    barTouchData: BarTouchData(
                                      touchTooltipData: BarTouchTooltipData(
                                        getTooltipItem:
                                            (group, groupIndex, rod, rodIndex) {
                                          return BarTooltipItem(
                                            '${_getWorkerName(group.x)}\n',
                                            const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            children: [
                                              TextSpan(
                                                text:
                                                    '${rod.toY.toString()} worked hours',
                                                style: const TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 50,
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: _getBottomTitles,
                                          reservedSize: 50,
                                        ),
                                      ),
                                      topTitles: AxisTitles(
                                          drawBelowEverything: false),
                                      rightTitles: AxisTitles(
                                          drawBelowEverything: false),
                                    ),
                                    borderData: FlBorderData(show: true),
                                    gridData: FlGridData(show: true),
                                    barGroups: _getSortedBarData(
                                        selectedTimeRange == "Today"
                                            ? _getTodayBarData()
                                            : selectedTimeRange == "This Week"
                                                ? _getWeeklyBarData()
                                                : selectedTimeRange ==
                                                        "This Month"
                                                    ? _getMonthlyBarData()
                                                    : _getYearlyBarData()),
                                  ),
                                ),
                              ),
                            ],
                          ),
                    SizedBox(
                      height: 30,
                    ),
                  ],
                ),
                // Sorting dropdown
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Row(
                    children: [
                      Text(
                        'Sort: ',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black54),
                      ),
                      DropdownButton<String>(
                        value: selectedSorting,
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedSorting = newValue!;
                          });
                        },
                        focusColor: Colors.transparent,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: Colors.blueAccent,
                        ),
                        underline: Container(), // Removes the underline
                        items: <String>['Alphabetical', 'Highest', 'Lowest']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12.0, horizontal: 16.0),
                              child: Text(value),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Flexible(
          flex: 1,
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 10),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Leaderboard",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Display the top 5 workers based on selected time range
                    ..._getTop5Workers(
                      selectedTimeRange == "Today"
                          ? workHours
                          : selectedTimeRange == "This Week"
                              ? weeklyWorkHours
                              : selectedTimeRange == "This Month"
                                  ? monthlyWorkHours
                                  : workHours,
                    ).map((worker) {
                      return ListTile(
                        leading: Icon(Icons.star, color: Colors.amber),
                        title: Text(worker['name']),
                        trailing: Text("${worker['workHours']} hrs"),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getTop5Workers(Map<String, double> workHoursMap) {
    // Sort the users based on work hours in descending order and get the top 5
    List<Map<String, dynamic>> sortedUsers = users
        .where((user) => workHoursMap.containsKey(user['rfid']))
        .map((user) {
      return {
        'name': user['name'],
        'workHours': workHoursMap[user['rfid']],
      };
    }).toList();

    sortedUsers.sort((a, b) => b['workHours'].compareTo(a['workHours']));

    // Return the top 5 workers
    return sortedUsers.take(5).toList();
  }

  // Labels for each worker (bottom axis)
  Widget _getBottomTitles(double value, TitleMeta meta) {
    const style = TextStyle(
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

  // Generate today bar chart data
  List<BarChartGroupData> _getTodayBarData() {
    return List.generate(users.length, (index) {
      final userId = users[index]['rfid'];
      final workedHours = workHours[userId] ?? 0;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: double.parse(workedHours.toStringAsFixed(1)),
            color: Colors.blueAccent,
            width: 20,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
        ],
      );
    });
  }

  // Generate weekly bar chart data
  List<BarChartGroupData> _getWeeklyBarData() {
    return List.generate(users.length, (index) {
      final userId = users[index]['rfid'];
      final workedHours = weeklyWorkHours[userId] ?? 0;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: double.parse(workedHours.toStringAsFixed(1)),
            color: Colors.redAccent,
            width: 20,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
        ],
      );
    });
  }

  // Generate monthly bar chart data
  List<BarChartGroupData> _getMonthlyBarData() {
    return List.generate(users.length, (index) {
      final userId = users[index]['rfid'];
      final workedHours = monthlyWorkHours[userId] ?? 0;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: double.parse(workedHours.toStringAsFixed(1)),
            color: Colors.orangeAccent,
            width: 20,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
        ],
      );
    });
  }

  // Generate yearly bar chart data
  List<BarChartGroupData> _getYearlyBarData() {
    return List.generate(users.length, (index) {
      final userId = users[index]['rfid'];
      final workedHours = workHours[userId] ?? 0;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: double.parse(workedHours.toStringAsFixed(1)),
            color: Colors.greenAccent,
            width: 20,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
        ],
      );
    });
  }

  // Widget for each statistics card
  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(color: Colors.white),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
