import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';
import 'package:path_drawing/path_drawing.dart';
import 'order_arrows.dart';

class ProvinceData {
  final String id;
  final String type; // 'land', 'sea', 'coast'
  final List<String> adjacencies;
  final Path path;

  /// The province path's `class` attribute (`land` | `sea` | `island`), i.e.
  /// the cartography the SVG's own `<style>` block paints it with. Distinct
  /// from [type], which is the gameplay classification (`data-type`) used for
  /// move validation — a coastal province is `type: coast` but `cssClass:
  /// land`.
  final String cssClass;

  ProvinceData({required this.id, required this.type, required this.adjacencies, required this.path, required this.cssClass});
}

/// One shape from the SVG's root-level `<rect>` sea backdrop or its
/// `<g id="neutral">` layer: the base cartography (parchment land, sea,
/// decorative unclickable coastline) that every map ships alongside the
/// interactive `<g id="provinces">` layer. The web client renders the whole
/// SVG natively and gets this for free; this painter has to draw it
/// explicitly or the shapes that exist ONLY here (e.g. small islands with no
/// gameplay role, or the ocean itself) never appear at all — the app's own
/// background shows through in exactly their silhouette.
class NeutralShape {
  final Path path;
  final Color fill;
  final Color stroke;
  final double strokeWidth;

  NeutralShape(this.path, this.fill, this.stroke, this.strokeWidth);
}

/// Fill/stroke/width for each class used in `<g id="neutral">`, the root
/// `<rect>` backdrop and `<g id="provinces">`, copied from the `<style>`
/// block every shipped map SVG defines identically. This mirrors the SVG's
/// own cartography, not the app's UI — it deliberately does not live in
/// `AppColors`. A class this table doesn't recognise falls back to the
/// "land" look rather than disappearing.
const Map<String, (Color, Color, double)> _neutralStyles = {
  'land': (Color(0xFFE8DFC0), Color(0xFF999999), 0.7),
  'island': (Color(0xFFE8DFC0), Color(0xFF999999), 0.7),
  'sea': (Color(0xFFADC8E0), Color(0xFF5A8FAA), 0.5),
  'unclickable': (Color(0xFFCFC6A8), Color(0xFF8A8267), 0.7),
};

class MapViewer extends StatefulWidget {
  final String svgString;
  final Map<String, Color> provinceColors;
  final Map<String, Offset> labelPositions;
  final Map<String, Offset> scPositions;
  final Map<String, Offset> unitPositions;

  /// A unit's own colour (from its owning empire), keyed by the province it
  /// sits in. Distinct from [provinceColors] — that map is supply-center
  /// ownership, and a unit can sit in a province that isn't one, or that a
  /// different empire currently holds the *center* of.
  final Map<String, Color> unitColors;
  final List<Order> orders;
  final Function(String) onProvinceTapped;
  final Function(Map<String, ProvinceData>)? onSvgParsed;
  final String? activeOrderUnitProvince; // If non-null, dim un-selectable provinces
  final Set<String> validTargetProvinces; // Highlight these
  final bool isReadOnly;

  const MapViewer({
    super.key,
    required this.svgString,
    this.provinceColors = const {},
    this.labelPositions = const {},
    this.scPositions = const {},
    this.unitPositions = const {},
    this.unitColors = const {},
    this.orders = const [],
    required this.onProvinceTapped,
    this.onSvgParsed,
    this.activeOrderUnitProvince,
    this.validTargetProvinces = const {},
    this.isReadOnly = false,
  });

  @override
  State<MapViewer> createState() => _MapViewerState();
}

class _MapViewerState extends State<MapViewer> {
  final Map<String, Path> _paths = {};
  final Map<String, String> _provinceClasses = {};
  final List<NeutralShape> _neutralShapes = [];
  // Supply-center marker positions. These are static per map (they don't
  // move turn to turn) and the SVG already carries them in
  // `<g id="supply-centers"><circle>`, so this widget parses them itself
  // instead of asking the caller to supply them — the caller usually has no
  // reason to know them at all (see game_screen.dart, preview_screen.dart:
  // neither ever passed `scPositions`, which is exactly why supply centers
  // never appeared).
  final Map<String, Offset> _svgScPositions = {};
  Size _mapSize = const Size(1000, 1000); // Default, updated on parse

  // Bumped every time `_parseSvg` successfully replaces the parsed data.
  // `_paths` and friends are mutated in place, so comparing map identity in
  // `shouldRepaint` is always false; this counter is what actually changes.
  int _parseGeneration = 0;

  final TransformationController _transformController = TransformationController();
  // The map size the current transform was homed for. Re-homing (writing
  // `_transformController.value`) only happens when THIS changes — never on
  // a viewport-only change, or every `AnimatedSize` tick of the command bar
  // (it has 38/40/72px variants and disappears entirely in history mode)
  // would yank a panned/zoomed player back to the fitted view.
  Size? _homedMapSize;
  // The last viewport `_homeScale` (and so `_boundaryMargin`) was computed
  // for, kept only to skip redundant recomputation on an unchanged rebuild.
  Size? _lastViewportSize;
  double _homeScale = 0.5;
  // Generous enough that the board can be panned to its edge and back
  // without the clamp fighting the home centring, but not so generous that
  // the whole board can be dragged past the edge of the viewport and left
  // on a blank screen with no way back (T02 rules out a "reset view"
  // button). Recomputed alongside `_homeScale` in `_homeTransform`.
  EdgeInsets _boundaryMargin = EdgeInsets.zero;

  @override
  void initState() {
    super.initState();
    _parseSvg().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant MapViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.svgString != widget.svgString) {
      _parseSvg().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _parseSvg() async {
    // Yield to let page transition finish before heavy parsing. Everything
    // below is built into local collections and only written to the state
    // fields once parsing has fully succeeded, so a frame drawn while this
    // is in flight keeps painting the previous (or still-empty) board
    // instead of a half-cleared one.
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final paths = <String, Path>{};
    final provinceClasses = <String, String>{};
    final neutralShapes = <NeutralShape>[];
    final svgScPositions = <String, Offset>{};
    final provinceDataMap = <String, ProvinceData>{};
    var mapSize = _mapSize;

    try {
      final document = XmlDocument.parse(widget.svgString);
      final svgElement = document.findAllElements('svg').firstOrNull;
      if (svgElement != null) {
        final widthStr = svgElement.getAttribute('width')?.replaceAll('px', '');
        final heightStr = svgElement.getAttribute('height')?.replaceAll('px', '');
        if (widthStr != null && heightStr != null) {
          mapSize = Size(double.parse(widthStr), double.parse(heightStr));
        } else {
          final viewBox = svgElement.getAttribute('viewBox');
          if (viewBox != null) {
            final parts = viewBox.split(' ');
            if (parts.length >= 4) {
              mapSize = Size(double.parse(parts[2]), double.parse(parts[3]));
            }
          }
        }

        // The ocean backdrop. Every shipped map draws it as a `<rect>` that
        // is a direct child of `<svg>` — outside `g#neutral` and outside
        // `g#provinces` — so it must be read here, not from the province
        // parser below. It has to be painted before everything else or it
        // covers the whole board. Each `<rect>`'s own `clip-path` is a
        // full-size rect on every shipped map, so ignoring `clip-path` here
        // is currently a no-op, not a shortcut that loses anything.
        for (final element in svgElement.childElements.where((e) => e.name.local == 'rect')) {
          final x = double.tryParse(element.getAttribute('x') ?? '') ?? 0;
          final y = double.tryParse(element.getAttribute('y') ?? '') ?? 0;
          final w = double.tryParse(element.getAttribute('width') ?? '');
          final h = double.tryParse(element.getAttribute('height') ?? '');
          if (w == null || h == null) continue;
          final style = _neutralStyles[element.getAttribute('class')] ?? _neutralStyles['sea']!;
          neutralShapes.add(NeutralShape(Path()..addRect(Rect.fromLTWH(x, y, w, h)), style.$1, style.$2, style.$3));
        }
      }

      // Base cartography — land, sea, decorative coastline that has no
      // gameplay role. Not every map ships this layer (older/simpler maps
      // don't), so its absence is normal, not an error.
      final gNeutral = document.findAllElements('g').where((e) => e.getAttribute('id') == 'neutral').firstOrNull;
      if (gNeutral != null) {
        for (final element in gNeutral.findAllElements('path')) {
          final d = element.getAttribute('d');
          if (d == null) continue;
          final path = parseSvgPathData(d);
          if (element.getAttribute('fill-rule') == 'evenodd') {
            path.fillType = PathFillType.evenOdd;
          }
          // A shape with no `class` but a pattern fill (`fill:url(#...)`) is
          // still decorative sea texture, not land — matching it to "land"
          // would paint a stray tan patch over open water.
          final style = element.getAttribute('class') != null
              ? _neutralStyles[element.getAttribute('class')] ?? _neutralStyles['land']!
              : ((element.getAttribute('style') ?? '').contains('fill:url(')
                  ? _neutralStyles['sea']!
                  : _neutralStyles['land']!);
          neutralShapes.add(NeutralShape(path, style.$1, style.$2, style.$3));
        }
      }

      // Supply-center markers. Static per map — the SVG is the only source
      // for these (the backend's `label_positions` field covers province
      // name labels only). Each <circle>'s <title> reads "XXX supply
      // center"; the first word is the province code.
      final gSc = document.findAllElements('g').where((e) => e.getAttribute('id') == 'supply-centers').firstOrNull;
      if (gSc != null) {
        for (final circle in gSc.findAllElements('circle')) {
          final cx = double.tryParse(circle.getAttribute('cx') ?? '');
          final cy = double.tryParse(circle.getAttribute('cy') ?? '');
          if (cx == null || cy == null) continue;
          final title = circle.findElements('title').firstOrNull?.innerText.trim();
          final code = title?.split(RegExp(r'\s+')).firstOrNull;
          if (code != null && code.isNotEmpty) {
            svgScPositions[code] = Offset(cx, cy);
          }
        }
      }

      final gProvinces = document.findAllElements('g').where((e) => e.getAttribute('id') == 'provinces').firstOrNull;
      final pathElements = gProvinces != null ? gProvinces.findAllElements('path') : document.findAllElements('path');
      for (final element in pathElements) {
        final id = element.getAttribute('id');
        final d = element.getAttribute('d');
        if (id != null && d != null) {
          final path = parseSvgPathData(d);
          paths[id] = path;

          final type = element.getAttribute('data-type') ?? 'land';
          final cssClass = element.getAttribute('class') ?? 'land';
          provinceClasses[id] = cssClass;
          final adjStr = element.getAttribute('data-adj') ?? '';
          final adjacencies = adjStr.isNotEmpty ? adjStr.split(' ') : <String>[];
          provinceDataMap[id] = ProvinceData(id: id, type: type, adjacencies: adjacencies, path: path, cssClass: cssClass);
        }
      }
    } catch (e) {
      debugPrint('Error parsing SVG: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('SVG ERROR: $e')));
      }
      return;
    }

    if (!mounted) return;
    _paths
      ..clear()
      ..addAll(paths);
    _provinceClasses
      ..clear()
      ..addAll(provinceClasses);
    _neutralShapes
      ..clear()
      ..addAll(neutralShapes);
    _svgScPositions
      ..clear()
      ..addAll(svgScPositions);
    _mapSize = mapSize;
    _parseGeneration++;

    if (widget.onSvgParsed != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onSvgParsed!(provinceDataMap);
      });
    }
  }

  void _handleTap(TapUpDetails details) {
    if (widget.isReadOnly) return;
    for (final entry in _paths.entries) {
      if (entry.value.contains(details.localPosition)) {
        widget.onProvinceTapped(entry.key);
        break;
      }
    }
  }

  /// Fits `_mapSize` inside `viewportSize` ("contain": the whole board is
  /// always visible, letterboxed on whichever axis has slack) and centres
  /// it — but only actually writes `_transformController.value` (re-homing,
  /// discarding the player's pan/zoom) when the *map* has changed. A
  /// viewport-only change (the command bar's `AnimatedSize`, the draw
  /// banner, history mode removing the bar entirely) still needs a fresh
  /// `_homeScale`/`_boundaryMargin` — the scale bounds and pan clamp must
  /// track the new available space — but must leave the transform alone.
  /// Cheap to call every build — it does nothing once already up to date —
  /// so it is safe to call unconditionally from `LayoutBuilder`.
  void _homeTransform(Size viewportSize) {
    if (viewportSize.isEmpty || _mapSize.isEmpty) return;
    final mapChanged = _homedMapSize != _mapSize;
    if (!mapChanged && _lastViewportSize == viewportSize) return;
    _lastViewportSize = viewportSize;

    _homeScale = (viewportSize.width / _mapSize.width) < (viewportSize.height / _mapSize.height)
        ? viewportSize.width / _mapSize.width
        : viewportSize.height / _mapSize.height;

    // The boundary is expressed in child (map) coordinates. It needs to
    // cover the letterbox slack on whichever axis has it (half the gap
    // between the scaled map and the viewport on that axis), or the home
    // position itself would be outside the clamp and get fought on the
    // very first frame. On top of that, allow roughly another half-viewport
    // of pan past the map's edge on each side — generous enough that
    // panning to an edge and back never feels clamped, but tight enough
    // that some of the board always stays on screen; a boundary as wide as
    // the whole map (the previous behaviour) let the board be dragged
    // completely off-screen with no "reset view" button to recover with.
    final letterboxX = (viewportSize.width / _homeScale - _mapSize.width).clamp(0, double.infinity) / 2;
    final letterboxY = (viewportSize.height / _homeScale - _mapSize.height).clamp(0, double.infinity) / 2;
    _boundaryMargin = EdgeInsets.symmetric(
      horizontal: letterboxX + viewportSize.width / 2 / _homeScale,
      vertical: letterboxY + viewportSize.height / 2 / _homeScale,
    );

    if (!mapChanged) return;
    _homedMapSize = _mapSize;

    final dx = (viewportSize.width - _mapSize.width * _homeScale) / 2;
    final dy = (viewportSize.height - _mapSize.height * _homeScale) / 2;
    _transformController.value = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(_homeScale);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _homeTransform(Size(constraints.maxWidth, constraints.maxHeight));

        return InteractiveViewer(
          transformationController: _transformController,
          // The home fit is itself the fully-zoomed-out view, so the lower
          // bound sits a hair under it rather than at a fixed 0.5 — on a
          // board bigger than the viewport (every shipped map, on a phone)
          // a fixed 0.5 could still be too far in to show the whole thing.
          minScale: _homeScale * 0.9,
          maxScale: _homeScale * 6.7, // matches the Mini App's zoom range
          constrained: false,
          boundaryMargin: _boundaryMargin,
          child: GestureDetector(
            onTapUp: _handleTap,
            child: SizedBox(
              width: _mapSize.width,
              height: _mapSize.height,
              child: RepaintBoundary(
                child: CustomPaint(
                  size: _mapSize,
                  painter: MapPainter(
                    neutralShapes: _neutralShapes,
                    paths: _paths,
                    provinceClasses: _provinceClasses,
                    parseGeneration: _parseGeneration,
                    provinceColors: widget.provinceColors,
                    labelPositions: widget.labelPositions,
                    // Self-parsed positions first, so an explicit override
                    // from the caller (none exists today) always wins.
                    scPositions: {..._svgScPositions, ...widget.scPositions},
                    unitPositions: widget.unitPositions,
                    unitColors: widget.unitColors,
                    activeOrderUnitProvince: widget.activeOrderUnitProvince,
                    validTargetProvinces: widget.validTargetProvinces,
                  ),
                  foregroundPainter: OrderArrowsPainter(widget.orders),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class MapPainter extends CustomPainter {
  final List<NeutralShape> neutralShapes;
  final Map<String, Path> paths;
  final Map<String, String> provinceClasses;
  final int parseGeneration;
  final Map<String, Color> provinceColors;
  final Map<String, Offset> labelPositions;
  final Map<String, Offset> scPositions;
  final Map<String, Offset> unitPositions;
  final Map<String, Color> unitColors;
  final String? activeOrderUnitProvince;
  final Set<String> validTargetProvinces;

  MapPainter({
    required this.neutralShapes,
    required this.paths,
    required this.provinceClasses,
    required this.parseGeneration,
    required this.provinceColors,
    required this.labelPositions,
    required this.scPositions,
    required this.unitPositions,
    this.unitColors = const {},
    this.activeOrderUnitProvince,
    required this.validTargetProvinces,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // The province geometry on some maps (e.g. `ancient_med`) extends past
    // the SVG's own `viewBox` — the browser clips to it, so this must too,
    // or a sliver of bare scaffold background shows through in ragged
    // notches at the board's edges instead of the "contain" fit being exact.
    canvas.clipRect(Offset.zero & size);

    // 0. Draw the base cartography (land / sea / decorative coastline) that
    // has no gameplay role, so it sits *under* the interactive layer. Shapes
    // that exist only here (e.g. a small island with no matching province)
    // would otherwise never be drawn at all — leaving the app's own
    // background showing through in their exact silhouette instead.
    for (final shape in neutralShapes) {
      canvas.drawPath(shape.path, Paint()..color = shape.fill);
      canvas.drawPath(
        shape.path,
        Paint()
          ..color = shape.stroke
          ..strokeWidth = shape.strokeWidth
          ..style = PaintingStyle.stroke,
      );
    }

    // 1. Draw Provinces: the province's own land/sea/island base fill first
    // (this is the "unclaimed" look, matching the SVG's `<style>` block),
    // then an owner tint on top when one exists, then the class's own
    // stroke — sea and land are outlined differently in the source art, and
    // a flat black 1px line was reading as an outline on a black ground
    // rather than a border between two visibly different terrains.
    for (final entry in paths.entries) {
      final provinceId = entry.key;
      final path = entry.value;
      final style = _neutralStyles[provinceClasses[provinceId]] ?? _neutralStyles['land']!;

      canvas.drawPath(
        path,
        Paint()
          ..color = style.$1
          ..style = PaintingStyle.fill,
      );

      final ownerColor = provinceColors[provinceId];
      if (ownerColor != null) {
        canvas.drawPath(
          path,
          Paint()
            ..color = ownerColor
            ..style = PaintingStyle.fill,
        );
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = style.$2
          ..strokeWidth = style.$3
          ..style = PaintingStyle.stroke,
      );
    }

    // 2. Draw Labels
    for (final entry in labelPositions.entries) {
      final provinceId = entry.key;
      final offset = entry.value;

      final textPainter = TextPainter(
        text: TextSpan(
          text: provinceId,
          style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(offset.dx - textPainter.width / 2, offset.dy - textPainter.height / 2));
    }

    // 3. Draw Supply Centers (stars)
    for (final entry in scPositions.entries) {
      final offset = entry.value;
      _drawStar(canvas, offset, Colors.yellow); // simplified SC marker
    }

    // 4. Draw Units
    for (final entry in unitPositions.entries) {
      final provinceId = entry.key;
      final offset = entry.value;
      // A unit's own colour comes from ITS owner, not the province's supply-
      // center tint — those differ whenever a unit sits in a non-SC province,
      // or holds a center a different empire currently owns.
      final color = unitColors[provinceId] ?? provinceColors[provinceId] ?? Colors.grey;
      
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(offset, 10, paint);
      
      final strokePaint = Paint()
        ..color = Colors.black
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(offset, 10, strokePaint);
    }

    // 5. Draw Dimming Mask if ordering
    if (activeOrderUnitProvince != null) {
      canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
      
      // Draw dimming overlay
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.black54);

      // Punch holes for valid targets
      final punchPaint = Paint()..blendMode = BlendMode.clear;
      for (final target in validTargetProvinces) {
        if (paths.containsKey(target)) {
          canvas.drawPath(paths[target]!, punchPaint);
        }
      }
      
      // Punch hole for the active unit itself
      if (paths.containsKey(activeOrderUnitProvince)) {
        canvas.drawPath(paths[activeOrderUnitProvince]!, punchPaint);
      }

      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, Offset center, Color color) {
    final paint = Paint()..color = color;
    canvas.drawCircle(center, 5, paint);
    canvas.drawCircle(center, 5, Paint()..color = Colors.black..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant MapPainter oldDelegate) {
    // `paths` (and `neutralShapes`) are mutated in place by `_parseSvg`, so
    // old and new delegates always share the same map/list instance and a
    // reference or `mapEquals` comparison on them is always false. The
    // generation counter is what actually changes on a re-parse; the shape
    // count is a cheap extra signal for the neutral layer, which has no
    // per-entry identity to compare.
    return oldDelegate.parseGeneration != parseGeneration ||
        oldDelegate.neutralShapes.length != neutralShapes.length ||
        !mapEquals(oldDelegate.provinceColors, provinceColors) ||
        !mapEquals(oldDelegate.unitPositions, unitPositions) ||
        !mapEquals(oldDelegate.unitColors, unitColors) ||
        !mapEquals(oldDelegate.labelPositions, labelPositions) ||
        !mapEquals(oldDelegate.scPositions, scPositions) ||
        oldDelegate.activeOrderUnitProvince != activeOrderUnitProvince ||
        !setEquals(oldDelegate.validTargetProvinces, validTargetProvinces);
  }
}
