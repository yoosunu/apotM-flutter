import 'dart:convert';

import 'package:apotm/notification.dart';
import 'package:apotm/pages/login.dart';
import 'package:apotm/type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'pages/home.dart';

@pragma('vm:entry-point')
void startCallback() async {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  bool isRunning = false;
  // Called when the task is started.
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('onStart(starter: ${starter.name})');
    isRunning = true;
  }

  Future<List<ITodo>> getTodosBG() async {
    List<ITodo> todos = [];

    // jwt
    const storage = FlutterSecureStorage();
    String? accessToken = await storage.read(key: "access_token");
    // print('at: $accessToken');

    if (accessToken == null) {
      String? refreshToken = await storage.read(key: "refresh_token");
      // print('rt: $refreshToken');
      if (refreshToken == null) {
        await FlutterLocalNotification.showNotification(
            401, 'Status 401', 'you should login first');
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
      if (response.statusCode == 200) {
        var utf8Body = utf8.decode(response.bodyBytes);
        List<dynamic> jsonData = json.decode(utf8Body);
        todos = jsonData.map((json) => ITodo.fromJson(json)).toList();
      }

      if (response.statusCode == 401 || response.statusCode == 500) {
        await storage.delete(key: "access_token");
        var refreshToken = await storage.read(key: 'refresh_token');
        // print('RtGet: $refreshToken');

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
            if (newAccessToken != null && newAccessToken.isNotEmpty) {
              await storage.write(key: "access_token", value: newAccessToken);
              return await getTodosBG();
            }
          }
        } catch (e) {
          await FlutterLocalNotification.showNotification(
              3, "posting error BG", "Failed to refresh AT with $e");
          print("Failed to refresh AT with $e");
        }
      }
    } catch (e) {
      print('Error fetching data: $e');
      await FlutterLocalNotification.showNotification(
          500, "getTodo Error", '$e');
    }

    for (var todo in todos) {
      for (var everyday in todo.everydays) {
        if (everyday.done == false) {
          await FlutterLocalNotification.scheduleNotification(
              everyday.id, everyday.time, everyday.name);
        }
        if (everyday.done == true) {
          await FlutterLocalNotification.cancelNotification(everyday.id);
        }
      }
    }
    return todos;
  }

  // Called based on the eventAction set in ForegroundTaskOptions.
  @override
  void onRepeatEvent(DateTime timestamp) {
    // Send data to main isolate.
    Map<String, dynamic> data = {
      "timestampMillis": timestamp.millisecondsSinceEpoch,
      "IsRunning": isRunning,
    };
    FlutterForegroundTask.sendDataToMain(data);

    // backgrund logic
    getTodosBG();
  }

  // Called when the task is destroyed.
  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('onDestroy');
    isRunning = false;
  }

  // Called when data is sent using `FlutterForegroundTask.sendDataToTask`.
  @override
  void onReceiveData(Object data) {
    print('onReceiveData: $data');
  }

  // void _sendDataToTask() {
  //   // Main(UI) -> TaskHandler
  //   //
  //   // The Map collection can only be sent in json format, such as Map<String, dynamic>.
  //   FlutterForegroundTask.sendDataToTask(Object);
  // }

  // Called when the notification button is pressed.
  @override
  void onNotificationButtonPressed(String id) {
    print('onNotificationButtonPressed: $id');
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
      serviceId: 512,
      notificationTitle: 'ApotM',
      notificationText: 'ApotM is running',
      notificationIcon: NotificationIcon(
        metaDataName: 'com.example.apotm.service.APOT_ICON',
        backgroundColor: Colors.green[300],
      ),
      notificationButtons: [
        const NotificationButton(id: 'reset', text: 'init'),
      ],
      notificationInitialRoute: '/',
      callback: startCallback,
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterLocalNotification.init();
  FlutterLocalNotification.requestNotificationPermissionAndroid();
  FlutterForegroundTask.initCommunicationPort();

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
