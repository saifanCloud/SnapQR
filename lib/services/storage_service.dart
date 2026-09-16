import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_item.dart';

class StorageService {
  static const String _prefsKey = 'scan_history_data';
  static const String _fileName = 'scan_history.json';

  /// Loads the scan history list from SharedPreferences (or migrates from local file).
  Future<List<ScanItem>> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_prefsKey);

      if (savedJson != null && savedJson.isNotEmpty) {
        final decoded = jsonDecode(savedJson);
        if (decoded is List) {
          return decoded
              .map((item) => ScanItem.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }

      // Fallback migration: check old file on mobile if SharedPreferences is empty
      if (!kIsWeb) {
        try {
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/$_fileName');
          if (await file.exists()) {
            final contents = await file.readAsString();
            final decoded = jsonDecode(contents);
            if (decoded is List) {
              final items = decoded
                  .map((item) => ScanItem.fromJson(item as Map<String, dynamic>))
                  .toList();
              await saveHistory(items);
              return items;
            }
          }
        } catch (_) {}
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error loading history: $e');
      }
      return [];
    }
  }

  /// Saves the updated list of ScanItems.
  /// Hard-capped at 500 items to prevent unbounded storage growth.
  Future<bool> saveHistory(List<ScanItem> history) async {
    try {
      final capped = history.length > 500 ? history.sublist(0, 500) : history;
      final serializedList = capped.map((item) => item.toJson()).toList();
      final jsonString = jsonEncode(serializedList);

      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setString(_prefsKey, jsonString);

      // Also sync to file on native platforms if available
      if (!kIsWeb) {
        try {
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/$_fileName');
          await file.writeAsString(jsonString);
        } catch (_) {}
      }

      return success;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving history: $e');
      }
      return false;
    }
  }

  /// Clears all history from storage.
  Future<bool> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);

      if (!kIsWeb) {
        try {
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/$_fileName');
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing history: $e');
      }
      return false;
    }
  }
}
