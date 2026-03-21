import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

import 'package:viewer/features/techniques/data/models/technique_dto.dart';
import 'package:viewer/features/techniques/domain/failures/technique_failure.dart';

/// Persistência local com Hive (funciona em mobile e web).
/// Uma única box com chave por [academyId] para listas serializadas em JSON.
abstract class TechniqueLocalDataSource {
  Future<List<TechniqueDto>?> read(String academyId);
  Future<void> write(String academyId, List<TechniqueDto> items);
  Future<void> clear(String academyId);
}

class TechniqueLocalDataSourceImpl implements TechniqueLocalDataSource {
  TechniqueLocalDataSourceImpl({Box<String>? boxOverride})
      : _boxOverride = boxOverride;

  static const String _boxName = 'techniques_module_v1';
  final Logger _log = Logger('TechniqueLocalDataSource');
  final Box<String>? _boxOverride;

  Future<Box<String>> get _box async {
    if (_boxOverride != null) return _boxOverride!;
    if (!Hive.isBoxOpen(_boxName)) {
      return Hive.openBox<String>(_boxName);
    }
    return Hive.box<String>(_boxName);
  }

  String _key(String academyId) => 'academy_$academyId';

  @override
  Future<List<TechniqueDto>?> read(String academyId) async {
    try {
      final box = await _box;
      final raw = box.get(_key(academyId));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => TechniqueDto.fromHiveMap(e as Map<dynamic, dynamic>))
          .toList();
    } catch (e, st) {
      _log.warning('read cache failed', e, st);
      throw const CacheTechniqueFailure('Não foi possível ler o cache local.');
    }
  }

  @override
  Future<void> write(String academyId, List<TechniqueDto> items) async {
    try {
      final box = await _box;
      final encoded = jsonEncode(items.map((e) => e.toHiveMap()).toList());
      await box.put(_key(academyId), encoded);
    } catch (e, st) {
      _log.warning('write cache failed', e, st);
      throw const CacheTechniqueFailure('Não foi possível gravar o cache local.');
    }
  }

  @override
  Future<void> clear(String academyId) async {
    final box = await _box;
    await box.delete(_key(academyId));
  }
}
