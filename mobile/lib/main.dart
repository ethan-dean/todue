import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/todo_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/later_list_provider.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'widgets/main_navigation.dart';
import 'services/todo_api.dart';
import 'services/later_list_api.dart';
import 'services/database_service.dart';
import 'services/websocket_service.dart';
import 'config/environment.dart';

void main() {
  Environment.printEnvironment();
  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
          create: (_) => TodoProvider(
            todoApi: TodoApi.instance,
            databaseService: DatabaseService.instance,
            websocketService: WebSocketService.instance,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => LaterListProvider(
            laterListApi: LaterListApi.instance,
            websocketService: WebSocketService.instance,
            databaseService: DatabaseService.instance,
          ),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Todue',
            debugShowCheckedModeBanner: false,
            theme: ThemeProvider.lightTheme,
            darkTheme: ThemeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const AuthWrapper(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/forgot-password': (context) => const ForgotPasswordScreen(),
              '/todos': (context) => const MainNavigation(),
            },
            onGenerateRoute: (settings) {
              // Handle routes with parameters
              if (settings.name == '/reset-password') {
                final token = settings.arguments as String;
                return MaterialPageRoute(
                  builder: (context) => ResetPasswordScreen(token: token),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}

/// Wrapper that checks authentication and shows appropriate screen
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Show loading while checking authentication
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
          );
        }

        // Show main app if authenticated, otherwise show login
        if (authProvider.isAuthenticated) {
          return const MainNavigation();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

