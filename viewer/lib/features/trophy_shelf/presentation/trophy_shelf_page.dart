import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/features/trophy_shelf/domain/shelf_trophy.dart';
import 'package:viewer/features/trophy_shelf/utils/shelf_layout_config.dart';
import 'package:viewer/features/trophy_shelf/presentation/widgets/trophy_detail_modal.dart';
import 'package:viewer/features/trophy_shelf/presentation/widgets/trophy_shelf_layout.dart';
import 'package:viewer/models/trophy.dart';
import 'package:viewer/services/api_service.dart' show ApiException, ApiService;
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';

/// Página principal da estante: fundo, loading/erro, orquestra shelf e modal.
/// Recebe [userId], [userName] e [trophies] (ou carrega via API quando null).
class TrophyShelfPage extends StatefulWidget {
  final String userId;
  final String? userName;
  final List<TrophyWithEarned>? trophies;

  const TrophyShelfPage({
    super.key,
    required this.userId,
    this.userName,
    this.trophies,
  });

  @override
  State<TrophyShelfPage> createState() => _TrophyShelfPageState();
}

class _TrophyShelfPageState extends State<TrophyShelfPage> {
  final _api = ApiService();
  List<TrophyWithEarned>? _list;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.trophies != null) {
      _list = widget.trophies;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.getTrophiesForUser(widget.userId);
      if (mounted) {
        setState(() {
          _list = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException && e.statusCode == 403
            ? 'Esta galeria está privada.'
            : userFacingMessage(e);
        setState(() {
          _error = msg;
          _loading = false;
        });
      }
    }
  }

  void _onTrophyTap(ShelfTrophy st) {
    final isOwnGallery = AuthService().currentUser?.id == widget.userId;
    final galleryOwnerName = isOwnGallery ? null : (widget.userName ?? '');
    TrophyDetailModal.show(context, st, galleryOwnerName: galleryOwnerName);
  }

  /// Lista mock para desenvolvimento quando [trophies] é passado explicitamente para testes.
  static List<TrophyWithEarned> get mockTrophies {
    return [
      TrophyWithEarned(
        trophyId: 'mock-1',
        techniqueId: 't1',
        name: 'Troféu Ouro',
        techniqueName: 'Técnica A',
        startDate: '2024-01-01',
        endDate: '2024-12-31',
        targetCount: 10,
        awardKind: 'trophy',
        earnedTier: 'gold',
        goldCount: 10,
        silverCount: 8,
        bronzeCount: 5,
      ),
      TrophyWithEarned(
        trophyId: 'mock-2',
        techniqueId: 't2',
        name: 'Medalha Prata',
        techniqueName: 'Técnica B',
        startDate: '2024-06-01',
        endDate: '2024-11-30',
        targetCount: 5,
        awardKind: 'medal',
        earnedTier: 'silver',
        goldCount: 0,
        silverCount: 5,
        bronzeCount: 4,
      ),
      TrophyWithEarned(
        trophyId: 'mock-3',
        techniqueId: 't3',
        name: 'A conquistar',
        techniqueName: 'Técnica C',
        startDate: '2024-09-01',
        endDate: '2025-02-28',
        targetCount: 8,
        awardKind: 'trophy',
        earnedTier: null,
        goldCount: 0,
        silverCount: 0,
        bronzeCount: 2,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Container(
          color: const Color(0xFF2D1810),
          child: const Center(child: CircularProgressIndicator(color: Colors.amber)),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Container(
          color: const Color(0xFF2D1810),
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _error == 'Esta galeria está privada.'
                        ? Colors.white70
                        : Colors.red.shade200,
                  ),
                ),
                if (_error != 'Esta galeria está privada') ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _load,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final list = _list ?? [];
    final config = ShelfLayoutConfig.fromWidth(MediaQuery.sizeOf(context).width);
    final shelfTrophies = ShelfTrophy.fromTrophies(
      list,
      slotsPerRow: config.slotsPerRow,
      rowCount: config.rowCount,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Estante de troféus'),
            if (widget.userName != null && widget.userName!.isNotEmpty)
              Text(
                widget.userName!,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: const Color(0xFF2D1810),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: list.isEmpty
            ? Container(
                color: const Color(0xFF2D1810),
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Nenhum troféu nesta galeria.',
                    style: TextStyle(color: AppTheme.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : TrophyShelfLayout(
                shelfTrophies: shelfTrophies,
                config: config,
                onTrophyTap: _onTrophyTap,
              ),
      ),
    );
  }
}
