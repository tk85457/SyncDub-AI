import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_exp;

class DialogueSegment {
  final int startMs;
  final int durationMs;
  final String originalText;
  String translatedText;
  String? audioPath;

  DialogueSegment({
    required this.startMs,
    required this.durationMs,
    required this.originalText,
    this.translatedText = '',
    this.audioPath,
  });

  Map<String, dynamic> toJson() => {
    'startMs': startMs,
    'durationMs': durationMs,
    'originalText': originalText,
    'translatedText': translatedText,
    'audioPath': audioPath ?? '',
  };
}

Future<void> main() async {
  final yt = yt_exp.YoutubeExplode();
  final videoId = 'dQw4w9WgXcQ';
  try {
    print('1. Fetching caption manifest for $videoId...');
    final manifest = await yt.videos.closedCaptions.getManifest(videoId);
    print('Available tracks: ${manifest.tracks.length}');

    yt_exp.ClosedCaptionTrackInfo? selectedTrack;
    for (final t in manifest.tracks) {
      if (t.language.code.startsWith('en')) {
        selectedTrack = t;
        break;
      }
    }
    selectedTrack ??= manifest.tracks.firstOrNull;

    if (selectedTrack == null) {
      print('No caption tracks found!');
      return;
    }

    print('Using track: ${selectedTrack.language.name} (${selectedTrack.language.code})');
    final track = await yt.videos.closedCaptions.get(selectedTrack);
    print('Raw caption count: ${track.captions.length}');

    // Group captions into sentences/phrases
    final segments = <DialogueSegment>[];
    String currentText = '';
    int groupStartMs = 0;
    int groupEndMs = 0;

    for (final c in track.captions.take(15)) {
      final start = c.offset.inMilliseconds;
      final dur = c.duration.inMilliseconds;
      final end = start + dur;
      final text = c.text.replaceAll('\n', ' ').trim();
      if (text.isEmpty) continue;

      if (currentText.isEmpty) {
        currentText = text;
        groupStartMs = start;
        groupEndMs = end;
      } else {
        // If pause between captions is > 1.2s or current length > 60 chars, push group
        final gap = start - groupEndMs;
        if (gap > 1200 || currentText.length > 60 || currentText.endsWith('.') || currentText.endsWith('?')) {
          segments.add(DialogueSegment(
            startMs: groupStartMs,
            durationMs: groupEndMs - groupStartMs,
            originalText: currentText,
          ));
          currentText = text;
          groupStartMs = start;
          groupEndMs = end;
        } else {
          currentText += ' $text';
          groupEndMs = end;
        }
      }
    }
    if (currentText.isNotEmpty) {
      segments.add(DialogueSegment(
        startMs: groupStartMs,
        durationMs: groupEndMs - groupStartMs,
        originalText: currentText,
      ));
    }

    print('Grouped into ${segments.length} dialogue phrases:');
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      print('[$i] at ${s.startMs}ms (${s.durationMs}ms): "${s.originalText}"');
    }

    // Translate first 4 segments
    final targetLang = 'hi';
    print('\n2. Translating phrases to $targetLang...');
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      // Clean music tags
      final cleanOrig = s.originalText
          .replaceAll(RegExp(r'\[.*?\]'), '')
          .replaceAll('♪', '')
          .trim();
      if (cleanOrig.isEmpty) {
        print('[$i] Skipped non-speech audio marker: ${s.originalText}');
        continue;
      }

      try {
        final transUri = Uri.parse(
          'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=$targetLang&dt=t&q=${Uri.encodeComponent(cleanOrig)}',
        );
        final res = await http.get(transUri);
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          s.translatedText = (data[0] as List).map((item) => item[0]).join().trim();
          print('[$i] Translated: "${s.translatedText}"');

          if (s.translatedText.isNotEmpty) {
            final ttsUri = Uri.parse(
              'https://translate.google.com/translate_tts?ie=UTF-8&q=${Uri.encodeComponent(s.translatedText)}&tl=$targetLang&client=tw-ob',
            );
            final ttsRes = await http.get(ttsUri, headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
            });
            if (ttsRes.statusCode == 200 && ttsRes.bodyBytes.isNotEmpty) {
              final outFile = File('test_segment_$i.mp3');
              await outFile.writeAsBytes(ttsRes.bodyBytes);
              s.audioPath = outFile.path;
              print('[$i] TTS saved: ${outFile.path} (${ttsRes.bodyBytes.length} bytes)');
            }
          }
        }
      } catch (err) {
        print('[$i] Error: $err');
      }
    }
    print('\nPipeline test SUCCESS!');
  } catch (e) {
    print('Pipeline test error: $e');
  } finally {
    yt.close();
  }
}
