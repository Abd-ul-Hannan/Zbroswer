import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SearchHistoryController extends GetxController {
  final searchHistory = <String>[].obs;
  static const String _key = 'search_history';
  static const int _maxHistory = 20;

  @override
  void onInit() {
    super.onInit();
    loadHistory();
  }

  Future<void> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList(_key) ?? [];
      searchHistory.assignAll(data);
    } catch (e) {
      print('Error loading search history: $e');
    }
  }

  Future<void> addSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    searchHistory.remove(query);
    searchHistory.insert(0, query);
    
    if (searchHistory.length > _maxHistory) {
      searchHistory.removeRange(_maxHistory, searchHistory.length);
    }
    
    await _saveHistory();
  }

  Future<void> deleteSearch(String query) async {
    searchHistory.remove(query);
    await _saveHistory();
  }

  Future<void> clearHistory() async {
    searchHistory.clear();
    await _saveHistory();
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, searchHistory.toList());
    } catch (e) {
      print('Error saving search history: $e');
    }
  }

  List<String> getFilteredHistory(String query) {
    if (query.isEmpty) return searchHistory.toList();
    return searchHistory
        .where((item) => item.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
}
