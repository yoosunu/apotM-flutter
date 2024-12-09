// import 'dart:async';
// import 'package:path/path.dart';
// import 'package:sqflite/sqflite.dart';

// // define class DatabaseHelper
// class DatabaseHelper {
//   static DatabaseHelper? _databaseHelper;
//   static Database? _database;

//   // store notifications table defining
//   static const String secondTableName = 'save';

//   static const String secondColumnCode = 'codeSaved';
//   static const String secondColumnTag = 'tagSaved';
//   static const String secondColumnTitle = 'titleSaved';
//   static const String secondColumnLink = 'linkSaved';
//   static const String secondColumnWriter = 'writerSaved';
//   static const String secondColumnEtc = 'etcSaved';
//   static const String secondColumnCreatedAt = 'createdAtSaved';
//   static const String secondColumnTimeStamp = 'timeStampSaved';

//   DatabaseHelper._createInstance();

//   factory DatabaseHelper() {
//     _databaseHelper ??= DatabaseHelper._createInstance();
//     return _databaseHelper!;
//   }

//   Future<Database> get database async {
//     _database ??= await initializeDatabase();
//     return _database!;
//   }

//   Future<Database> initializeDatabase() async {
//     String path = join(await getDatabasesPath(), 'save.db');
//     return await openDatabase(
//       path,
//       version: 1,
//       onCreate: (Database db, int version) async {
//         await db.execute('''
//           CREATE TABLE IF NOT EXISTS $secondTableName(
//             $secondColumnCode INTEGER,
//             $secondColumnTag TEXT,
//             $secondColumnTitle TEXT,
//             $secondColumnLink TEXT,
//             $secondColumnWriter TEXT,
//             $secondColumnEtc TEXT,
//             $secondColumnCreatedAt TEXT,
//             $secondColumnTimeStamp TEXT
//           )
//           ''');
//       },
//       onUpgrade: (Database db, int oldVersion, int newVersion) async {
//         await db.execute('''
//           CREATE TABLE IF NOT EXISTS $secondTableName(
//             $secondColumnCode INTEGER,
//             $secondColumnTag TEXT,
//             $secondColumnTitle TEXT,
//             $secondColumnLink TEXT,
//             $secondColumnWriter TEXT,
//             $secondColumnEtc TEXT,
//             $secondColumnCreatedAt TEXT,
//             $secondColumnTimeStamp TEXT
//           )
//         ''');
//       },
//     );
//   }

//   Future<void> resetStoredTable() async {
//     Database db = await database;

//     await db.execute('DROP TABLE IF EXISTS $secondTableName');

//     await db.execute('''
//       CREATE TABLE $secondTableName(
//         $secondColumnCode INTEGER,
//             $secondColumnTag TEXT,
//             $secondColumnTitle TEXT,
//             $secondColumnLink TEXT,
//             $secondColumnWriter TEXT,
//             $secondColumnEtc TEXT,
//             $secondColumnCreatedAt TEXT,
//             $secondColumnTimeStamp TEXT
//       )
//     ''');
//   }

//   Future<int> saveNotification(Map<String, dynamic> info) async {
//     info[secondColumnTimeStamp] = DateTime.now().toIso8601String();
//     if (info.containsKey('created_at') && info['created_at'] is DateTime) {
//       info['created_at'] = (info['created_at'] as DateTime).toIso8601String();
//     }
//     Database db = await database;
//     return await db.insert(secondTableName, info);
//   }

//   Future<int> deleteNotification(int codeSaved) async {
//     Database db = await database;
//     return await db.delete(
//       secondTableName,
//       where: '$secondColumnCode = ?',
//       whereArgs: [codeSaved],
//     );
//   }

//   Future<List<Map<String, dynamic>>> getStoredData() async {
//     Database db = await database;
//     return db.query(secondTableName);
//   }
// }
