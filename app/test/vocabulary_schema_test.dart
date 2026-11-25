import 'package:flutter_test/flutter_test.dart';
import 'package:linguaflow/constants/app_constants.dart';
import 'package:linguaflow/data/schema.dart';
import 'package:linguaflow/models/vocabulary.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('词汇表 schema v3 — seed_words / vocab_cards / seed_meta', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      for (final stmt in kSchemaStatements) {
        await db.execute(stmt);
      }
    });

    tearDown(() async => db.close());

    SeedWord seedWord() => SeedWord(
          id: 'w_refactor',
          word: 'refactor',
          phonetics: '/riːˈfæktər/',
          partOfSpeech: 'verb',
          meaningCn: '重构。在不改变外部行为的前提下改善代码结构。',
          example: 'We need to refactor this component.',
          exampleCn: '我们需要重构这个组件。',
          cefr: 'B2',
          difficulty: 3,
          tags: const ['tech', 'frontend'],
          grammarTags: const ['tense:past_simple'],
          createdAt: DateTime(2026, 1, 1),
        );

    VocabCard vocabCard(String id, String word) => VocabCard(
          id: id,
          userId: kLocalUserId,
          word: word,
          phonetics: null,
          partOfSpeech: 'verb',
          meaningCn: '部署。把应用发布到服务器。',
          example: 'We deploy to production every Friday.',
          exampleCn: '我们每周五部署到生产环境。',
          cefr: 'B1',
          difficulty: 2,
          tags: const ['tech', 'workplace'],
          source: 'ai',
          createdAt: DateTime(2026, 1, 2),
          updatedAt: DateTime(2026, 1, 2),
        );

    test('建表 + 模型往返（两表同构字段不丢失）', () async {
      await db.insert('seed_words', seedWord().toMap());
      await db.insert('vocab_cards', vocabCard(generateUserVocabId(), 'deploy').toMap());

      final seedRow =
          (await db.query('seed_words')).map(SeedWord.fromMap).first;
      expect(seedRow.id, 'w_refactor');
      expect(seedRow.tags, ['tech', 'frontend']);
      expect(seedRow.grammarTags, ['tense:past_simple']);
      expect(seedRow.active, isTrue);
      expect(seedRow.cefr, 'B2');

      final cardRow = (await db.query('vocab_cards')).map(VocabCard.fromMap).first;
      expect(cardRow.id, startsWith(kUserVocabIdPrefix));
      expect(cardRow.source, 'ai');
      expect(cardRow.userId, kLocalUserId);
    });

    test('seed_words.word 唯一约束生效', () async {
      await db.insert('seed_words', seedWord().toMap());
      // 同 word 不同 id，INSERT 冲突
      final conflict = seedWord().copyWithId('w_refactor_2');
      expect(() => db.insert('seed_words', conflict.toMap()),
          throwsA(isA<Exception>()));
    });

    test('vocab_cards UNIQUE(user_id, word) 防重复生成', () async {
      await db.insert('vocab_cards', vocabCard('uv_1', 'deploy').toMap());
      // 同 user 同 word 不同 id → 违反唯一约束
      expect(() => db.insert('vocab_cards', vocabCard('uv_2', 'deploy').toMap()),
          throwsA(isA<Exception>()));
      // 不同 word 不冲突
      await db.insert('vocab_cards', vocabCard('uv_3', 'rollback').toMap());
      expect(await db.query('vocab_cards'), hasLength(2));
    });

    test('VocabEntry 统一消费：seed 与 user 卡字段访问一致', () {
      final entry1 = VocabEntry.fromSeed(seedWord());
      final entry2 = VocabEntry.fromCard(vocabCard('uv_1', 'deploy'));

      expect(entry1.isSeed, isTrue);
      expect(entry2.isSeed, isFalse);
      expect(entry1.word, 'refactor');
      expect(entry2.word, 'deploy');
      expect(entry1.cefr, 'B2');
      expect(entry2.cefr, 'B1');
    });

    test('id 前缀约定：w_ / uv_ 生成符合规范', () {
      expect(generateUserVocabId(), startsWith('uv_'));
      expect(kSeedWordIdPrefix, 'w_');
      // 两次生成不同 id（防 SRS 卡片误判为同一张）
      expect(generateUserVocabId(), isNot(equals(generateUserVocabId())));
    });

    test('DDL 幂等重放（模拟 v3 升级时 onUpgrade 重放）', () async {
      await db.insert('seed_words', seedWord().toMap());
      // 重放全部建表语句（onUpgrade 路径）
      for (final stmt in kSchemaStatements) {
        await db.execute(stmt);
      }
      expect(await db.query('seed_words'), hasLength(1));
    });
  });
}

extension on SeedWord {
  SeedWord copyWithId(String newId) => SeedWord(
        id: newId,
        word: word,
        phonetics: phonetics,
        partOfSpeech: partOfSpeech,
        meaningCn: meaningCn,
        example: example,
        exampleCn: exampleCn,
        cefr: cefr,
        difficulty: difficulty,
        tags: tags,
        grammarTags: grammarTags,
        active: active,
        createdAt: createdAt,
      );
}
