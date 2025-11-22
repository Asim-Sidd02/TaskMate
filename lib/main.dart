import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:task_mate/services/note_service.dart';

import 'services/auth_service.dart';
import 'services/task_service.dart';
import 'services/notification_service.dart';
import 'providers/app_settings.dart';
import 'screens/home_screen.dart';
import 'screens/WelcomeScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // initialize notification plugin early
  await NotificationService().init();

  // Create and initialize AuthService BEFORE runApp so app knows login state immediately
  final authService = AuthService();
  await authService.init(); // loads token / user data from secure storage
  debugPrint('[main] AuthService init done: loggedIn=${authService.loggedIn}');



  runApp(
    MyApp(authService: authService),
  );
}

class MyApp extends StatelessWidget {
  final AuthService authService;

  const MyApp({Key? key, required this.authService}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MultiProvider(
          providers: [

            // Provide the already-initialized AuthService instance
            ChangeNotifierProvider<AuthService>.value(value: authService),

            // TaskService depends on auth; give it a chance to receive auth updates
            ChangeNotifierProxyProvider<AuthService, TaskService>(
              create: (_) => TaskService(),
              update: (_, auth, taskService) {
                // taskService is the previously created instance (non-null)
                taskService!.updateAuth(auth);
                return taskService;
              },
            ),
// inside MultiProvider providers:
            ChangeNotifierProxyProvider<AuthService, NoteService>(
              create: (_) => NoteService(),
              update: (_, auth, noteService) {
                noteService ??= NoteService();
                noteService.updateAuth(auth);
                return noteService;
              },
            ),


            ChangeNotifierProvider<AppSettings>(create: (_) => AppSettings()..load()),

            // NotificationService is a singleton; provide if you want DI
            Provider<NotificationService>(create: (_) => NotificationService()),
          ],
          child: Consumer<AppSettings>(
            builder: (context, settings, _) {
              final theme = settings.currentThemeData;
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                title: 'TaskMate',
                theme: theme,
                home: RootDecider(),
              );
            },
          ),
        );
      },
    );
  }
}

class RootDecider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    // While AuthService init is quick (we awaited it), if you still want a loader:
    if (auth.initializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // If logged in, go to HomeScreen — otherwise Welcome.
    return auth.loggedIn ? HomeScreen() : WelcomeScreen();
  }
}
