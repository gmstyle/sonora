import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/ask_storage_repository_impl.dart';
import '../../domain/models/ask_chat_models.dart';
import '../../domain/repositories/ask_storage_repository.dart';
import 'database_provider.dart';

final askStorageRepositoryProvider = Provider<AskStorageRepository>((ref) {
  return AskStorageRepositoryImpl(ref.watch(databaseProvider));
});

final askConversationsProvider = StreamProvider<List<AskConversationSummary>>((
  ref,
) {
  return ref.watch(askStorageRepositoryProvider).watchConversations();
});

final askMessagesProvider = StreamProvider.family<List<AskChatMessage>, String>(
  (ref, conversationId) {
    return ref
        .watch(askStorageRepositoryProvider)
        .watchMessages(conversationId);
  },
);

final askActiveDropsProvider = StreamProvider<List<AskProactiveDrop>>((ref) {
  return ref.watch(askStorageRepositoryProvider).watchActiveDrops();
});
