import 'package:flutter/services.dart';

class HapticService {
  static void toggle() => HapticFeedback.lightImpact();
  static void action() => HapticFeedback.mediumImpact();
  static void destructive() => HapticFeedback.heavyImpact();
}
