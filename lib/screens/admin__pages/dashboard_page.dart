import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:iconly/iconly.dart';
import 'package:intl/intl.dart';
import 'package:nlrc_rfid_scanner/assets/themeData.dart';
import 'package:nlrc_rfid_scanner/backend/data/fetch_attendance.dart';
import 'package:nlrc_rfid_scanner/backend/data/file_reader.dart';
import 'package:nlrc_rfid_scanner/main.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

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
  late TransformationController _transformationController;
  bool _isPanEnabled = true;
  bool _isScaleEnabled = true;
  late ZoomPanBehavior _zoomPanBehavior;
  @override
  void initState() {
    _transformationController = TransformationController();
    _zoomPanBehavior = ZoomPanBehavior(
      //enablePinching: true,
      enableSelectionZooming: true,
      zoomMode: ZoomMode.x,
      enablePanning: true,
      //maximumZoomLevel: 10.0,
      enableMouseWheelZooming: true,
      //enableDoubleTapZooming: true,
    );
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
    final result = await InternetAddress.lookup('example.com');

    setState(() {
      isLoading = true;
    });
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      await fetchUsers();
      await fetchLoggedUsers();
      await fetchAttendanceData();
      ScaffoldMessenger.of(context).showSnackBar(
        snackBarSuccess('Data Reloaded', context),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        snackBarFailed(
            'No internet connection to Fetch from Database', context),
      );
    }

    users = await loadUsers();
    attendance = await loadAttendance();
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
                  "${numberOfUsers.length}",
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
                              'lib/assets/images/NLRC-WHITE.png',
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
                          fontSize: 20,
                        ),
                      ),
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
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black54,
                            ),
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
                        height: 10,
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
                          : AspectRatio(
                              aspectRatio: 4,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Center(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Scroll to Zoom in or Out to see more names',
                                            style: TextStyle(
                                              color: Colors.black38,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          SizedBox(
                                            height: 20,
                                          ),
                                          Text(
                                            'Hold Left and Drag Left to Right to see more',
                                            style: TextStyle(
                                              color: Colors.black38,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            'Can\'t drag? try zooming in a bit first!',
                                            style: TextStyle(
                                              color: Colors.black38,
                                              fontWeight: FontWeight.bold,
                                              height: 0.2,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: SfCartesianChart(
                                      primaryXAxis: CategoryAxis(
                                        isVisible: true,
                                        labelRotation: 0,
                                        majorGridLines:
                                            MajorGridLines(width: 0),
                                        //interval: 1,
                                      ),

                                      primaryYAxis: NumericAxis(
                                        isVisible: true,
                                      ),
                                      //title: ChartTitle(text: 'Work Hours by Worker'),
                                      tooltipBehavior: TooltipBehavior(
                                        enable: true,
                                        header: '',
                                        canShowMarker: false,
                                        format: 'point.x : point.y',
                                      ),
                                      series: <CartesianSeries<
                                          BarChartGroupData, String>>[
                                        ColumnSeries<BarChartGroupData, String>(
                                          dataSource: _getSortedBarData(
                                            selectedTimeRange == "Today"
                                                ? _getTodayBarData()
                                                : selectedTimeRange ==
                                                        "This Week"
                                                    ? _getWeeklyBarData()
                                                    : selectedTimeRange ==
                                                            "This Month"
                                                        ? _getMonthlyBarData()
                                                        : selectedTimeRange ==
                                                                "This Year"
                                                            ? _getYearlyBarData()
                                                            : _getYearlyBarData(),
                                          ),
                                          xValueMapper:
                                              (BarChartGroupData data, _) =>
                                                  _getWorkerName(data.x),
                                          yValueMapper: (BarChartGroupData data,
                                                  _) =>
                                              data.barRods.isNotEmpty
                                                  ? data.barRods[0].toY
                                                  : 0, // Get the worked hours from the barRod
                                          name: 'Worked Hours',
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(8)),
                                          color: Colors.blueAccent,
                                          width: 0.8,
                                        ),
                                      ],
                                      zoomPanBehavior: _zoomPanBehavior,
                                    ),
                                  ),
                                ],
                              ),
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
                  fit: FlexFit.loose,
                  flex: 1,
                  child: SizedBox(
                    width: MediaQuery.sizeOf(context).width,
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 50, vertical: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                "Leaderboard $selectedTimeRange",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 10),
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
                                  double thisWidth =
                                      MediaQuery.sizeOf(context).width;
                                  // Display the list of top 5 workers
                                  return Wrap(
                                    spacing: thisWidth == 1920
                                        ? thisWidth * 0.07
                                        : thisWidth * 0.04,
                                    runSpacing: 20.0,
                                    children: top5Workers
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final index = entry.key;
                                      final worker = entry.value;

                                      return SizedBox(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Shimmer(
                                              duration: Duration(seconds: 10),
                                              child: Image.asset(
                                                'lib/assets/images/medal/${index + 1}.png',
                                                fit: BoxFit.cover,
                                                height:
                                                    MediaQuery.sizeOf(context)
                                                            .width *
                                                        0.07,
                                                width:
                                                    MediaQuery.sizeOf(context)
                                                            .width *
                                                        0.07,
                                              ),
                                            ),
                                            const SizedBox(
                                                height:
                                                    5), // Space between the icon and the text
                                            Text(
                                              worker['name'],
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16),
                                              textAlign: TextAlign.center,
                                            ),
                                            Text(
                                              "${worker['workHours'].toStringAsFixed(1)} hrs",
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 16,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
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
      meta: meta,
      //axisSide: meta.axisSide,
      child: Text(
        _getWorkerName(value.toInt()),
        style: style,
        softWrap: true,
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
        child: SizedBox(
          width: 100,
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
      ),
    );
  }
}
