import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/call_log_entry.dart';

class CallLogService {
  static final CallLogService _instance = CallLogService._();
  factory CallLogService() => _instance;
  CallLogService._();

  static const _key = 'call_log';
  static const _maxEntries = 100;

  final notifier = ValueNotifier<int>(0);

  Future<List<CallLogEntry>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((s) => CallLogEntry.fromJson(jsonDecode(s))).toList();
  }

  Future<void> add(CallLogEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.insert(0, jsonEncode(entry.toJson()));
    if (raw.length > _maxEntries) raw.removeRange(_maxEntries, raw.length);
    await prefs.setStringList(_key, raw);
    notifier.value++;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    notifier.value++;
  }
}
