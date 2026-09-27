import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' show PlayerState, ProcessingState;

import '../core/locator.dart';
import '../models/phrase.dart';
import '../repositories/phrase_repository.dart';
import '../services/player_service.dart';

enum PlaybackStatus { idle, playing, paused }

class PhraseListState {
  const PhraseListState({
    this.phrases = const [],
    this.playingId,
    this.status = PlaybackStatus.idle,
    this.error,
  });

  final List<Phrase> phrases;
  final String? playingId;
  final PlaybackStatus status;
  final String? error;

  PhraseListState copyWith({
    List<Phrase>? phrases,
    String? playingId,
    bool clearPlayingId = false,
    PlaybackStatus? status,
    String? error,
    bool clearError = false,
  }) {
    return PhraseListState(
      phrases: phrases ?? this.phrases,
      playingId: clearPlayingId ? null : (playingId ?? this.playingId),
      status: clearPlayingId
          ? PlaybackStatus.idle
          : (status ?? this.status),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PhraseListViewModel extends Notifier<PhraseListState> {
  StreamSubscription<PlayerState>? _playerStateSub;

  @override
  PhraseListState build() {
    final repository = getIt<PhraseRepository>();
    final player = getIt<PlayerService>();
    // build() re-runs (on the same Notifier instance) whenever this
    // provider is invalidated, e.g. by AddPhraseViewModel.save() — cancel
    // any previous subscription before creating a new one.
    _playerStateSub?.cancel();
    _playerStateSub = player.playerStateStream.listen(_handlePlayerState);
    ref.onDispose(_handleDispose);
    return PhraseListState(phrases: repository.getPhrases());
  }

  void refresh() {
    final repository = getIt<PhraseRepository>();
    state = state.copyWith(phrases: repository.getPhrases());
  }

  Future<void> play(Phrase phrase) async {
    try {
      final player = getIt<PlayerService>();
      if (state.playingId == phrase.id &&
          state.status == PlaybackStatus.paused) {
        await player.resume();
      } else {
        final repository = getIt<PhraseRepository>();
        final path = await repository.audioPathFor(phrase);
        await player.play(path);
      }
      state = state.copyWith(
        playingId: phrase.id,
        status: PlaybackStatus.playing,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(
        clearPlayingId: true,
        error: 'Could not play recording.',
      );
    }
  }

  Future<void> pause() async {
    if (state.status != PlaybackStatus.playing) return;
    await getIt<PlayerService>().pause();
    state = state.copyWith(status: PlaybackStatus.paused);
  }

  Future<void> stop() async {
    if (state.playingId == null) return;
    await getIt<PlayerService>().stop();
    state = state.copyWith(clearPlayingId: true);
  }

  Future<void> delete(Phrase phrase) async {
    if (state.playingId == phrase.id) {
      await getIt<PlayerService>().stop();
      state = state.copyWith(clearPlayingId: true);
    }
    try {
      await getIt<PhraseRepository>().deletePhrase(phrase);
      state = state.copyWith(
        phrases: state.phrases.where((p) => p.id != phrase.id).toList(),
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(error: 'Could not delete phrase.');
    }
  }

  void _handlePlayerState(PlayerState playerState) {
    if (playerState.processingState == ProcessingState.completed) {
      state = state.copyWith(clearPlayingId: true);
    }
  }

  void _handleDispose() {
    _playerStateSub?.cancel();
  }
}

final phraseListViewModelProvider =
    NotifierProvider<PhraseListViewModel, PhraseListState>(
      PhraseListViewModel.new,
    );
