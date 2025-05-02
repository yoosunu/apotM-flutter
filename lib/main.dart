// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:apotm/notification.dart';
import 'package:apotm/pages/login.dart';
import 'package:apotm/type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'pages/home.dart';
import 'package:timezone/data/latest.dart' as tdz;
import 'package:timezone/timezone.dart' as tz;
import 'package:http/http.dart' as http;

@pragma('vm:entry-point')
void alarmManagerCallback(int id, Map<String, dynamic> params) async {
  IAlarmData alarmData = IAlarmData.fromJson(params);
  await FlutterLocalNotification.showNotification(
      id, alarmData.title, alarmData.body);
}

@pragma('vm:entry-point')
void startCallback() async {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  bool isRunning = false;
  bool isLoading = true;
  // Called when the task is started.
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('onStart(starter: ${starter.name})');
    isRunning = true;
    isLoading = false;
  }

  // Called based on the eventAction set in ForegroundTaskOptions.
  @override
  void onRepeatEvent(DateTime timestamp) {
    // Send data to main isolate.
    Map<String, dynamic> data = {
      "IsRunning": isRunning,
      "IsLoading": isLoading,
    };
    FlutterForegroundTask.sendDataToMain(data);

    // background posting logic
    // setAlarm(id, time, name);
  }

  // Called when the task is destroyed.
  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('onDestroy');
    isRunning = false;
    isLoading = true;
  }

  // Called when data is sent using `FlutterForegroundTask.sendDataToTask`.
  @override
  void onReceiveData(Object data) {
    print('onReceiveData: $data');
  }

  // Called when the notification button is pressed.
  @override
  void onNotificationButtonPressed(String id) async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
    // print('onNotificationButtonPressed: $id');
  }

  // Called when the notification itself is pressed.
  @override
  void onNotificationPressed() {
    print('onNotificationPressed');
  }

  // Called when the notification itself is dismissed.
  @override
  void onNotificationDismissed() {
    print('onNotificationDismissed');
  }
}

Future<ServiceRequestResult> _startService() async {
  if (await FlutterForegroundTask.isRunningService) {
    return FlutterForegroundTask.restartService();
  } else {
    return FlutterForegroundTask.startService(
      serviceId: 32,
      notificationTitle: 'apotM',
      notificationText: 'apotM is running',
      notificationIcon: NotificationIcon(
        metaDataName: 'com.example.apotm.service.APOT_ICON',
        backgroundColor: Colors.green[300],
      ),
      notificationButtons: [
        const NotificationButton(id: 'btn_stop', text: 'Stop'),
      ],
      notificationInitialRoute: '/',
      callback: startCallback,
    );
  }
}

// @pragma('vm:entry-point')
// void initDoneCallback(int id, Map<String, dynamic> params) async {
//   IInitDoneData initDoneData = IInitDoneData.fromJson(params);

//   const storage = FlutterSecureStorage();
//   String? accessToken = await storage.read(key: "access_token");

//   String url =
//       "https://backend.apot.pro/api/v1/todos/${initDoneData.todoId}/everydays/${initDoneData.everydayId}";

//   try {
//     var response = await http.put(
//       Uri.parse(url),
//       body: json.encode({
//         'name': initDoneData.name,
//         'time': initDoneData.time,
//         'done': false,
//       }),
//       headers: {
//         'Jwt': '$accessToken',
//         'Content-Type': 'application/json',
//       },
//     );

//     if (response.statusCode == 200) {
//       await FlutterLocalNotification.showNotification(
//           200, 'Init', 'All Done Initialized.');
//     }
//     if (response.statusCode == 401) {
//       await storage.delete(key: "access_token");
//       var refreshToken = await storage.read(key: 'refresh_token');
//       const String url = "https://backend.apot.pro/api/v1/users/refresh-at";
//       try {
//         var response = await http.post(
//           Uri.parse(url),
//           body: json.encode({"refresh_token": refreshToken}),
//           headers: {'Content-Type': 'application/json'},
//         );
//         if (response.statusCode == 200) {
//           Map<String, dynamic> newAcData = json.decode(response.body);
//           var newAccessToken = newAcData["access_token"];
//           try {
//             await storage.write(key: "access_token", value: newAccessToken);
//           } catch (e) {
//             print('Error occured on putting done at AT');
//           }
//         }
//       } catch (e) {
//         print("Failed to refresh AT with $e, status: ${response.statusCode}");
//       }
//     }
//   } catch (e) {
//     print('Failed to change done with $e');
//   }
// }

// Future<void> initDone(
//     int todoId, int everydayId, String name, String time) async {
//   tdz.initializeTimeZones();

//   var seoul = tz.getLocation('Asia/Seoul');
//   var now = tz.TZDateTime.now(seoul);
//   var midNight = tz.TZDateTime(seoul, now.year, now.month, now.day, 0, 0);

//   IInitDoneData iInitDoneData = IInitDoneData(
//       todoId: todoId, everydayId: everydayId, name: name, time: time);

//   await AndroidAlarmManager.periodic(
//     const Duration(days: 1),
//     0,
//     initDoneCallback,
//     allowWhileIdle: false,
//     exact: true,
//     wakeup: true,
//     rescheduleOnReboot: false,
//     startAt: midNight,
//     params: iInitDoneData.toJson(),
//   );
// }

Future<void> setAlarm(int id, String time, String name) async {
  var parts = time.split(':');
  var hour = int.parse(parts[0]);
  var minute = int.parse(parts[1]);

  tdz.initializeTimeZones();

  var seoul = tz.getLocation('Asia/Seoul');
  var now = tz.TZDateTime.now(seoul);
  var startDate =
      tz.TZDateTime(seoul, now.year, now.month, now.day, hour, minute);

  IAlarmData alarmData = IAlarmData(
    id: id,
    title: name,
    body: '$name 하실 시간입니다 ♥️',
  );

  await AndroidAlarmManager.oneShotAt(
    startDate,
    id,
    alarmManagerCallback,
    allowWhileIdle: false,
    exact: true,
    wakeup: true,
    rescheduleOnReboot: false,
    params: alarmData.toJson(),
  );
}

Future<List<ITodo>> getTodosMain() async {
  List<ITodo> todos = [];
  List<IEveryday> everydaysGet = [];

  // jwt
  const storage = FlutterSecureStorage();
  String? accessToken = await storage.read(key: "access_token");

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
      todos = jsonData.map((json) => ITodo.fromJson(json)).toList();

      everydaysGet = todos[0].everydays;

      for (var everyday in everydaysGet) {
        if (everyday.done == false) {
          try {
            await setAlarm(everyday.id, everyday.time, everyday.name);
          } catch (e) {
            print('Set Alarm Error: $e');
          }
        }
        if (everyday.done == true) {
          try {
            await AndroidAlarmManager.cancel(everyday.id);
          } catch (e) {
            print('cancel error with $e');
          }
        }
      }
      // await initDone(
      //   todos[0].id, todos[0].everydays[], String name, String time
      // );
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
            return await getTodosMain();
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
  }
  return todos;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterLocalNotification.init();
  FlutterLocalNotification.requestNotificationPermissionAndroid();
  AndroidAlarmManager.initialize();
  getTodosMain();
  _startService();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'apotM',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomePage(
        title: 'APOTM',
      ),
      routes: <String, WidgetBuilder>{
        '/home': (BuildContext context) => const HomePage(title: 'Home'),
        '/login': (BuildContext context) => const LoginPage(title: 'login'),
      },
    );
  }
}
