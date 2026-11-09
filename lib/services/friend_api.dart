import 'package:shared_preferences/shared_preferences.dart';

import '../services/local_app_data_service.dart';
import '../services/local_auth_service.dart';

class FriendApi {
  static Future<int?> _currentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');
  }

  static Future<String> _currentUserName() async {
    final user = await LocalAuthService.currentUser();
    return user?['name']?.toString() ?? 'Saya';
  }

  static Future<List<Map<String, dynamic>>> getFriends() async {
    final uid = await _currentUserId();
    if (uid == null) return [];
    return LocalAppDataService.getFriends(uid);
  }

  static Future<String> sendFriendRequest(int friendId, String friendName) async {
    final uid = await _currentUserId();
    if (uid == null) return 'none';
    final name = await _currentUserName();
    return LocalAppDataService.sendFriendRequest(uid, name, friendId, friendName);
  }

  static Future<void> removeFriend(int friendId) async {
    final uid = await _currentUserId();
    if (uid == null) return;
    await LocalAppDataService.removeFriend(uid, friendId);
  }

  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final uid = await _currentUserId();
    if (uid == null) return [];
    return LocalAppDataService.searchUsers(uid, query);
  }

  static Future<List<Map<String, dynamic>>> getIncomingRequests() async {
    final uid = await _currentUserId();
    if (uid == null) return [];
    return LocalAppDataService.getIncomingFriendRequests(uid);
  }

  static Future<List<Map<String, dynamic>>> getOutgoingRequests() async {
    final uid = await _currentUserId();
    if (uid == null) return [];
    return LocalAppDataService.getOutgoingFriendRequests(uid);
  }

  static Future<void> acceptRequest(int requestId) async {
    final uid = await _currentUserId();
    if (uid == null) return;
    await LocalAppDataService.acceptFriendRequest(requestId, uid);
  }

  static Future<void> rejectRequest(int requestId) async {
    final uid = await _currentUserId();
    if (uid == null) return;
    await LocalAppDataService.rejectFriendRequest(requestId, uid);
  }

  static Future<String> requestStatus(int friendId) async {
    final uid = await _currentUserId();
    if (uid == null) return 'none';
    return LocalAppDataService.friendRequestStatus(uid, friendId);
  }

  static Future<List<Map<String, dynamic>>> getMessages(int friendId) async {
    final uid = await _currentUserId();
    if (uid == null) return [];
    return LocalAppDataService.getDMMessages(uid, friendId);
  }

  static Future<void> sendMessage(int friendId, String text) async {
    final uid = await _currentUserId();
    if (uid == null) return;
    final name = await _currentUserName();
    await LocalAppDataService.sendDM(uid, friendId, text, name);
  }
}
