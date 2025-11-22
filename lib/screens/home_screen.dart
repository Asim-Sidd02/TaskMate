import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import '../services/task_service.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import './task_list.dart';
import './settings_screen.dart';
import 'HomeScreenComponents/AddTaskSheet.dart';
import 'HomeScreenComponents/TaskListItem.dart';
import 'HomeScreenComponents/TopBar.dart';
import 'HomeScreenComponents/TaskSection.dart';
import './notes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime selectedDay = DateTime.now();
  int _bottomNavIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<TaskService>().fetchTasks());
  }

  List dueTodayTasks(List all) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return all.where((t) {
      final rawDate = t['endDate'];
      if (rawDate == null) return false;
      try {
        final d = DateTime.parse(rawDate);
        return DateFormat('yyyy-MM-dd').format(d) == todayStr;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  List activeTasks(List all) {
    return all.where((t) => (t['status'] ?? '').toLowerCase() == 'active').toList();
  }

  List notStartedTasks(List all) {
    return all.where((t) => (t['status'] ?? '').toLowerCase() == 'not started').toList();
  }

  List<Widget> get _pages => [
    _HomePageBody(onAdd: () => _showAddDialog(context)),
    TaskListScreen(),
    NotesScreen(),
    SettingsScreen(),

  ];

  @override
  Widget build(BuildContext context) {
    context.watch<TaskService>();

    return SafeArea(
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: const Color(0xFF0F0F10),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _bottomNavIndex,
          onTap: (i) => setState(() => _bottomNavIndex = i),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white54,
          backgroundColor: const Color(0xFF151516),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: "Tasks"),
            BottomNavigationBarItem(icon: Icon(Icons.note), label: "Notes"),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          ],
        ),
        body: IndexedStack(
          index: _bottomNavIndex,
          children: _pages,
        ),
      ),
    );
  }


  void _showAddDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddTaskSheet(),
    );
  }
}


class _HomePageBody extends StatelessWidget {
  final VoidCallback onAdd;
  const _HomePageBody({Key? key, required this.onAdd}) : super(key: key);

  List dueTodayTasks(List all) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return all.where((t) {
      final rawDate = t['endDate'];
      if (rawDate == null) return false;
      try {
        final d = DateTime.parse(rawDate);
        return DateFormat('yyyy-MM-dd').format(d) == todayStr;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  List activeTasks(List all) {
    return all.where((t) => (t['status'] ?? '').toLowerCase() == 'active').toList();
  }

  List notStartedTasks(List all) {
    return all.where((t) => (t['status'] ?? '').toLowerCase() == 'not started').toList();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<TaskService>();
    final tasks = service.tasks ?? [];

    final dueToday = dueTodayTasks(tasks);
    final active = activeTasks(tasks);
    final notStarted = notStartedTasks(tasks);

    final horizontalPadding = 4.w;
    final bottomSafePadding =
        MediaQuery.of(context).viewPadding.bottom + MediaQuery.of(context).viewInsets.bottom + 24.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(top: 1.h, bottom: bottomSafePadding),
        children: [
          SizedBox(height: 0.5.h),
          TopBar(onAdd: onAdd),
          SizedBox(height: 2.h),

          // Due Today
          TaskSection(
            title: "Due Today",
            emptyMessage: "No tasks due today",
            children: dueToday.isEmpty
                ? []
                : dueToday
                .map((t) => TaskListItem(task: t, compact: false))
                .toList(),
          ),
          SizedBox(height: 2.h),

          // Active Tasks
          TaskSection(
            title: "Active Tasks",
            emptyMessage: "No active tasks",
            children: active.isEmpty
                ? []
                : active
                .map((t) => TaskListItem(task: t, compact: true))
                .toList(),
          ),
          SizedBox(height: 2.h),


          TaskSection(
            title: "Not Started Tasks",
            emptyMessage: "No tasks",
            children: notStarted.isEmpty
                ? []
                : notStarted
                .map((t) => TaskListItem(task: t, compact: true))
                .toList(),
          ),

          SizedBox(height: 4.h),
        ],
      ),
    );
  }
}





