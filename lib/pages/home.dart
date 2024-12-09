// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:convert';
import 'package:apotm/pages/login.dart';
import 'package:apotm/type.dart';
import 'package:flutter/material.dart';
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
  List<ITodo> todos = [];

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
            print(!todos[todoIndex].everydays[indexOfEandP].done);
          }
          if (EorP == 1) {
            todos[todoIndex].plans[indexOfEandP].done =
                !todos[todoIndex].plans[indexOfEandP].done;
            print(!todos[todoIndex].plans[indexOfEandP].done);
          }
        });
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
            if (newAccessToken != null && newAccessToken.isNotEmpty) {
              await storage.write(key: "access_token", value: newAccessToken);
            }
            setState(() {
              isLoading = false;
            });
          }
        } catch (e) {
          print("Failed to refresh AT with $e, status: ${response.statusCode}");
        }
      }
      if (response.statusCode != 200 && response.statusCode != 401) {
        print(
            'Failed to put with status ${response.statusCode}, error: ${response.request?.url}');
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
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Jwt': '$accessToken',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        var utf8Body = utf8.decode(response.bodyBytes);
        List<dynamic> jsonData = json.decode(utf8Body);
        setState(() {
          todos = jsonData.map((json) => ITodo.fromJson(json)).toList();
          isLoading = false;
        });
      }
      if (response.statusCode != 200) {
        retryCount++;
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
              return await getTodos();
            }
            setState(() {
              isLoading = false;
            });
          }
        } catch (e) {
          print("Failed to refresh AT with $e");
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
    getTodos();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
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
