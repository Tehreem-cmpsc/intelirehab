// The exercise illustrations: which media_url values are shown (and which are
// refused), that a missing one degrades quietly, and that the bundled files
// are real animated WebP images.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/core/theme/app_theme.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/exercises_models.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/widgets/exercise_media.dart';

void main() {
  group('ExerciseMedia.providerFor', () {
    test('a relative path is a bundled asset', () {
      final p = ExerciseMedia.providerFor('exercises/hammer-curl.webp');
      expect(p, isA<AssetImage>());
      expect((p as AssetImage).assetName, 'assets/exercises/hammer-curl.webp');
      expect((ExerciseMedia.providerFor('/exercises/hammer-curl.webp') as AssetImage).assetName,
          'assets/exercises/hammer-curl.webp');
    });

    test('an https URL is loaded from the network', () {
      expect(ExerciseMedia.providerFor('https://cdn.example.com/curl.webp'), isA<NetworkImage>());
    });

    test('anything else is refused', () {
      for (final bad in [
        null,
        '',
        '   ',
        'http://example.com/a.webp',
        'file:///etc/passwd',
        'javascript:alert(1)',
        '//evil.example.com/a.webp',
        '../secret.webp',
        'exercises/../../secret.webp',
      ]) {
        expect(ExerciseMedia.providerFor(bad), isNull, reason: '$bad');
      }
    });

    test('a video is not shown as an image', () {
      expect(ExerciseMedia.providerFor('https://cdn.example.com/curl.mp4', mediaType: 'video'), isNull);
    });
  });

  testWidgets('no media shows a placeholder, not an error', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: ExerciseMedia(mediaUrl: null, name: 'Hammer Curl')),
    ));
    expect(find.byIcon(Icons.accessibility_new), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a thumbnail with no media keeps the plain icon', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: ExerciseThumb(mediaUrl: null, name: 'Hammer Curl')),
    ));
    expect(find.byIcon(Icons.accessibility_new), findsOneWidget);
  });

  test('AssignedExercise keeps its media through the journal JSON', () {
    const e = AssignedExercise(
      assignmentId: 'a',
      exerciseId: 'e',
      name: 'Hammer Curl',
      target: null,
      difficulty: 'Beginner',
      description: null,
      mediaUrl: 'exercises/hammer-curl.webp',
      sets: 3,
      repsTarget: 10,
      romTarget: null,
    );
    final back = AssignedExercise.fromJson(e.toJson());
    expect(back.mediaUrl, 'exercises/hammer-curl.webp');
    expect(back.mediaType, 'image');
    // An older journal entry without the fields still loads.
    final old = e.toJson()..remove('mediaUrl')..remove('mediaType');
    expect(AssignedExercise.fromJson(old).mediaUrl, isNull);
  });

  test('every bundled illustration is a real animated WebP', () {
    final dir = Directory('assets/exercises');
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.webp')).toList();
    expect(files.length, greaterThanOrEqualTo(35));
    for (final f in files) {
      final b = f.readAsBytesSync();
      expect(b.length, greaterThan(1000), reason: f.path);
      expect(String.fromCharCodes(b.sublist(0, 4)), 'RIFF', reason: f.path);
      expect(String.fromCharCodes(b.sublist(8, 12)), 'WEBP', reason: f.path);
      // An animated WebP carries an ANIM chunk; a still image would not.
      expect(String.fromCharCodes(b).contains('ANIM'), isTrue, reason: '${f.path} is not animated');
      expect(b.length, lessThan(150 * 1024), reason: '${f.path} is too big to bundle 35 of');
    }
  });

  testWidgets("Flutter's own decoder reads each illustration as a multi-frame animation", (tester) async {
    await tester.runAsync(() async {
      for (final f in Directory('assets/exercises').listSync().whereType<File>().where((f) => f.path.endsWith('.webp'))) {
        final codec = await ui.instantiateImageCodec(f.readAsBytesSync());
        expect(codec.frameCount, greaterThan(1), reason: f.path);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 256, reason: f.path);
        frame.image.dispose();
        codec.dispose();
      }
    });
  });
}
