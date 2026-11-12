import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:to_do_list/providers/todo_provider.dart';
import 'package:to_do_list/screens/main_navigator.dart';
import 'package:to_do_list/theme/app_theme.dart';
import 'package:to_do_list/services/notification_service.dart';
import 'package:to_do_list/services/sun_service.dart';
import 'package:to_do_list/widgets/celebration.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sets the device time zone (used by reminders and sun times) and the
  // notification plugin, then asks for notification permission on phones.
  try {
    await NotificationService().init();
    if (!kIsWeb) await NotificationService().requestPermissions();
  } catch (e) {
    debugPrint('Error initializing notifications: $e');
  }

  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TodoProvider()..loadTodos()),
        ChangeNotifierProvider(create: (_) => SunService()..init()),
      ],
      child: Consumer<TodoProvider>(
        builder: (context, todoProvider, _) {
          return MaterialApp(
            title: 'Habit Builder',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: todoProvider.themeMode,
            // Confetti layer above every screen, sheet and dialog.
            builder: (context, child) =>
                CelebrationOverlay(child: child ?? const SizedBox.shrink()),
            home: kIsWeb ? const MobileFrame(child: MainNavigator()) : const MainNavigator(),
          );
        },
      ),
    );
  }
}

// Mobile frame wrapper for web view (9:16 aspect ratio)
class MobileFrame extends StatelessWidget {
  final Widget child;

  const MobileFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    const double mobileWidth = 412.0;  // Standard mobile width
    const double mobileHeight = 732.0; // 9:16 ratio (412 * 16/9)

    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      body: Center(
        child: Container(
          width: mobileWidth,
          height: mobileHeight,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 8),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }
}
