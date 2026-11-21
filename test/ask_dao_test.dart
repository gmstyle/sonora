import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/data/datasources/local/database.dart';
import 'package:sonora/data/repositories/ask_storage_repository_impl.dart';
import 'package:sonora/domain/models/ask_chat_models.dart';
import 'package:sonora/domain/models/grounded_llm_result.dart';

void main() {
  late AppDatabase db;
  late AskStorageRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = AskStorageRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('AskDao & AskStorageRepositoryImpl (Drift v27)', () {
    test(
      'persists conversations, messages, and roundtrips attachments',
      () async {
        final t1 = DateTime(2026, 11, 21, 10, 0);
        final t2 = DateTime(2026, 11, 21, 10, 1);

        await repo.upsertConversation(
          AskConversationSummary(
            id: 'conv_1',
            title: 'Mix serale',
            createdAt: t1,
            updatedAt: t1,
          ),
        );

        await repo.insertMessage(
          AskChatMessage(
            id: 'msg_1',
            conversationId: 'conv_1',
            role: 'user',
            content: 'Fammi una playlist jazz notturna',
            createdAt: t1,
          ),
        );

        const mix = AskMixAttachment(
          title: 'Midnight Jazz',
          tracks: [
            AskTrackRef(
              videoId: 'v_jazz_1',
              title: 'Blue in Green',
              artist: 'Miles Davis',
              durationSec: 327,
            ),
          ],
        );
        const proposal = AskPlaylistWriteProposal(
          operation: 'create',
          playlistName: 'Midnight Jazz',
          tracks: [
            AskTrackRef(
              videoId: 'v_jazz_1',
              title: 'Blue in Green',
              artist: 'Miles Davis',
            ),
          ],
        );
        const insights = AskInsightsAttachment(
          title: 'Curiosità',
          bullets: ['Registrata nel 1959.'],
          sources: [
            GroundedSource(uri: 'https://en.wikipedia.org/wiki/Kind_of_Blue'),
          ],
        );

        await repo.insertMessage(
          AskChatMessage(
            id: 'msg_2',
            conversationId: 'conv_1',
            role: 'assistant',
            content: 'Ecco la mia proposta!',
            attachments: [mix, proposal, insights],
            toolNamesUsed: ['search_catalog', 'propose_mix'],
            createdAt: t2,
          ),
        );

        final convs = await repo.getConversations();
        expect(convs, hasLength(1));
        expect(convs.single.title, 'Mix serale');

        final msgs = await repo.getMessages('conv_1');
        expect(msgs, hasLength(2));
        expect(msgs[1].toolNamesUsed, ['search_catalog', 'propose_mix']);
        expect(msgs[1].attachments, hasLength(3));
        expect(
          (msgs[1].attachments[0] as AskMixAttachment).title,
          'Midnight Jazz',
        );
        expect(
          (msgs[1].attachments[1] as AskPlaylistWriteProposal).isPending,
          isTrue,
        );
        expect(
          (msgs[1].attachments[2] as AskInsightsAttachment)
              .sources
              .single
              .displayTitle,
          'en.wikipedia.org',
        );

        // Update Safe Write status to saved.
        await repo.updateMessageAttachments('msg_2', [
          mix.copyWith(savedPlaylistId: 42),
          proposal.copyWith(status: 'saved', savedPlaylistId: 42),
          insights,
        ]);
        final updated = await repo.getMessages('conv_1');
        final savedProp = updated[1].attachments[1] as AskPlaylistWriteProposal;
        expect(savedProp.status, 'saved');
        expect(savedProp.savedPlaylistId, 42);

        // Deleting conversation cascades to its messages.
        await repo.deleteConversation('conv_1');
        expect(await repo.getConversations(), isEmpty);
        expect(await repo.getMessages('conv_1'), isEmpty);
      },
    );

    test('persists proactive Pulse Drops and hides dismissed ones', () async {
      await repo.upsertDrop(
        AskProactiveDrop(
          id: 'drop_1',
          kind: 'heavy_rotation',
          title: 'Settimana Radiohead',
          body: '45 minuti negli ultimi 3 giorni.',
          starterPrompt: 'Trovami brani simili a Radiohead',
          seedId: 'UC_RH',
          createdAt: DateTime(2026, 11, 21),
        ),
      );

      var active = await repo.getActiveDrops();
      expect(active, hasLength(1));
      expect(active.single.isRead, isFalse);

      await repo.markDropRead('drop_1');
      active = await repo.getActiveDrops();
      expect(active.single.isRead, isTrue);

      await repo.dismissDrop('drop_1');
      expect(await repo.getActiveDrops(), isEmpty);
    });

    test(
      'migrates existing schema v26 database to v27 creating Ask tables',
      () async {
        final upgraded = AppDatabase(
          NativeDatabase.memory(
            setup: (rawDb) {
              rawDb.execute('PRAGMA user_version = 26;');
              rawDb.execute(
                'CREATE TABLE search_history (id INTEGER PRIMARY KEY AUTOINCREMENT, query TEXT NOT NULL, searched_at INTEGER NOT NULL, query_key TEXT);',
              );
            },
          ),
        );
        addTearDown(upgraded.close);

        final upgradedRepo = AskStorageRepositoryImpl(upgraded);
        await upgradedRepo.upsertConversation(
          AskConversationSummary(
            id: 'migrated_1',
            title: 'Post-upgrade',
            createdAt: DateTime(2026, 11, 21),
            updatedAt: DateTime(2026, 11, 21),
          ),
        );
        final convs = await upgradedRepo.getConversations();
        expect(convs, hasLength(1));
        expect(convs.single.id, 'migrated_1');
      },
    );
  });
}
