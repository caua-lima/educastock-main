import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../donations/presentation/widgets/donor_header.dart';
import '../../domain/assistant_prompt.dart';
import '../../domain/chat_message.dart';
import '../controllers/chat_controller.dart';

/// Tela do assistente virtual (Gemini): histórico em `ListView.builder` e campo de
/// texto no rodapé. Mensagens do doador alinhadas à direita em balões azuis; as do
/// assistente à esquerda em balões cinza.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? preset]) async {
    final text = preset ?? _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    final future = ref.read(chatControllerProvider.notifier).send(text);
    _scrollToEnd();
    await future;
    _scrollToEnd();
    if (mounted) _focus.requestFocus();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.donorHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chat = ref.watch(chatControllerProvider);
    final itemCount = chat.messages.length + (chat.sending ? 1 : 0);

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          DonorHeader(
            title: 'Assistente EducaStock',
            subtitle: 'Tire dúvidas sobre sua doação',
            onBack: _back,
            actions: [
              IconButton(
                tooltip: 'Nova conversa',
                onPressed: chat.isFresh
                    ? null
                    : () => ref.read(chatControllerProvider.notifier).reset(),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: itemCount + (chat.isFresh && !chat.sending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < chat.messages.length) {
                      final message = chat.messages[index];
                      return _Bubble(
                        message: message,
                        onRetry: message.isError && index == chat.messages.length - 1
                            ? () => ref.read(chatControllerProvider.notifier).retry()
                            : null,
                      );
                    }
                    if (chat.sending && index == chat.messages.length) {
                      return const _TypingBubble();
                    }
                    return _Suggestions(onPick: _send);
                  },
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 500,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Digite sua pergunta…',
                            counterText: '',
                            filled: true,
                            fillColor: cs.surface,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide(color: cs.outlineVariant),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton.filled(
                        tooltip: 'Enviar',
                        onPressed: chat.sending ? null : () => _send(),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.brandPrimary600,
                          minimumSize: const Size(48, 48),
                        ),
                        icon: const Icon(Icons.send_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;

  const _Bubble({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    final background = isUser
        ? AppColors.brandPrimary600
        : (message.isError ? AppColors.danger600.withValues(alpha: 0.1) : cs.surfaceContainerHighest);
    final foreground = isUser
        ? Colors.white
        : (message.isError ? AppColors.danger600 : cs.onSurface);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82 > 560 ? 560 : MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              message.text,
              style: AppTypography.bodyMedium.copyWith(color: foreground, height: 1.4),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  foregroundColor: AppColors.danger600,
                ),
                child: const Text('Tentar de novo'),
              ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        label: 'O assistente está digitando',
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const SizedBox(
            width: 36,
            height: 12,
            child: LinearProgressIndicator(minHeight: 4, borderRadius: BorderRadius.all(Radius.circular(4))),
          ),
        ),
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  final ValueChanged<String> onPick;
  const _Suggestions({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final s in kAssistantSuggestions)
          ActionChip(
            label: Text(s),
            onPressed: () => onPick(s),
            labelStyle: AppTypography.labelMedium.copyWith(color: AppColors.brandPrimary600),
            side: const BorderSide(color: AppColors.brandPrimary600),
            backgroundColor: Colors.transparent,
          ),
      ],
    );
  }
}
