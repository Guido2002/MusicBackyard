import 'package:flutter/material.dart';

import '../../app/localization/context_l10n.dart';

Future<String?> askText(
  BuildContext context,
  String title, {
  String initial = '',
  bool multiline = false,
}) async {
  var value = initial;
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextFormField(
        initialValue: initial,
        onChanged: (text) => value = text,
        autofocus: true,
        minLines: multiline ? 3 : 1,
        maxLines: multiline ? 8 : 1,
        onFieldSubmitted: multiline
            ? null
            : (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, value.trim()),
          child: Text(context.l.save),
        ),
      ],
    ),
  );
  return result;
}

Future<bool> confirm(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l.apply),
          ),
        ],
      ),
    ) ??
    false;
void message(BuildContext context, String text) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

Future<void> guard(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (_) {
    if (context.mounted) {
      message(context, context.l.error);
    }
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.compact = false,
  });
  final IconData icon;
  final String title, body;
  final Widget? action;
  final bool compact;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(compact ? 20 : 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: compact ? 32 : 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(height: compact ? 12 : 24),
              Text(
                title,
                style: compact
                    ? Theme.of(context).textTheme.titleMedium
                    : Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(body, textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: 24), action!],
            ],
          ),
        ),
      ),
    ),
  );
}
