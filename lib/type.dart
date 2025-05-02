class IEveryday {
  final int id;
  String name;
  String time;
  bool done;

  IEveryday({
    required this.id,
    required this.name,
    required this.time,
    required this.done,
  });

  factory IEveryday.fromJson(Map<String, dynamic> json) {
    return IEveryday(
      id: json['id'],
      name: json['name'],
      time: json['time'],
      done: json['done'],
    );
  }
}

class IPlan {
  final int id;
  String name;
  String time;
  String description;
  bool done;

  IPlan({
    required this.id,
    required this.name,
    required this.time,
    required this.description,
    required this.done,
  });

  // JSON -> IPlan 객체
  factory IPlan.fromJson(Map<String, dynamic> json) {
    return IPlan(
      id: json['id'],
      name: json['name'],
      time: json['time'],
      description: json['description'],
      done: json['done'],
    );
  }
}

class ITodo {
  final int id;
  List<IEveryday> everydays;
  List<IPlan> plans;
  String name;

  ITodo({
    required this.id,
    required this.everydays,
    required this.plans,
    required this.name,
  });

  // JSON -> ITodo 객체
  factory ITodo.fromJson(Map<String, dynamic> json) {
    return ITodo(
      id: json['id'],
      name: json['name'],
      everydays: (json['everydays'] as List)
          .map((item) => IEveryday.fromJson(item))
          .toList(),
      plans:
          (json['plans'] as List).map((item) => IPlan.fromJson(item)).toList(),
    );
  }
}

class IAlarmData {
  final int id;
  final String title;
  final String body;

  IAlarmData({
    required this.id,
    required this.title,
    required this.body,
  });

  factory IAlarmData.fromJson(Map<String, dynamic> json) {
    return IAlarmData(
      id: json['id'],
      title: json['title'],
      body: json['body'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
    };
  }
}

class IInitDoneData {
  final int todoId;
  final int everydayId;
  final String name;
  final String time;

  IInitDoneData({
    required this.todoId,
    required this.everydayId,
    required this.name,
    required this.time,
  });

  factory IInitDoneData.fromJson(Map<String, dynamic> json) {
    return IInitDoneData(
      todoId: json['todoId'],
      everydayId: json['everydayId'],
      name: json['name'],
      time: json['time'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'todoId': todoId,
      'everydayId': everydayId,
      'name': name,
      'time': time,
    };
  }
}
