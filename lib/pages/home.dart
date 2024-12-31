// ignore_for_file: use_build_context_synchronously, non_constant_identifier_names
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:apotm/notification.dart';
import 'package:apotm/pages/login.dart';
import 'package:apotm/type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isLoading = true;
  int retryCount = 0;
  int todoIndex = 0;
  int EorP = 0; // 0: E, 1: P

  bool isRunningGet = false; // forBG
  late DateTime timeStampGet; // forBG

  List<ITodo> todos = [];

  Future<void> _onReceiveTaskData(Object data) async {
    if (data is Map<String, dynamic>) {
      final dynamic timestampMillis = data["timestampMillis"];
      final bool isRunning = data["IsRunning"];
      DateTime timestamp =
          DateTime.fromMillisecondsSinceEpoch(timestampMillis, isUtc: true);
      setState(() {
        isRunningGet = isRunning;
        timeStampGet = timestamp;
      });
    }
  }

  Future<void> _requestPermissions() async {
    final NotificationPermission notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (Platform.isAndroid) {
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }

      // Use this utility only if you provide services that require long-term survival,
      // such as exact alarm service, healthcare service, or Bluetooth communication.
      //
      // This utility requires the "android.permission.SCHEDULE_EXACT_ALARM" permission.
      // Using this permission may make app distribution difficult due to Google policy.
      if (!await FlutterForegroundTask.canScheduleExactAlarms) {
        // When you call this function, will be gone to the settings page.
        // So you need to explain to the user why set it.
        await FlutterForegroundTask.openAlarmsAndRemindersSettings();
      }
    }
  }

  void _initService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'apotM foreground_service',
        channelName: 'apotM Foreground Service Notification',
        channelDescription:
            'This notification appears when the apotM foreground service is running.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(
            3600000), // 10분: 600000, 30분: 1800000, 1h: 3600000
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<void> putDone(int indexOfEandP) async {
    // jwt
    const storage = FlutterSecureStorage();
    String? accessToken = await storage.read(key: "access_token");

    if (accessToken == null) {
      String? refreshToken = await storage.read(key: "refresh_token");
      if (refreshToken == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => const LoginPage(title: "Login")),
        );
      }
    }

    // putting
    String url = EorP == 0
        ? "https://backend.apot.pro/api/v1/todos/${todos[todoIndex].id}/everydays/${todos[todoIndex].everydays[indexOfEandP].id}"
        : "https://backend.apot.pro/api/v1/todos/${todos[todoIndex].id}/plans/${todos[todoIndex].plans[indexOfEandP].id}";

    try {
      var response = await http.put(
        Uri.parse(url),
        body: todoIndex == 0
            ? json.encode({
                'name': todos[todoIndex].everydays[indexOfEandP].name,
                'time': todos[todoIndex].everydays[indexOfEandP].time,
                'done': !todos[todoIndex].everydays[indexOfEandP].done,
              })
            : json.encode({
                'name': todos[todoIndex].plans[indexOfEandP].name,
                'time': todos[todoIndex].plans[indexOfEandP].time,
                'description': todos[todoIndex].plans[indexOfEandP].description,
                'done': !todos[todoIndex].plans[indexOfEandP].done,
              }),
        headers: {
          'Jwt': '$accessToken',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        setState(() {
          if (EorP == 0) {
            todos[todoIndex].everydays[indexOfEandP].done =
                !todos[todoIndex].everydays[indexOfEandP].done;
          }
          if (EorP == 1) {
            todos[todoIndex].plans[indexOfEandP].done =
                !todos[todoIndex].plans[indexOfEandP].done;
          }
        });
        await FlutterLocalNotification.cancelNotification(
            todos[todoIndex].everydays[indexOfEandP].id);
      }
      if (response.statusCode == 401) {
        retryCount++;
        await storage.delete(key: "access_token");
        var refreshToken = await storage.read(key: 'refresh_token');
        const String url = "https://backend.apot.pro/api/v1/users/refresh-at";
        try {
          var response = await http.post(
            Uri.parse(url),
            body: json.encode({"refresh_token": refreshToken}),
            headers: {'Content-Type': 'application/json'},
          );
          if (response.statusCode == 200) {
            var newAcData = json.decode(response.body);
            var newAccessToken = newAcData["access_token"];
            try {
              await storage.write(key: "access_token", value: newAccessToken);
              setState(() {
                isLoading = false;
              });
            } catch (e) {
              print('Error occured on putting done at AT');
              setState(() {
                isLoading = false;
              });
              throw Exception('Error occured on putting done at AT');
            }
          }
        } catch (e) {
          print("Failed to refresh AT with $e, status: ${response.statusCode}");
          setState(() {
            isLoading = false;
          });
        }
      } else {
        print('Error occurred with status ${response.statusCode}');
      }
    } catch (e) {
      print('Failed to change done with $e');
    }
  }

  Future<List<ITodo>> getTodos() async {
    if (retryCount > 1) {
      throw Exception("Exceeded maximum retry attempts");
    }

    // jwt
    const storage = FlutterSecureStorage();
    String? accessToken = await storage.read(key: "access_token");
    // print('at: $accessToken');

    if (accessToken == null) {
      String? refreshToken = await storage.read(key: "refresh_token");
      // print('rt: $refreshToken');
      if (refreshToken == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => const LoginPage(title: "Login")),
        );
      }
    }

    //fetching
    const url = "https://backend.apot.pro/api/v1/todos";

    try {
      var response = await http.get(
        Uri.parse(url),
        headers: {
          'Jwt': '$accessToken',
          'Content-Type': 'application/json',
        },
      );
      // print(response.statusCode);
      if (response.statusCode == 200) {
        var utf8Body = utf8.decode(response.bodyBytes);
        List<dynamic> jsonData = json.decode(utf8Body);
        setState(() {
          todos = jsonData.map((json) => ITodo.fromJson(json)).toList();
          isLoading = false;
        });
      }
      if (response.statusCode == 500 || response.statusCode == 401) {
        await storage.delete(key: "access_token");
        var refreshToken = await storage.read(key: "refresh_token");
        const String url = "https://backend.apot.pro/api/v1/users/refresh-at";
        try {
          var response = await http.post(
            Uri.parse(url),
            body: json.encode({"refresh_token": refreshToken}),
            headers: {'Content-Type': 'application/json'},
          );
          if (response.statusCode == 200) {
            var newAcData = json.decode(response.body);
            var newAccessToken = newAcData["access_token"];
            try {
              await storage.write(key: "access_token", value: newAccessToken);
              return await getTodos();
            } catch (e) {
              print('Error occured refreshing AT');
              throw Exception('Error occured refreshing AT');
            }
          }
        } catch (e) {
          print('Error occured during refreshing AT at status 500');
        }
      }
    } catch (e) {
      print('Error fetching data: $e');
      setState(() {
        isLoading = false;
      });
    }
    return todos;
  }

  Future<List<ITodo>> loadAndSetData() async {
    setState(() {
      isLoading = true;
    });
    try {
      List<ITodo> data = await getTodos();
      setState(() {
        todos = data;
      });
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
    return todos;
  }

  void showPopup(BuildContext context, int index) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.green[100],
          key: UniqueKey(),
          title: Text(
            EorP == 0
                ? todos[todoIndex].everydays[index].name
                : todos[todoIndex].plans[index].name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: 300,
            height: 220,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.watch_later_outlined,
                        color: Colors.black,
                        size: 50,
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Text(
                        EorP == 0
                            ? todos[todoIndex].everydays[index].time
                            : todos[todoIndex].plans[index].time,
                        style: const TextStyle(
                          fontSize: 40,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor:
                              WidgetStateProperty.all(Colors.green[400]),
                        ),
                        onPressed: () {},
                        child: const Text(
                          'PUT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor:
                              WidgetStateProperty.all(Colors.red[400]),
                        ),
                        onPressed: () {},
                        child: const Text(
                          'DELETE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    )
                  ],
                )
              ],
            ),
          ),
          // actions: [],
        );
      },
    );
  }

  void todoIndexPopup(BuildContext context, List<int> indices) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          key: UniqueKey(),
          title: const Text(
            'select todo',
            textAlign: TextAlign.justify,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
          content: SizedBox(
            width: 300,
            height: 220,
            child: ListView.builder(
              itemCount: isLoading ? 1 : todos.length,
              itemBuilder: (BuildContext context, int index) {
                return Container(
                  padding: const EdgeInsets.all(10),
                  alignment: Alignment.center,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(100, 55),
                      alignment: Alignment.center,
                    ),
                    onPressed: () {
                      setState(() {
                        todoIndex = index;
                      });
                    },
                    child: Text(
                      todos[index].name,
                      style: const TextStyle(
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // actions: [],
        );
      },
    );
  }

  @override
  void initState() {
    loadAndSetData();
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Request permissions and initialize the service.
      _requestPermissions();
      _initService();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: <Widget>[
          Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 20, 0),
              child: isRunningGet
                  ? IconButton(
                      iconSize: 34,
                      onPressed: () {
                        FlutterLocalNotification.showNotification(
                            1, "test", "test message for debugging");
                      },
                      icon: const Icon(Icons.toggle_on_rounded),
                    )
                  : IconButton(
                      iconSize: 34,
                      onPressed: () {
                        FlutterLocalNotification.showNotification(
                            1, "test", "test message for debugging");
                      },
                      icon: const Icon(Icons.toggle_off_outlined),
                    ))
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : todos.isEmpty
              ? const Center(child: Text('No todos'))
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        child: SizedBox(
                          // top manual
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[100]),
                                  onPressed: () => {
                                        todoIndexPopup(
                                            context,
                                            List.generate(
                                                todos.length, (index) => index))
                                      },
                                  child: const Padding(
                                    padding: EdgeInsets.fromLTRB(0, 0, 0, 0),
                                    child: Icon(Icons.menu),
                                  )),
                              Text(
                                todos[todoIndex].name,
                                style: const TextStyle(fontSize: 20),
                              ),
                              ElevatedButton(
                                // swiping E and P
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green[100]),
                                onPressed: () => setState(() {
                                  EorP == 0 ? EorP = 1 : EorP = 0;
                                }),
                                child: Row(
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.fromLTRB(0, 0, 0, 0),
                                      child: Icon(Icons.change_circle_outlined),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      EorP == 0 ? "E" : "P",
                                      style: const TextStyle(fontSize: 20),
                                    )
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                          alignment: Alignment.center,
                          child: ListView.builder(
                            itemCount: isLoading
                                ? 0
                                : EorP == 0
                                    ? todos[todoIndex].everydays.length
                                    : todos[todoIndex].plans.length,
                            itemBuilder: (BuildContext context, int index) {
                              return Container(
                                padding: const EdgeInsets.all(10),
                                alignment: Alignment.center,
                                child: ElevatedButton(
                                  // E and P buttons
                                  style: ElevatedButton.styleFrom(
                                    padding:
                                        const EdgeInsets.fromLTRB(10, 4, 4, 4),
                                    minimumSize: const Size(100, 55),
                                    alignment: Alignment.center,
                                    backgroundColor: EorP == 0
                                        ? todos[todoIndex]
                                                    .everydays[index]
                                                    .done ==
                                                true
                                            ? Colors.blue[400]
                                            : Colors.red[400]
                                        : todos[todoIndex].plans[index].done ==
                                                true
                                            ? Colors.blue[400]
                                            : Colors.red[400],
                                  ),
                                  onPressed: () {
                                    putDone(index);
                                  },
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      TextButton(
                                        // E&P detail menu button
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                        ),
                                        onPressed: () {
                                          showPopup(context, index);
                                        },
                                        child: const Icon(Icons.menu),
                                      ),
                                      Text(
                                        EorP == 0
                                            ? todos[todoIndex]
                                                .everydays[index]
                                                .name
                                            : todos[todoIndex]
                                                .plans[index]
                                                .name,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox()
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     Navigator.push(
      //       context,
      //       MaterialPageRoute(
      //           builder: (context) => const SavePage(title: "Saved")),
      //     );
      //   },
      //   tooltip: 'Fetch',
      //   child: const Icon(Icons.save_alt),
      // ),
    );
  }
}
