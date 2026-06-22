import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/scan_item.dart';

class StorageService {
  static const String _fileName = 'scan_history.json';

  /// Gets the reference to the local file where scan history is saved.
  Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  /// Loads the scan history list from the local JSON file.
  Future<List<ScanItem>> loadHistory() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        return [];
      }
      final contents = await file.readAsString();
      final decoded = jsonDecode(contents);
      if (decoded is List) {
        return decoded
            .map((item) => ScanItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error loading history: $e');
      }
      return [];
    }
  }

  /// Saves the updated list of ScanItems to the local JSON file.
  Future<bool> saveHistory(List<ScanItem> history) async {
    try {
      final file = await _localFile;
      final serializedList = history.map((item) => item.toJson()).toList();
      final jsonString = jsonEncode(serializedList);
      await file.writeAsString(jsonString);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving history: $e');
      }
      return false;
    }
  }
}
