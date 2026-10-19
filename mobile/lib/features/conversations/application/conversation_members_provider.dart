import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/conversation_model.dart';
import '../data/repositories/conversations_repository.dart';

final FutureProviderFamily<List<ConversationMemberModel>, String> conversationMembersProvider =
    FutureProvider.family<List<ConversationMemberModel>, String>((ref, conversationId) {
  return ref.read(conversationsRepositoryProvider).fetchMembers(conversationId);
});
