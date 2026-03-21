import 'package:viewer/features/techniques/data/models/technique_dto.dart';
import 'package:viewer/services/api_service.dart';

/// Fonte remota: delega ao [ApiService] existente (sem duplicar HTTP).
abstract class TechniqueRemoteDataSource {
  Future<List<TechniqueDto>> fetchAll(String academyId);
  Future<TechniqueDto> create({
    required String academyId,
    required String name,
    String? slug,
    String? description,
    String? videoUrl,
  });
  Future<TechniqueDto> update({
    required String academyId,
    required String id,
    String? name,
    String? slug,
    String? description,
    String? videoUrl,
  });
  Future<void> delete({required String academyId, required String id});
}

class TechniqueRemoteDataSourceImpl implements TechniqueRemoteDataSource {
  TechniqueRemoteDataSourceImpl(this._api);

  final ApiService _api;

  @override
  Future<List<TechniqueDto>> fetchAll(String academyId) async {
    final list = await _api.getTechniques(
      academyId: academyId,
      cacheBust: true,
    );
    return list
        .map(
          (t) => TechniqueDto(
            id: t.id,
            academyId: academyId,
            name: t.name,
            slug: t.slug,
            description: t.description,
            videoUrl: t.videoUrl,
          ),
        )
        .toList();
  }

  @override
  Future<TechniqueDto> create({
    required String academyId,
    required String name,
    String? slug,
    String? description,
    String? videoUrl,
  }) async {
    final t = await _api.createTechnique(
      academyId: academyId,
      name: name,
      slug: slug,
      description: description,
      videoUrl: videoUrl,
    );
    return TechniqueDto(
      id: t.id,
      academyId: academyId,
      name: t.name,
      slug: t.slug,
      description: t.description,
      videoUrl: t.videoUrl,
    );
  }

  @override
  Future<TechniqueDto> update({
    required String academyId,
    required String id,
    String? name,
    String? slug,
    String? description,
    String? videoUrl,
  }) async {
    final t = await _api.updateTechnique(
      id,
      academyId: academyId,
      name: name,
      slug: slug,
      description: description,
      videoUrl: videoUrl,
    );
    return TechniqueDto(
      id: t.id,
      academyId: academyId,
      name: t.name,
      slug: t.slug,
      description: t.description,
      videoUrl: t.videoUrl,
    );
  }

  @override
  Future<void> delete({required String academyId, required String id}) {
    return _api.deleteTechnique(id, academyId: academyId);
  }
}
