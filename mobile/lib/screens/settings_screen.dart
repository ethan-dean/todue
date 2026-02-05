import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/accent_color_picker.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/timezone_selector.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = '${info.version} (${info.buildNumber})';
        });
      }
    } catch (_) {
      // Ignore if package info not available
    }
  }

  Future<void> _handleLogout() async {
    final result = await AppChoiceDialog.show(
      context: context,
      description: 'Are you sure you want to logout?',
      options: [
        const AppChoiceOption(label: 'Logout', value: 'logout', isDestructive: true),
      ],
    );

    if (result == 'logout' && mounted) {
      final authProvider = context.read<AuthProvider>();
      await authProvider.logout();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  void _openTimezoneSelector() {
    final authProvider = context.read<AuthProvider>();
    final currentTz = authProvider.user?.timezone ?? 'UTC';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TimezoneSelector(
          currentTimezone: currentTz,
          onSelected: (tz) async {
            try {
              await authProvider.updateTimezone(timezone: tz);
            } catch (_) {
              // Error handled in provider
            }
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
    );
  }

  Widget _buildThemeOption(String label, ThemeMode mode, ThemeProvider themeProvider) {
    final isSelected = themeProvider.themeMode == mode;
    final primary = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () => themeProvider.setThemeMode(mode),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? primary : Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check, size: 20, color: primary),
          ],
        ),
      ),
    );
  }

  Widget _buildRow({
    required String label,
    String? subtitle,
    VoidCallback? onTap,
    Color? labelColor,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      color: labelColor ?? Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SETTINGS',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Consumer2<ThemeProvider, AuthProvider>(
        builder: (context, themeProvider, authProvider, _) {
          final userTimezone = authProvider.user?.timezone ?? 'UTC';

          return ListView(
            children: [
              // Theme Section
              _buildSectionHeader('Theme'),
              _buildThemeOption('System', ThemeMode.system, themeProvider),
              _buildDivider(),
              _buildThemeOption('Light', ThemeMode.light, themeProvider),
              _buildDivider(),
              _buildThemeOption('Dark', ThemeMode.dark, themeProvider),

              // Accent Color Section
              _buildSectionHeader('Accent Color'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: const AccentColorPicker(),
              ),

              // Timezone Section
              _buildSectionHeader('Timezone'),
              _buildRow(
                label: userTimezone.replaceAll('_', ' '),
                onTap: _openTimezoneSelector,
                trailing: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

              // Account Section
              _buildSectionHeader('Account'),
              _buildRow(
                label: 'Logout',
                labelColor: Colors.red,
                onTap: _handleLogout,
              ),

              // Version
              _buildSectionHeader('About'),
              _buildRow(
                label: 'Version',
                subtitle: _version.isNotEmpty ? _version : 'Loading...',
              ),

              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}
