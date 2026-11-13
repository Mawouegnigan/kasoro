import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/supported_languages.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';

String _languageLabel(String code) {
  return supportedLanguages
      .firstWhere((l) => l.$1 == code, orElse: () => (code, code))
      .$2;
}

class PendingCorrection {
  const PendingCorrection({
    required this.id,
    required this.type,
    required this.language,
    required this.original,
    required this.corrected,
  });

  final String id;
  final String type;
  final String language;
  final String original;
  final String corrected;

  factory PendingCorrection.fromJson(Map<String, dynamic> json) {
    return PendingCorrection(
      id: json['id'] as String,
      type: json['correction_type'] as String,
      language: json['language'] as String,
      original: (json['original_value'] as String?) ?? '',
      corrected: (json['corrected_value'] as String?) ?? '',
    );
  }
}

final validationLanguagesProvider = StateProvider<Set<String>>((ref) => <String>{});

final pendingCorrectionsProvider =
    FutureProvider.autoDispose<List<PendingCorrection>>((ref) async {
  final List<String> langs = ref.watch(validationLanguagesProvider).toList()..sort();
  try {
    final response =
        await ref.read(dioClientProvider).get<List<dynamic>>(
      '/corrections/pending',
      queryParameters: langs.isEmpty ? null : {'languages': langs.join(',')},
    );
    return response.data!
        .map((j) => PendingCorrection.fromJson(j as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    throw ApiException.fromDioException(e);
  }
});
class ValidationScreen extends ConsumerWidget {
  const ValidationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<PendingCorrection>> pending =
        ref.watch(pendingCorrectionsProvider);

    return Scaffold(
      appBar: AppBar(bottom: const PreferredSize(preferredSize: Size.fromHeight(56), child: _LanguageFilter()), title: const Text('Corrections à valider')),
      body: pending.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(e is ApiException ? e.message : 'Chargement impossible : $e'),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aucune correction à valider pour le moment.'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(pendingCorrectionsProvider);
              await ref.read(pendingCorrectionsProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, i) => _CorrectionCard(item: items[i]),
            ),
          );
        },
      ),
    );
  }
}
class _LanguageFilter extends ConsumerWidget {
  const _LanguageFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<String> selected = ref.watch(validationLanguagesProvider);
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final String code in const ['fon', 'yo', 'wo'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_languageLabel(code)),
                selected: selected.contains(code),
                onSelected: (bool v) {
                  final Set<String> next = {...selected};
                  if (v) {
                    next.add(code);
                  } else {
                    next.remove(code);
                  }
                  ref.read(validationLanguagesProvider.notifier).state = next;
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _CorrectionCard extends ConsumerStatefulWidget {
  const _CorrectionCard({required this.item});
  final PendingCorrection item;

  @override
  ConsumerState<_CorrectionCard> createState() => _CorrectionCardState();
}

class _CorrectionCardState extends ConsumerState<_CorrectionCard> {
  bool _busy = false;

  Future<void> _decide(bool approve) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(dioClientProvider).post<Map<String, dynamic>>(
        '/corrections/${widget.item.id}/validate',
        data: {'approve': approve},
        queryParameters: ref.read(validationLanguagesProvider).isEmpty
            ? null
            : {'languages': (ref.read(validationLanguagesProvider).toList()..sort()).join(',')},
      );
      ref.invalidate(pendingCorrectionsProvider);
      messenger.showSnackBar(SnackBar(
        content: Text(approve ? 'Correction approuvée. Merci !' : 'Correction rejetée.'),
      ));
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(content: Text(ApiException.fromDioException(e).message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final PendingCorrection c = widget.item;
    final bool isTranscription = c.type == 'transcription';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${isTranscription ? 'Transcription' : 'Traduction'} · ${_languageLabel(c.language)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text('Avant', style: TextStyle(fontSize: 12)),
            Text(c.original.isEmpty ? '(aucun texte existant)' : c.original),
            const SizedBox(height: 8),
            const Text('Après', style: TextStyle(fontSize: 12)),
            Text(c.corrected),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => _decide(false),
                  child: const Text('Rejeter'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : () => _decide(true),
                  child: const Text('Approuver'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}