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

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:diplomacy_app/models/board_state.dart';
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

/// Province-code -> label anchor, read straight out of the SVG's own
/// `g#labels`, exactly what `map_viewer.dart`'s `_parseSvg` reads for T05.
/// There is no live game here to carry DB `unit_x`/`unit_y` (those are
/// DB-owned at runtime, per CONTEXT.md), so this harness anchors every
/// starting unit at its own province's label position + 16 — the same
/// unit_x/unit_y-null fallback T04 specifies for `game_screen.dart`'s
/// `_computeUnits()`.
Map<String, Offset> _svgLabelPositions(String svg) {
  final document = XmlDocument.parse(svg);
  final positions = <String, Offset>{};
  final gLabels = document.findAllElements('g').where((e) => e.getAttribute('id') == 'labels').firstOrNull;
  if (gLabels == null) return positions;
  for (final text in gLabels.findAllElements('text')) {
    final code = text.innerText.trim();
    final x = double.tryParse(text.getAttribute('x') ?? '');
    final y = double.tryParse(text.getAttribute('y') ?? '');
    if (code.isEmpty || x == null || y == null) continue;
    positions.putIfAbsent(code, () => Offset(x, y));
  }
  return positions;
}

/// Starting province ownership tints and unit tokens for `name`, read from
/// the same `<name>.empires.json` the server's own `import_map`/
/// `export_empires` round-trip through — real empire colours and real
/// starting armies/fleets, not synthetic placeholders. One unit per map is
/// flagged dislodged so the harness also exercises T04's halo/opacity path,
/// which a plain game-start snapshot would never contain.
(Map<String, Color>, List<MapUnit>) _startingPositionFor(String mapsDir, String name, Map<String, Offset> labelPositions) {
  final empiresJson = jsonDecode(File('$mapsDir/$name.empires.json').readAsStringSync()) as Map<String, dynamic>;
  final empires = (empiresJson['empires'] as List).cast<Map<String, dynamic>>();

  final provinceColors = <String, Color>{};
  final units = <MapUnit>[];
  var flaggedDislodged = false;
  for (final empire in empires) {
    final hex = empire['color'] as String;
    final color = Color(int.parse('0xFF${hex.substring(1)}'));
    for (final code in (empire['territory'] as List).cast<String>()) {
      provinceColors[code] = color.withOpacity(0.55);
    }
    for (final raw in (empire['units'] as List).cast<String>()) {
      final parts = raw.split(' ');
      final code = parts[1];
      final anchor = labelPositions[code];
      if (anchor == null) continue; // no SVG label for this code — skip rather than guess a position
      units.add(MapUnit(
        province: code,
        type: parts[0] == 'F' ? 'fleet' : 'army',
        position: anchor.translate(0, 16),
        color: color,
        isDislodged: !flaggedDislodged,
      ));
      flaggedDislodged = true;
    }
  }
  return (provinceColors, units);
}

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
      final labelPositions = _svgLabelPositions(svg);
      final (provinceColors, units) = _startingPositionFor(_mapsDir, name, labelPositions);

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
              provinceColors: provinceColors,
              units: units,
              mapSlug: name,
              onProvinceTapped: (_) {},
            ),
          ),
        ),
      ));

      // `_parseSvg` deliberately yields for 300 ms before parsing, so that a
      // page transition is not competing with 269 province paths. The unit
      // icon load is a separate async fetch off `rootBundle` kicked off from
      // `initState`, so it also needs a settle before the tokens the
      // assertions below expect to see have actually landed.
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

  // The tests above prove `MapViewer` paints given hand-assembled `MapUnit`s
  // and `scPositions` — they say nothing about whether `BoardState` (and so
  // `GameScreen`/`GamePreviewScreen`) actually produces those from a real
  // server payload. This drives `BoardState.units`/`BoardState.scPositions`/
  // `BoardState.mapSlugFromSvgUrl` — the exact functions T04/T03 wired the
  // two screens to — through a payload shaped like `_serialize_game_state`
  // (game/api/serializers.py), then paints the result, so a caller-side
  // regression (a wrong field name, a dropped coast, a mixed-up y+16) is
  // caught here even though it would never show up in a test that only
  // constructs `MapUnit`s directly.
  group('BoardState → MapViewer conversion', () {
    // Real coordinates lifted from diplomacy_classic.svg's own `g#labels`/
    // `g#supply-centers`, not invented numbers — a wrong port of
    // `unitCenter()`'s field precedence could still "work" against made-up
    // coordinates that happen not to exercise the label/unit_x fallback.
    const parLabel = Offset(362.744, 731.981);
    const parSc = Offset(375.585, 706.754);
    const lonLabel = Offset(357.376, 638.33);
    const lonSc = Offset(352.843, 614.879);
    const mosSc = Offset(1012.67, 511.086);
    const stpLabel = Offset(904.217, 406.123);
    const vieSc = Offset(646.451, 754.053);

    // Mirrors `_serialize_game_state`'s `units` rows: one with an admin-set
    // `unit_x`/`unit_y` (PAR), one relying on the `label_y + 16` fallback
    // because the admin never set a position (LON, also flagged dislodged
    // to exercise T04's halo), and a split-coast pair sharing STP with no
    // `coast_positions` entry at all — so both must fall through to the
    // ported `COAST_OFFSETS` table rather than land on the same pixel.
    final units = [
      {
        'province_code': 'PAR',
        'label_x': parLabel.dx, 'label_y': parLabel.dy,
        'unit_x': parSc.dx, 'unit_y': parSc.dy,
        'color': '#59a8d3', // FRA
        'unit_type': 0, // army
        'is_dislodged': false,
        'coast': '',
      },
      {
        'province_code': 'LON',
        'label_x': lonLabel.dx, 'label_y': lonLabel.dy,
        'unit_x': null, 'unit_y': null,
        'color': '#196bde', // ENG
        'unit_type': 1, // fleet
        'is_dislodged': true,
        'coast': '',
      },
      {
        'province_code': 'STP',
        'label_x': stpLabel.dx, 'label_y': stpLabel.dy,
        'unit_x': null, 'unit_y': null,
        'color': '#f6d258', // TUR
        'unit_type': 1,
        'is_dislodged': false,
        'coast': 'NC',
      },
      {
        'province_code': 'STP',
        'label_x': stpLabel.dx, 'label_y': stpLabel.dy,
        'unit_x': null, 'unit_y': null,
        'color': '#d15245', // AUS
        'unit_type': 1,
        'is_dislodged': false,
        'coast': 'SC',
      },
    ];

    // Mirrors `sc_ownership`: PAR/LON/MOS are real supply centres with
    // coordinates; VIE is a province the SVG itself marks with a
    // `<circle class="sc">` (real map data — see `vieSc` above) but whose
    // ownership row says `is_supply_center: false`, the exact "SC removed
    // from the DB" case T03 exists for.
    final scOwnership = [
      {'province_code': 'PAR', 'empire_code': 'FRA', 'is_supply_center': true, 'sc_x': parSc.dx, 'sc_y': parSc.dy},
      {'province_code': 'LON', 'empire_code': 'ENG', 'is_supply_center': true, 'sc_x': lonSc.dx, 'sc_y': lonSc.dy},
      {'province_code': 'MOS', 'empire_code': 'RUS', 'is_supply_center': true, 'sc_x': mosSc.dx, 'sc_y': mosSc.dy},
      {'province_code': 'VIE', 'empire_code': null, 'is_supply_center': false, 'sc_x': vieSc.dx, 'sc_y': vieSc.dy},
    ];

    const gameSvgUrl = '/static/maps/diplomacy_classic.svg?v=1234567890';

    test('BoardState.units/scPositions/mapSlugFromSvgUrl read the payload correctly', () {
      final resolved = BoardState.units(units: units, coastPositions: const {}, armyCoasts: const {});
      expect(resolved, hasLength(4));

      final par = resolved.firstWhere((u) => u.province == 'PAR');
      expect(par.position, parSc, reason: 'an admin-set unit_x/unit_y must win over the label fallback');
      expect(par.type, 'army');

      final lon = resolved.firstWhere((u) => u.province == 'LON');
      expect(lon.position, lonLabel.translate(0, 16),
          reason: 'a null unit_x/unit_y must fall back to label_y + 16, matching map.js unitCenter()');
      expect(lon.isDislodged, isTrue);

      final stpUnits = resolved.where((u) => u.province == 'STP').toList();
      expect(stpUnits, hasLength(2));
      // Both STP tokens must actually separate — this is T04's split-coast
      // acceptance criterion expressed as geometry rather than a screenshot.
      final separation = (stpUnits[0].position - stpUnits[1].position).distance;
      expect(separation, greaterThan(50),
          reason: 'STP/NC and STP/SC must not land on the same pixel — got ${stpUnits[0].position} and ${stpUnits[1].position}');
      for (final u in stpUnits) {
        expect(u.position, isNot(stpLabel),
            reason: 'a split-coast fallback must actually apply the COAST_OFFSETS nudge, not just echo the label position');
      }

      final scPositions = BoardState.scPositions(scOwnership);
      expect(scPositions['PAR'], parSc);
      expect(scPositions['LON'], lonSc);
      expect(scPositions['MOS'], mosSc);
      expect(scPositions.containsKey('VIE'), isFalse,
          reason: 'is_supply_center: false must suppress the dot even though the SVG itself has a <circle class="sc"> for VIE');

      expect(BoardState.mapSlugFromSvgUrl(gameSvgUrl), 'diplomacy_classic');
    });

    testWidgets('paints the real conversion (visual check)', (tester) async {
      if (!mapsDirExists) {
        markTestSkipped('Conspa checkout not found at $_mapsDir.');
        return;
      }
      final svg = File('$_mapsDir/diplomacy_classic.svg').readAsStringSync();
      final resolvedUnits = BoardState.units(units: units, coastPositions: const {}, armyCoasts: const {});
      final resolvedScPositions = BoardState.scPositions(scOwnership);
      final mapSlug = BoardState.mapSlugFromSvgUrl(gameSvgUrl);

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
              scPositions: resolvedScPositions,
              units: resolvedUnits,
              mapSlug: mapSlug,
              onProvinceTapped: (_) {},
            ),
          ),
        ),
      ));

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      late Uint8List png;
      late ui.Image image;
      await tester.runAsync(() async {
        image = await boundary.toImage(pixelRatio: 2.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        png = data!.buffer.asUint8List();
      });

      // The same blankness sanity check the per-map tests above run — this
      // group's real assertions are the exact-geometry ones above (position,
      // separation, dislodged flag, SC filtering); this PNG is for the human
      // check T04 asks for (a split-coast province drawing two separated
      // tokens, a dislodged halo, SC dots not colliding with tokens), not a
      // second copy of those as pixel assertions.
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
          reason: 'board_state_conversion painted $distinctColours distinct colours — effectively blank');

      final out = Directory('build/map_render')..createSync(recursive: true);
      // Named distinctly from the per-map files above: this one exercises
      // the BoardState conversion, not a hand-built MapUnit list, so a
      // reviewer opening it is looking for the split-coast/halo/SC-overlap
      // behaviour described in this group's doc comment, not general
      // cartography.
      File('${out.path}/board_state_conversion.png').writeAsBytesSync(png);
    });
  });
}
