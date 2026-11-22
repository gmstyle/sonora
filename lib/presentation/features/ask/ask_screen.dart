import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/layout_breakpoints.dart';
import '../../../domain/models/ask_chat_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/action_feedback_provider.dart';
import '../../providers/ask_llm_provider.dart';
import '../../providers/ask_storage_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../shared/widgets/feedback_toast.dart';
import 'providers/ask_chat_provider.dart';
import 'widgets/ask_composer.dart';
import 'widgets/ask_drops_section.dart';
import 'widgets/ask_follow_up_chips.dart';
import 'widgets/ask_guided_actions.dart';
import 'widgets/ask_guided_sheets.dart';
import 'widgets/ask_rich_cards.dart';

class AskScreen extends ConsumerStatefulWidget {
  const AskScreen({super.key, this.initialPrompt, this.initialDropId});

  final String? initialPrompt;
  final String? initialDropId;

  @override
  ConsumerState<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends ConsumerState<AskScreen> {
  final TextEditingController _composerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _lastHandledPrompt;
  String? _lastHandledDropId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(askQuotaProvider.notifier).refresh());
      unawaited(_consumeInitialArgs());
    });
  }

  @override
  void didUpdateWidget(covariant AskScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPrompt != widget.initialPrompt ||
        oldWidget.initialDropId != widget.initialDropId) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _consumeInitialArgs(),
      );
    }
  }

  Future<void> _consumeInitialArgs() async {
    if (!mounted) return;
    final locale = Localizations.localeOf(context).languageCode;

    final dropId = widget.initialDropId?.trim();
    if (dropId != null && dropId.isNotEmpty && dropId != _lastHandledDropId) {
      _lastHandledDropId = dropId;
      final drops = await ref
          .read(askStorageRepositoryProvider)
          .getActiveDrops();
      final match = drops.cast<AskProactiveDrop?>().firstWhere(
        (d) => d?.id == dropId,
        orElse: () => null,
      );
      if (match != null && mounted) {
        await ref
            .read(askChatProvider.notifier)
            .openDrop(match, locale: locale);
      }
      return;
    }

    final prompt = widget.initialPrompt?.trim();
    if (prompt == null || prompt.isEmpty) {
      _lastHandledPrompt = null;
      return;
    }
    if (prompt != _lastHandledPrompt) {
      _lastHandledPrompt = prompt;
      if (ref.read(isOfflineProvider)) {
        _composerController.text = prompt;
        return;
      }
      ref.read(askChatProvider.notifier).startNewConversation();
      _composerController.clear();
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        final uri = router.routerDelegate.currentConfiguration.uri;
        if (uri.path == '/ask' && uri.queryParameters.isNotEmpty) {
          router.go('/ask');
        }
      }
      await _sendPrompt(prompt);
    }
  }

  @override
  void dispose() {
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendPrompt([String? overrideText]) async {
    final text = (overrideText ?? _composerController.text).trim();
    if (text.isEmpty) return;
    if (overrideText == null) {
      _composerController.clear();
    }
    final locale = Localizations.localeOf(context).languageCode;
    await ref.read(askChatProvider.notifier).sendMessage(text, locale: locale);
    if (mounted) _scrollToBottom();
  }

  Future<void> _retryLastFailed() async {
    final locale = Localizations.localeOf(context).languageCode;
    await ref.read(askChatProvider.notifier).retryLastFailed(locale: locale);
    if (mounted) _scrollToBottom();
  }

  void _reportErrorBanner(AskChatState chatState) {
    final kind = chatState.errorKind;
    if (kind == null) return;
    final l10n = AppLocalizations.of(context)!;
    final limit = ref.read(askQuotaProvider).limit;
    final text = switch (kind) {
      AskUiErrorKind.offline => l10n.askErrorOffline,
      AskUiErrorKind.notConfigured => l10n.askErrorNotConfigured,
      AskUiErrorKind.quotaExceeded => l10n.askErrorQuotaExceeded(
        limit <= 0 ? 30 : limit,
      ),
      AskUiErrorKind.failed => l10n.askErrorFailed,
    };
    final showSettings =
        kind == AskUiErrorKind.notConfigured ||
        kind == AskUiErrorKind.quotaExceeded;
    final canRetry = !ref.read(isOfflineProvider) && chatState.canRetry;
    final String? actionLabel;
    final VoidCallback? onAction;
    if (showSettings) {
      actionLabel = l10n.askOpenSettings;
      onAction = () {
        ref.read(askChatProvider.notifier).clearError();
        if (mounted) context.push('/settings?section=ai');
      };
    } else if (canRetry) {
      actionLabel = l10n.askActionRetry;
      onAction = () => unawaited(_retryLastFailed());
    } else {
      actionLabel = null;
      onAction = null;
    }

    ref
        .read(actionFeedbackProvider.notifier)
        .report(
          text,
          kind: FeedbackKind.error,
          actionLabel: actionLabel,
          onAction: onAction,
          onDismiss: () {
            if (mounted) ref.read(askChatProvider.notifier).clearError();
          },
        );
  }

  Future<void> _openMixBuilder() async {
    final prompt = await showAskTailoredMixSheet(context);
    if (!mounted || prompt == null || prompt.trim().isEmpty) return;
    await _sendPrompt(prompt);
  }

  Future<void> _openExpandPlaylist() async {
    final prompt = await showAskExpandPlaylistSheet(context);
    if (!mounted || prompt == null || prompt.trim().isEmpty) return;
    await _sendPrompt(prompt);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);
    final isCompact = isCompactShell(size);
    final isWide = !isCompact && size.width >= kExpandedBreakpoint;
    final showUtility = size.width >= kWideContentBreakpoint;

    ref.listen<AskChatState>(askChatProvider, (prev, next) {
      if (prev?.isSending != next.isSending ||
          prev?.activeConversationId != next.activeConversationId) {
        _scrollToBottom();
      }
      if (next.errorKind != null && prev?.errorKind != next.errorKind) {
        _reportErrorBanner(next);
      } else if (prev?.errorKind != null && next.errorKind == null) {
        FeedbackToast.dismissSticky();
      }
    });

    final chatState = ref.watch(askChatProvider);
    final isOffline = ref.watch(isOfflineProvider);
    final caps = ref.watch(askCapabilitiesProvider).asData?.value;
    final quota = ref.watch(askQuotaProvider);
    final canUseAsk = !isOffline && (caps?.canUseAsk ?? false);
    final locale = Localizations.localeOf(context).languageCode;

    final chatColumn = Column(
      children: [
        Expanded(
          child: _AskConversationBody(
            conversationId: chatState.activeConversationId,
            scrollController: _scrollController,
            isSending: chatState.isSending,
            progressPhase: chatState.progressPhase,
            canUseAsk: canUseAsk,
            showDropsAndActionsInBody: isCompact || !showUtility,
            onSelectPrompt: (prompt) => _sendPrompt(prompt),
            onOpenMixBuilder: _openMixBuilder,
            onOpenExpandPlaylist: _openExpandPlaylist,
            onOpenDrop: (drop) => ref
                .read(askChatProvider.notifier)
                .openDrop(drop, locale: locale),
          ),
        ),
        AskComposer(
          controller: _composerController,
          enabled: canUseAsk,
          isSending: chatState.isSending,
          enableWebSearch: chatState.enableWebSearch,
          onToggleWebSearch: () =>
              ref.read(askChatProvider.notifier).toggleWebSearch(),
          onSubmit: () => _sendPrompt(),
          onStop: () =>
              ref.read(askChatProvider.notifier).cancelActiveRequest(),
        ),
      ],
    );

    if (isCompact) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.askHubTitle),
          actions: [
            _QuotaBadge(quota: quota),
            IconButton(
              tooltip: l10n.askHistoryTitle,
              icon: const Icon(LucideIcons.history),
              onPressed: () => _showHistorySheet(context),
            ),
            IconButton(
              tooltip: l10n.askNewChat,
              icon: const Icon(LucideIcons.plus),
              onPressed: () =>
                  ref.read(askChatProvider.notifier).startNewConversation(),
            ),
          ],
        ),
        body: chatColumn,
      );
    }

    final leftRail = _AskSidebarRail(
      canUseAsk: canUseAsk,
      onSelectPrompt: (p) => _sendPrompt(p),
      onOpenMixBuilder: _openMixBuilder,
      onOpenExpandPlaylist: _openExpandPlaylist,
    );

    if (!isWide) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.askHubTitle),
          actions: [
            _QuotaBadge(quota: quota),
            IconButton(
              tooltip: l10n.settingsLabel,
              icon: const Icon(LucideIcons.settings),
              onPressed: () => context.push('/settings?section=ai'),
            ),
          ],
        ),
        body: Row(
          children: [
            SizedBox(width: 240, child: leftRail),
            VerticalDivider(
              width: 1,
              color: Theme.of(context).colorScheme.outlineVariant
                  .withValues(alpha: 0.4),
            ),
            Expanded(child: chatColumn),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.askHubTitle),
        actions: [
          _QuotaBadge(quota: quota),
          const SizedBox(width: 8),
          IconButton(
            tooltip: l10n.settingsLabel,
            icon: const Icon(LucideIcons.settings),
            onPressed: () => context.push('/settings?section=ai'),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: kFacetFilterRailWidth, child: leftRail),
          VerticalDivider(
            width: 1,
            color: Theme.of(context).colorScheme.outlineVariant
                .withValues(alpha: 0.4),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: kWideContentPadding,
              ),
              child: chatColumn,
            ),
          ),
          if (showUtility) ...[
            VerticalDivider(
              width: 1,
              color: Theme.of(context).colorScheme.outlineVariant
                  .withValues(alpha: 0.4),
            ),
            SizedBox(
              width: kFacetUtilityRailWidth,
              child: ListView(
                children: [
                  AskDropsSection(
                    vertical: true,
                    enabled: canUseAsk,
                    onOpenDrop: (drop) => ref
                        .read(askChatProvider.notifier)
                        .openDrop(drop, locale: locale),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showHistorySheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Consumer(
        builder: (ctx, sheetRef, _) {
          final convs =
              sheetRef.watch(askConversationsProvider).asData?.value ??
              const [];
          final activeId = sheetRef.watch(askChatProvider).activeConversationId;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.askHistoryTitle,
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                      ),
                      if (convs.isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(LucideIcons.trash2, size: 16),
                          label: Text(l10n.askClearHistory),
                          onPressed: () => unawaited(
                            _confirmAndClearHistory(
                              ctx,
                              sheetRef,
                              popCaller: true,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (convs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.askHistoryEmpty),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: convs.length,
                      itemBuilder: (ctx, i) {
                        final conv = convs[i];
                        return ListTile(
                          selected: conv.id == activeId,
                          leading: const Icon(LucideIcons.sparkles, size: 18),
                          title: Text(
                            conv.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(LucideIcons.trash2, size: 16),
                            onPressed: () => sheetRef
                                .read(askChatProvider.notifier)
                                .deleteConversation(conv.id),
                          ),
                          onTap: () {
                            sheetRef
                                .read(askChatProvider.notifier)
                                .selectConversation(conv.id);
                            Navigator.of(ctx).pop();
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AskSidebarRail extends ConsumerWidget {
  const _AskSidebarRail({
    required this.canUseAsk,
    required this.onSelectPrompt,
    required this.onOpenMixBuilder,
    required this.onOpenExpandPlaylist,
  });

  final bool canUseAsk;
  final ValueChanged<String> onSelectPrompt;
  final VoidCallback onOpenMixBuilder;
  final VoidCallback onOpenExpandPlaylist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final convs = ref.watch(askConversationsProvider).asData?.value ?? const [];
    final activeId = ref.watch(askChatProvider).activeConversationId;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      children: [
        FilledButton.tonalIcon(
          onPressed: () =>
              ref.read(askChatProvider.notifier).startNewConversation(),
          icon: const Icon(LucideIcons.plus, size: 18),
          label: Text(l10n.askNewChat),
        ),
        AskGuidedActions(
          verticalList: true,
          enabled: canUseAsk,
          onSelectPrompt: onSelectPrompt,
          onOpenMixBuilder: onOpenMixBuilder,
          onOpenExpandPlaylist: onOpenExpandPlaylist,
        ),
        const Divider(height: 24),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 8, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.askHistoryTitle,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (convs.isNotEmpty)
                IconButton(
                  tooltip: l10n.askClearHistory,
                  icon: const Icon(LucideIcons.trash2, size: 15),
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      unawaited(_confirmAndClearHistory(context, ref)),
                ),
            ],
          ),
        ),
        if (convs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(
              l10n.askHistoryEmpty,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          )
        else
          for (final conv in convs)
            ListTile(
              dense: true,
              selected: conv.id == activeId,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(
                conv.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: l10n.askDeleteChat,
                icon: const Icon(LucideIcons.x, size: 14),
                visualDensity: VisualDensity.compact,
                onPressed: () => ref
                    .read(askChatProvider.notifier)
                    .deleteConversation(conv.id),
              ),
              onTap: () => ref
                  .read(askChatProvider.notifier)
                  .selectConversation(conv.id),
            ),
      ],
    );
  }
}

class _AskConversationBody extends ConsumerWidget {
  const _AskConversationBody({
    required this.conversationId,
    required this.scrollController,
    required this.isSending,
    required this.progressPhase,
    required this.canUseAsk,
    required this.showDropsAndActionsInBody,
    required this.onSelectPrompt,
    required this.onOpenMixBuilder,
    required this.onOpenExpandPlaylist,
    required this.onOpenDrop,
  });

  final String? conversationId;
  final ScrollController scrollController;
  final bool isSending;
  final AskProgressPhase? progressPhase;
  final bool canUseAsk;
  final bool showDropsAndActionsInBody;
  final ValueChanged<String> onSelectPrompt;
  final VoidCallback onOpenMixBuilder;
  final VoidCallback onOpenExpandPlaylist;
  final ValueChanged<AskProactiveDrop> onOpenDrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (conversationId == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        children: [
          Card(
            elevation: 0,
            color: cs.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.sparkles, color: cs.primary, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.askWelcomeTitle,
                          style: tt.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.askHubSubtitle,
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  AskGuidedActions(
                    enabled: canUseAsk,
                    onSelectPrompt: onSelectPrompt,
                    onOpenMixBuilder: onOpenMixBuilder,
                    onOpenExpandPlaylist: onOpenExpandPlaylist,
                  ),
                ],
              ),
            ),
          ),
          if (showDropsAndActionsInBody) ...[
            const SizedBox(height: 16),
            AskDropsSection(enabled: canUseAsk, onOpenDrop: onOpenDrop),
          ],
        ],
      );
    }

    final messagesAsync = ref.watch(askMessagesProvider(conversationId!));
    return messagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.askErrorFailed)),
      data: (messages) {
        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          itemCount: messages.length + (isSending ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= messages.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _progressLabelFor(progressPhase, l10n),
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            final message = messages[index];
            final showFollowUps =
                !isSending && index == messages.length - 1 && !message.isUser;
            return _MessageBubble(
              message: message,
              showFollowUps: showFollowUps,
              followUpsEnabled: canUseAsk && !isSending,
              onSelectFollowUp: onSelectPrompt,
            );
          },
        );
      },
    );
  }
}

String _progressLabelFor(AskProgressPhase? phase, AppLocalizations l10n) =>
    switch (phase) {
      AskProgressPhase.readingProfile => l10n.askProgressReadingProfile,
      AskProgressPhase.readingPlaylist => l10n.askProgressReadingPlaylist,
      AskProgressPhase.searchingCatalog => l10n.askProgressSearchingCatalog,
      AskProgressPhase.exploringSimilar => l10n.askProgressExploringSimilar,
      AskProgressPhase.buildingProposal => l10n.askProgressBuildingProposal,
      AskProgressPhase.finalizing => l10n.askProgressFinalizing,
      AskProgressPhase.thinking || null => l10n.askThinkingStatus,
    };

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.showFollowUps = false,
    this.followUpsEnabled = false,
    this.onSelectFollowUp,
  });

  final AskChatMessage message;
  final bool showFollowUps;
  final bool followUpsEnabled;
  final ValueChanged<String>? onSelectFollowUp;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            message.content,
            style: tt.bodyMedium?.copyWith(color: cs.onPrimaryContainer),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.content.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SelectionArea(
                    child: GptMarkdown(
                      message.content,
                      isStreaming: false,
                      useDollarSignsForLatex: false,
                      followLinkColor: true,
                      style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                      styleSheet: GptMarkdownStyleSheet(
                        link: LinkStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        heading: const HeadingStyle(
                          textStyle: TextStyle(fontWeight: FontWeight.w700),
                          showDivider: false,
                        ),
                        blockQuote: BlockQuoteStyle(
                          barWidth: 3,
                          barColor: cs.primary,
                          barRadius: const Radius.circular(2),
                          backgroundColor: cs.surfaceContainerHighest
                              .withValues(alpha: 0.45),
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            12,
                            6,
                            10,
                            6,
                          ),
                        ),
                      ),
                      onLinkTap: (url, _) => unawaited(_openMarkdownLink(url)),
                    ),
                  ),
                ),
              AskRichAttachments(message: message),
              if (showFollowUps && onSelectFollowUp != null)
                AskFollowUpChips(
                  message: message,
                  enabled: followUpsEnabled,
                  onSelectPrompt: onSelectFollowUp!,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMarkdownLink(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Failed to launch markdown link ($rawUrl): $e');
    }
  }
}

class _QuotaBadge extends StatelessWidget {
  const _QuotaBadge({required this.quota});

  final AskQuotaInfo quota;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = quota.isUnlimited
        ? l10n.askByokBadge
        : l10n.askQuotaBadge(
            quota.remaining < 0 ? 0 : quota.remaining,
            quota.limit <= 0 ? 30 : quota.limit,
          );
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Chip(label: Text(label), visualDensity: VisualDensity.compact),
    );
  }
}

Future<void> _confirmAndClearHistory(
  BuildContext context,
  WidgetRef ref, {
  bool popCaller = false,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final cs = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(l10n.askClearHistoryConfirmTitle),
      content: Text(l10n.askClearHistoryConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ),
          onPressed: () => Navigator.of(dialogCtx).pop(true),
          child: Text(l10n.askClearHistory),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await ref.read(askChatProvider.notifier).clearAllConversations();
  if (popCaller && context.mounted) {
    Navigator.of(context).pop();
  }
}
