import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/todo_screen.dart';
import '../screens/later_lists_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/later_list_provider.dart';
import '../providers/todo_provider.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    if (index == 1 && _selectedIndex == 1) {
      // User tapped "Later" while on "Later" - go back to list view
      context.read<LaterListProvider>().setCurrentListId(null);
    } else if (index == 0 && _selectedIndex == 0) {
      // User tapped "Now" while on "Now" - go back to today
      context.read<TodoProvider>().selectDate(DateTime.now());
    }
    
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _handleLogout() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.logout();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LaterListProvider>(
      builder: (context, laterListProvider, _) {
        String title;
        if (_selectedIndex == 0) {
          title = 'Now';
        } else {
          // Check if we are viewing a specific list
          if (laterListProvider.currentListId != null) {
            final list = laterListProvider.lists
                .where((l) => l.id == laterListProvider.currentListId)
                .firstOrNull;
            title = list?.listName ?? 'Later';
          } else {
            title = 'Later';
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            actions: [
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return IconButton(
                    icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                    onPressed: () {
                      themeProvider.toggleTheme();
                    },
                    tooltip: isDark ? 'Light Mode' : 'Dark Mode',
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _handleLogout,
                tooltip: 'Logout',
              ),
            ],
          ),
          body: IndexedStack(
            index: _selectedIndex,
            children: const [
              TodoScreen(),
              LaterListsScreen(),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: Colors.green,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.today),
                label: 'Now',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.list_alt),
                label: 'Later',
              ),
            ],
          ),
        );
      },
    );
  }
}
