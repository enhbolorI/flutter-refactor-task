import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:refactor_task/model/item.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TaskListScreen extends StatefulWidget {

  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  ViewType _viewType = ViewType.list;

  final RxBool _isLightTheme = false.obs;
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  _saveThemeStatus() async {
    SharedPreferences pref = await _prefs;
    pref.setBool('theme', _isLightTheme.value);
  }

  _getThemeStatus() async {
    var isLight = _prefs.then((SharedPreferences prefs) {
      return prefs.getBool('theme') ?? true;
    }).obs;
    _isLightTheme.value = await isLight.value;
    Get.changeThemeMode(_isLightTheme.value ? ThemeMode.light : ThemeMode.dark);
  }

  final _itemsController = StreamController<List<Item>>.broadcast();
  Stream<List<Item>> get itemsStream => _itemsController.stream;

  @override
  void initState() {
    super.initState();
    _getThemeStatus();
    hiveInit();
  }

  hiveInit() async {
    Directory appDocDirectory = await getApplicationDocumentsDirectory();
    var path = appDocDirectory.path;
    Hive
      ..init(path)
      ..registerAdapter(ItemAdapter());
    _refreshItems();
  }

  Future<void> _refreshItems() async {
    Box box1 = await Hive.openBox('task_list');
    final data = box1.keys.map((key) {
      final value = box1.get(key);
      return {"id": value["id"], "title": value["title"], "description": value['description']};
    }).toList();
    final itemList = data.reversed.map((item) => Item.fromJson(item)).toList();
    _itemsController.add(itemList);
  }

  Future<void> fetchAndStoreItems() async {
    Box box1 = await Hive.openBox('task_list');
    final response = await http.get(Uri.parse('https://jsonplaceholder.typicode.com/posts'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      final itemList = data.map((item) => Item.fromJson(item)).toList();
      for (var item in itemList) {
        box1.put('items', item.toJson());
      }

      _itemsController.add(itemList);
    } else {
      _itemsController.addError('Failed to fetch data from API');
    }
  }

  @override
  void dispose() {
    _itemsController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Refactor Task App'),
        actions: [
          // light and dark theme mode change button
          ObxValue((data) => Switch(
            activeColor: Theme.of(context).secondaryHeaderColor,
            value: _isLightTheme.value,
            onChanged: (val) {
              _isLightTheme.value = val;
              Get.changeThemeMode(_isLightTheme.value ? ThemeMode.light : ThemeMode.dark,);
              _saveThemeStatus();
            },
          ), false.obs,),
          IconButton(
            tooltip: 'change view listener',
            icon: _viewType == ViewType.list ? const Icon(Icons.list) : const Icon(Icons.grid_view),
            onPressed: () {
              if(_viewType == ViewType.list){
                _viewType = ViewType.grid;
              } else {
                _viewType = ViewType.list;
              }
              setState(() {});
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Item>>(
        stream: _itemsController.stream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            if(_viewType == ViewType.grid){
              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 3 / 4,
                  crossAxisSpacing: 5,
                  mainAxisSpacing: 5,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: snapshot.data?.length ?? 0,
                itemBuilder: (context, index) {
                  final item = snapshot.data![index];
                  return Card(
                    elevation: 4,
                    shadowColor: Colors.black12,
                    child: ListTile(
                      title: Text(item.title ?? ''),
                      subtitle: Text(item.description ?? ''),
                    ),
                  );
                },
              );
            } else {
              return ListView.builder(
                itemCount: snapshot.data?.length ?? 0,
                itemBuilder: (context, index) {
                  final item = snapshot.data![index];
                  return ListTile(
                    title: Text(item.title ?? ''),
                    subtitle: Text(item.description ?? ''),
                  );
                },
              );
            }
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: fetchAndStoreItems,
        tooltip: 'Fetch Data',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

enum ViewType { grid, list }