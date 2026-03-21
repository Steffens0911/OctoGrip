import 'package:flutter/material.dart';

import 'package:viewer/models/training_video.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/utils/youtube_utils.dart';

class TrainingVideoFormScreen extends StatefulWidget {
  final TrainingVideo? video;

  const TrainingVideoFormScreen({super.key, this.video});

  @override
  State<TrainingVideoFormScreen> createState() =>
      _TrainingVideoFormScreenState();
}

class _TrainingVideoFormScreenState extends State<TrainingVideoFormScreen> {
  final _api = ApiService();
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController(text: '1');
  final _durationCtrl = TextEditingController();
  bool _isActive = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final v = widget.video;
    if (v != null) {
      _titleCtrl.text = v.title;
      _urlCtrl.text = v.youtubeUrl;
      _pointsCtrl.text = v.pointsPerDay.toString();
      if (v.durationSeconds != null && v.durationSeconds! > 0) {
        _durationCtrl.text = v.durationSeconds.toString();
      }
      _isActive = v.isActive;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    _pointsCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final url = _urlCtrl.text.trim();
    final points = int.tryParse(_pointsCtrl.text.trim());
    final durationSeconds = int.tryParse(_durationCtrl.text.trim());

    if (title.isEmpty) {
      setState(() => _error = 'Informe um título para o vídeo.');
      return;
    }
    if (url.isEmpty || !isYouTubeUrl(url)) {
      setState(
        () => _error =
            'Informe um link válido do YouTube (watch, shorts, embed ou youtu.be).',
      );
      return;
    }
    if (points == null || points <= 0) {
      setState(() => _error = 'Informe pontos por dia maior que zero.');
      return;
    }
    if (durationSeconds != null && durationSeconds <= 0) {
      setState(() => _error = 'Duração (segundos) deve ser maior que zero.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (widget.video == null) {
        await _api.createTrainingVideo(
          title: title,
          youtubeUrl: url,
          pointsPerDay: points,
          isActive: _isActive,
          durationSeconds: durationSeconds,
        );
      } else {
        await _api.updateTrainingVideo(
          id: widget.video!.id,
          title: title,
          youtubeUrl: url,
          pointsPerDay: points,
          isActive: _isActive,
          durationSeconds: durationSeconds,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vídeo de treinamento salvo.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = userFacingMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.video == null
              ? 'Novo vídeo de treinamento'
              : 'Editar vídeo de treinamento',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Título',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Link do YouTube',
                hintText: 'https://www.youtube.com/watch?v=...',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pointsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Pontos por dia',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _durationCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duração (segundos) – opcional',
                helperText:
                    'Usado como fallback para liberar o botão após ~95% do tempo.',
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _isActive,
              title: const Text('Ativo'),
              subtitle:
                  const Text('Vídeos inativos não aparecem para os alunos'),
              onChanged: (v) => setState(() => _isActive = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
