import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';

/// Campo de busca reutilizável (Material 3); debounce fica no [Notifier].
class TechniqueSearchBar extends StatefulWidget {
  const TechniqueSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  State<TechniqueSearchBar> createState() => _TechniqueSearchBarState();
}

class _TechniqueSearchBarState extends State<TechniqueSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(covariant TechniqueSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  void _onText() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF2B2D42) : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: TextField(
        controller: widget.controller,
        onChanged: widget.onChanged,
        style: TextStyle(
          color: isDark ? Colors.white : AppTheme.textPrimary,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Buscar por nome da técnica',
          hintStyle: TextStyle(
            color: isDark ? Colors.white54 : AppTheme.textSecondary,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: isDark ? Colors.white70 : AppTheme.textSecondary,
          ),
          suffixIcon: widget.controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onClear?.call();
                  },
                ),
        ),
      ),
    );
  }
}
