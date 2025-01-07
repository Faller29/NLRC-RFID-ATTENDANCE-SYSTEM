import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:intl/intl.dart';
import 'package:nlrc_rfid_scanner/backend/data/fetch_attendance.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  String nlrc = "National Labor Relations Commission";
  String selectedTimeRange = "Today"; // Default value
  String selectedSorting = "Alphabetical"; // Default sorting option

  @override
  void initState() {
    super.initState();
    /* WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDatas();
    }); */
  }

  String getFormattedDate() {
    final now = DateTime.now();
    final formattedDate =
        DateFormat('EEEE, MMMM d, yyyy').format(now).toUpperCase();
    return formattedDate;
  }

  Future<void> _fetchDatas() async {
    setState(() {
      isLoading = true;
    });
    await fetchUsers();
    await fetchLoggedUsers();
    await fetchAttendanceData();
    setState(() {
      isLoading = false;
    });
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
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 221, 221, 221),
      body: Column(
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
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 20),
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
                            icon: const Icon(IconlyBold.arrow_left_2),
                          ),
                          Text(
                            selectedTimeRange,
                            style: const TextStyle(fontWeight: FontWeight.bold),
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
                            icon: const Icon(IconlyBold.arrow_right_2),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      isLoading
                          ? const Column(
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
                                          getTooltipItem: (group, groupIndex,
                                              rod, rodIndex) {
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
                                        leftTitles: const AxisTitles(
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
                                        topTitles: const AxisTitles(
                                            drawBelowEverything: false),
                                        rightTitles: const AxisTitles(
                                            drawBelowEverything: false),
                                      ),
                                      borderData: FlBorderData(show: true),
                                      gridData: const FlGridData(show: true),
                                      barGroups: _getSortedBarData(
                                          selectedTimeRange == "Today"
                                              ? _getTodayBarData()
                                              : selectedTimeRange == "This Week"
                                                  ? _getWeeklyBarData()
                                                  : selectedTimeRange ==
                                                          "This Month"
                                                      ? _getMonthlyBarData()
                                                      : selectedTimeRange ==
                                                              "This Year"
                                                          ? _getYearlyBarData()
                                                          : _getYearlyBarData()),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                      const SizedBox(
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
                        const Text(
                          'Sort: ',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black54),
                        ),
                        DropdownButton<String>(
                          value: selectedSorting,
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedSorting = newValue!;
                            });
                          },
                          focusColor: Colors.transparent,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                          icon: const Icon(
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
          !isLoading
              ? Flexible(
                  fit: FlexFit.tight,
                  flex: 1,
                  child: SizedBox(
                    width: MediaQuery.sizeOf(context).width,
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 50, vertical: 10),
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
                              // Get the top 5 workers based on the selected time range
                              Builder(
                                builder: (context) {
                                  final top5Workers = _getTop5Workers(
                                    selectedTimeRange == "Today"
                                        ? workHours
                                        : selectedTimeRange == "This Week"
                                            ? weeklyWorkHours
                                            : selectedTimeRange == "This Month"
                                                ? monthlyWorkHours
                                                : yearlyWorkHours,
                                  );

                                  if (top5Workers.isEmpty) {
                                    // Display "No data to show" when the list is empty
                                    return const Center(
                                      child: Text(
                                        "No data to show",
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 18,
                                        ),
                                      ),
                                    );
                                  }

                                  // Display the list of top 5 workers
                                  return Column(
                                    children: top5Workers.map((worker) {
                                      return ListTile(
                                        leading: const Icon(Icons.star,
                                            color: Colors.amber),
                                        title: Text(worker['name']),
                                        trailing: Text(
                                          "${worker['workHours'].toStringAsFixed(1)} hrs",
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : Container(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _fetchDatas();
        },
        backgroundColor: Colors.greenAccent,
        foregroundColor: Colors.black87,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.refresh,
            ),
            Text(
              'Refresh',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, height: 0.5),
            )
          ],
        ),
      ),
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
      final workedHoursY = yearlyWorkHours[userId] ?? 0;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: double.parse(workedHoursY.toStringAsFixed(1)),
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
