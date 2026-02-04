import 'package:flutter/material.dart';

class AppBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              builder(context),
            ],
          ),
        );
      },
    );
  }
}

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final bool autofocus;
  final int? maxLines;
  final int? maxLength;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  const AppTextField({
    Key? key,
    required this.controller,
    this.hintText,
    this.autofocus = false,
    this.maxLines,
    this.maxLength,
    this.onSubmitted,
    this.textInputAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      autofocus: autofocus,
      maxLines: maxLines,
      maxLength: maxLength,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 17),
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: isDark ? const Color(0xFF3A3A3C) : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class AppActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const AppActionButton({
    Key? key,
    required this.label,
    this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}

class AppCancelButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const AppCancelButton({Key? key, this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF3A3A3C) : Colors.grey[200],
          foregroundColor: isDark ? Colors.white : Colors.black87,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text('Cancel'),
      ),
    );
  }
}

class AppChoiceDialog extends StatelessWidget {
  final String description;
  final List<AppChoiceOption> options;
  final VoidCallback? onCancel;

  const AppChoiceDialog({
    Key? key,
    required this.description,
    required this.options,
    this.onCancel,
  }) : super(key: key);

  static Future<String?> show({
    required BuildContext context,
    required String description,
    required List<AppChoiceOption> options,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => AppChoiceDialog(
        description: description,
        options: options,
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ...options.map((option) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(option.value),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: option.isDestructive
                          ? Colors.red
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    child: Text(option.label),
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppChoiceOption {
  final String label;
  final String value;
  final bool isDestructive;

  const AppChoiceOption({
    required this.label,
    required this.value,
    this.isDestructive = false,
  });
}
