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

  ProvinceData({required this.id, required this.type, required this.adjacencies, required this.path});
}

/// One shape from the SVG's `<g id="neutral">` layer: the base cartography
/// (parchment land, sea, decorative unclickable coastline) that every map
/// ships alongside the interactive `<g id="provinces">` layer. The web
/// client renders the whole SVG natively and gets this for free; this
/// painter has to draw it explicitly or the shapes that exist ONLY in this
/// layer (e.g. small islands with no gameplay role) never appear at all —
/// the app's own background shows through in exactly their silhouette.
class NeutralShape {
  final Path path;
  final Color fill;
  final Color stroke;
  final double strokeWidth;

  NeutralShape(this.path, this.fill, this.stroke, this.strokeWidth);
}

/// Fill/stroke/width for each class used in `<g id="neutral">`, copied from
/// the `<style>` block every shipped map SVG defines identically. A class
/// this table doesn't recognise falls back to the "land" look rather than
/// disappearing.
const Map<String, (Color, Color, double)> _neutralStyles = {
  'land': (Color(0xFFE8DFC0), Color(0xFF999999), 0.7),
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

  Future<void> _parseSvg() async {
    _paths.clear();
    _neutralShapes.clear();
    _svgScPositions.clear();
    final Map<String, ProvinceData> provinceDataMap = {};
    
    // Yield to let page transition finish before heavy parsing
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    
    try {
      final document = XmlDocument.parse(widget.svgString);
      final svgElement = document.findAllElements('svg').firstOrNull;
      if (svgElement != null) {
        final widthStr = svgElement.getAttribute('width')?.replaceAll('px', '');
        final heightStr = svgElement.getAttribute('height')?.replaceAll('px', '');
        if (widthStr != null && heightStr != null) {
          _mapSize = Size(double.parse(widthStr), double.parse(heightStr));
        } else {
          final viewBox = svgElement.getAttribute('viewBox');
          if (viewBox != null) {
            final parts = viewBox.split(' ');
            if (parts.length >= 4) {
              _mapSize = Size(double.parse(parts[2]), double.parse(parts[3]));
            }
          }
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
          _neutralShapes.add(NeutralShape(path, style.$1, style.$2, style.$3));
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
            _svgScPositions[code] = Offset(cx, cy);
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
          _paths[id] = path;
          
          final type = element.getAttribute('data-type') ?? 'land';
          final adjStr = element.getAttribute('data-adj') ?? '';
          final adjacencies = adjStr.isNotEmpty ? adjStr.split(' ') : <String>[];
          provinceDataMap[id] = ProvinceData(id: id, type: type, adjacencies: adjacencies, path: path);
        }
      }
      
      if (widget.onSvgParsed != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onSvgParsed!(provinceDataMap);
        });
      }
    } catch (e) {
      debugPrint('Error parsing SVG: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('SVG ERROR: $e')));
      }
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

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 5.0,
      constrained: false,
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
                provinceColors: widget.provinceColors,
                labelPositions: widget.labelPositions,
                // Self-parsed positions first, so an explicit override from
                // the caller (none exists today) always wins.
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
  }
}

class MapPainter extends CustomPainter {
  final List<NeutralShape> neutralShapes;
  final Map<String, Path> paths;
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

    // 1. Draw Provinces
    for (final entry in paths.entries) {
      final provinceId = entry.key;
      final path = entry.value;

      // Transparent, not white, when nobody owns this province: the base
      // layer drawn above (parchment land / sea) is the "unclaimed" look.
      // A province colour, when present, is a translucent tint over it.
      final paint = Paint()
        ..color = provinceColors[provinceId] ?? Colors.transparent
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, paint);

      final strokePaint = Paint()
        ..color = Colors.black
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, strokePaint);
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
    return !mapEquals(oldDelegate.provinceColors, provinceColors) ||
        !mapEquals(oldDelegate.unitPositions, unitPositions) ||
        oldDelegate.activeOrderUnitProvince != activeOrderUnitProvince ||
        !setEquals(oldDelegate.validTargetProvinces, validTargetProvinces) ||
        oldDelegate.paths != paths;
  }
}
