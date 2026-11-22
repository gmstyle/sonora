import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';

class AskComposer extends StatelessWidget {
  const AskComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.isSending,
    required this.enableWebSearch,
    required this.onToggleWebSearch,
    required this.onSubmit,
    this.onStop,
    this.focusNode,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool isSending;
  final bool enableWebSearch;
  final VoidCallback onToggleWebSearch;
  final VoidCallback onSubmit;
  final VoidCallback? onStop;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Material(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      enabled: enabled && !isSending,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (enabled && !isSending) onSubmit();
                      },
                      decoration: InputDecoration(
                        hintText: l10n.askComposerHint,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (isSending && onStop != null)
                    Tooltip(
                      message: l10n.askStop,
                      child: FilledButton.tonal(
                        onPressed: onStop,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(42, 42),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Icon(LucideIcons.circleStop, size: 18),
                      ),
                    )
                  else
                    FilledButton(
                      onPressed: enabled && !isSending ? onSubmit : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(42, 42),
                        padding: EdgeInsets.zero,
                      ),
                      child: isSending
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.onPrimary,
                              ),
                            )
                          : const Icon(LucideIcons.arrowUp, size: 18),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              FilterChip(
                selected: enableWebSearch,
                onSelected: enabled && !isSending
                    ? (_) => onToggleWebSearch()
                    : null,
                avatar: Icon(
                  LucideIcons.globe,
                  size: 14,
                  color: enableWebSearch ? cs.primary : cs.onSurfaceVariant,
                ),
                label: Text(l10n.askWebSearchChip),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
