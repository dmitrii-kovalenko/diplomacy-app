// A rendering harness, not an assertion suite: it pumps `MapViewer` with the
// real map SVGs the server ships and writes what it painted to
// `build/map_render/<map>.png`, so a human (or a reviewer) can look at the
// board instead of reasoning about it from the painter's source.
//
// It exists because every map defect so far — a black ground, a board that
// cannot be zoomed out far enough to see, units drawn as bare dots — is
// invisible to `flutter analyze` and to a widget test that only counts
// finders. Run it with:
//
//   flutter test test/map_render_harness_test.dart
//
// The one thing it does assert is that the paint is not blank, which is the
// failure mode that started all of this.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diplomacy_app/widgets/map_viewer.dart';

/// The map SVGs live in the Django repo, which is the single source of truth
/// for them; the Flutter client fetches them over HTTP at runtime.
const _mapsDir = '/Users/dmitrii/Coding/Conspa/DjangoProject/assets/maps';

/// One map from each shape of the problem: the canonical board, the biggest
/// board, a portrait board, and the two that ship without a `g#neutral`
/// layer at all.
const _maps = [
  'diplomacy_classic',
  'known_world_901',
  'north_america',
  'ancient_med',
];

/// A phone, in logical pixels — the viewport the board actually has to fit.
const _viewport = Size(390, 700);

void main() {
  // The SVGs live in a sibling checkout of a different repo — real on this
  // machine, but not something any other clone of this repo can assume.
  // Skip rather than fail so the suite stays green (not merely "expected to
  // fail") wherever that checkout doesn't exist.
  final mapsDirExists = Directory(_mapsDir).existsSync();

  for (final name in _maps) {
    testWidgets('renders $name', (tester) async {
      if (!mapsDirExists) {
        markTestSkipped('Conspa checkout not found at $_mapsDir — this harness reads '
            'the map SVGs from the Django repo, which is not available on this machine.');
        return;
      }
      final svg = File('$_mapsDir/$name.svg').readAsStringSync();

      tester.view.physicalSize = _viewport;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: RepaintBoundary(
            key: boundaryKey,
            child: MapViewer(
              svgString: svg,
              onProvinceTapped: (_) {},
            ),
          ),
        ),
      ));

      // `_parseSvg` deliberately yields for 300 ms before parsing, so that a
      // page transition is not competing with 269 province paths.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      final boundary = boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;

      late Uint8List png;
      late ui.Image image;
      await tester.runAsync(() async {
        image = await boundary.toImage(pixelRatio: 2.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        png = data!.buffer.asUint8List();
      });

      final out = Directory('build/map_render')..createSync(recursive: true);
      File('${out.path}/$name.png').writeAsBytesSync(png);

      // Blankness check: sample the raw pixels and count distinct colours.
      // A board that failed to render is one flat colour edge to edge, which
      // is exactly what the black-map bug looked like.
      late int distinctColours;
      await tester.runAsync(() async {
        final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final bytes = raw!.buffer.asUint8List();
        final seen = <int>{};
        for (var i = 0; i + 3 < bytes.length; i += 4 * 97) {
          seen.add((bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2]);
        }
        distinctColours = seen.length;
      });

      expect(distinctColours, greaterThan(4),
          reason: '$name painted $distinctColours distinct colours — the board '
              'is effectively blank');

      // Fit-to-viewport check: a board that is technically non-blank but
      // jammed into one corner (the original defect — a couple of
      // decorative islands at 1:1 zoom in the top-left) would still pass
      // the distinct-colour check above. Treat the corner pixel as
      // "background" (every shipped map's aspect ratio differs from the
      // phone viewport, so at least one axis always letterboxes and a
      // corner is reliably untouched) and find the bounding box of
      // everything else painted on top of it.
      late Rect contentBounds;
      await tester.runAsync(() async {
        final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final bytes = raw!.buffer.asUint8List();
        final width = image.width;
        final height = image.height;
        int colourAt(int x, int y) {
          final i = (y * width + x) * 4;
          return (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2];
        }

        final background = colourAt(0, 0);
        var minX = width, minY = height, maxX = 0, maxY = 0;
        const step = 4; // every 4th pixel on each axis is plenty for a bbox.
        for (var y = 0; y < height; y += step) {
          for (var x = 0; x < width; x += step) {
            if (colourAt(x, y) != background) {
              if (x < minX) minX = x;
              if (x > maxX) maxX = x;
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
            }
          }
        }
        contentBounds = Rect.fromLTRB(minX.toDouble(), minY.toDouble(), maxX.toDouble(), maxY.toDouble());
      });

      final imageSize = Size(image.width.toDouble(), image.height.toDouble());

      expect(
        contentBounds.width / imageSize.width > 0.9 || contentBounds.height / imageSize.height > 0.9,
        isTrue,
        reason: '$name only fills ${contentBounds.width.toStringAsFixed(0)}x'
            '${contentBounds.height.toStringAsFixed(0)} of a '
            '${imageSize.width.toStringAsFixed(0)}x${imageSize.height.toStringAsFixed(0)} '
            'viewport — the whole board is not visible',
      );

      final boundsCenter = contentBounds.center;
      final imageCenter = Offset(imageSize.width / 2, imageSize.height / 2);
      expect(
        (boundsCenter - imageCenter).distance < imageSize.shortestSide * 0.15,
        isTrue,
        reason: '$name is painted off-centre (bounding-box centre '
            '$boundsCenter vs. viewport centre $imageCenter) — it reads as '
            'jammed into a corner rather than fit to the screen',
      );
    });
  }

  // `diplomacy_classic`, `europe_duel` and `europe_extended` all ship at
  // 1286x1166 in this checkout, but a byte-for-byte diff shows they are
  // currently identical placeholder files — swapping between them proves
  // nothing either way. Two minimal synthetic SVGs of an arbitrary shared
  // size stand in instead, so the test exercises the actual gap: a same-
  // size swap does not change `_mapSize` and so cannot rely on a relayout
  // to force a fresh paint — the exact case `shouldRepaint`'s old
  // `oldDelegate.paths != paths` self-comparison (always false, since
  // `_paths` is mutated in place rather than replaced) could hide.
  Size probeSize(String svg) {
    final match = RegExp(r'width="(\d+)" height="(\d+)"').firstMatch(svg)!;
    return Size(double.parse(match.group(1)!), double.parse(match.group(2)!));
  }

  String singleProvinceSvg(String cssClass) => '''
<svg width="200" height="200" viewBox="0 0 200 200">
  <g id="provinces">
    <path id="ONLY" class="$cssClass" data-type="$cssClass" d="M0 0 H200 V200 H0 Z" />
  </g>
</svg>
''';

  testWidgets('repaints on a same-size map swap (didUpdateWidget)', (tester) async {
    final seaSvg = singleProvinceSvg('sea');
    final landSvg = singleProvinceSvg('land');
    expect(probeSize(seaSvg), probeSize(landSvg), reason: 'test setup bug: the two probe SVGs must share a size');

    tester.view.physicalSize = _viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final boundaryKey = GlobalKey();
    Widget host(String svg) => MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: RepaintBoundary(
              key: boundaryKey,
              child: MapViewer(svgString: svg, onProvinceTapped: (_) {}),
            ),
          ),
        );

    Future<Color> centrePixel() async {
      final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      late Color colour;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.0);
        final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final bytes = raw!.buffer.asUint8List();
        final i = (image.height ~/ 2 * image.width + image.width ~/ 2) * 4;
        colour = Color.fromARGB(255, bytes[i], bytes[i + 1], bytes[i + 2]);
      });
      return colour;
    }

    await tester.pumpWidget(host(seaSvg));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final seaColour = await centrePixel();

    await tester.pumpWidget(host(landSvg));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final landColour = await centrePixel();

    // `_neutralStyles['sea']` is #ADC8E0, `_neutralStyles['land']` is
    // #E8DFC0 — a repaint should have moved the centre pixel from one to
    // the other; a stale paint would leave it on the sea colour.
    expect(seaColour, const Color(0xFFADC8E0));
    expect(landColour, const Color(0xFFE8DFC0),
        reason: 'the board still shows the previous map\'s colour after a '
            'same-size svgString swap — didUpdateWidget did not repaint');
  });
}
