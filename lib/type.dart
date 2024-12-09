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
