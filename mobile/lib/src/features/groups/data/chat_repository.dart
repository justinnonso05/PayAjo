import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/config/env_config.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'chat_message.dart';

class ChatRepository {
  final ApiClient _apiClient;
  final SecureStorageService _secureStorage;

  ChatRepository({
    required ApiClient apiClient,
    required SecureStorageService secureStorage,
  })  : _apiClient = apiClient,
        _secureStorage = secureStorage;

  /// Chat history, oldest first. Note this endpoint returns a bare JSON
  /// array rather than the usual `{success, message, data}` envelope.
  Future<List<ChatMessage>> getHistory(String groupId, {int limit = 50, int offset = 0}) async {
    final list = await _apiClient.getList(
      ApiConstants.chatHistory(groupId, limit: limit, offset: offset),
      headers: await _secureStorage.authHeaders(),
    );
    final messages = list.whereType<Map<String, dynamic>>().map(ChatMessage.fromJson).toList();
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return messages;
  }

  /// Opens the group's live chat socket. The backend authenticates via a
  /// `?token=` query param (not a header) so it works identically across
  /// mobile and web clients. Sending a message is `{"message": "..."}`;
  /// every connected client (including the sender) receives a full
  /// [ChatMessage]-shaped JSON object back over the same socket.
  Future<WebSocketChannel> connect(String groupId) async {
    final token = await _secureStorage.readAccessToken();
    if (token == null || token.isEmpty) {
      throw ApiException('You need to sign in again.');
    }
    final uri = EnvConfig.wsUri(ApiConstants.chatWebSocket(groupId, token));
    return WebSocketChannel.connect(uri);
  }

  /// Uploads an image (with an optional text caption) to the group chat.
  /// The backend broadcasts the resulting message over the WebSocket to
  /// every connected client, including the sender — same "wait for the
  /// echo" pattern as text messages, so this just needs to succeed.
  Future<void> sendImage(
    String groupId, {
    required List<int> bytes,
    required String filename,
    String? contentType,
    String? caption,
  }) async {
    await _apiClient.postMultipart(
      ApiConstants.chatImage(groupId),
      fileBytes: bytes,
      filename: filename,
      contentType: contentType,
      fields: caption != null && caption.trim().isNotEmpty ? {'message': caption.trim()} : null,
      headers: await _secureStorage.authHeaders(),
    );
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    apiClient: ref.watch(apiClientProvider),
    secureStorage: ref.watch(secureStorageServiceProvider),
  );
});
