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

class MapViewer extends StatefulWidget {
  final String svgString;
  final Map<String, Color> provinceColors;
  final Map<String, Offset> labelPositions;
  final Map<String, Offset> scPositions;
  final Map<String, Offset> unitPositions;
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
                paths: _paths,
                provinceColors: widget.provinceColors,
                labelPositions: widget.labelPositions,
                scPositions: widget.scPositions,
                unitPositions: widget.unitPositions,
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
  final Map<String, Path> paths;
  final Map<String, Color> provinceColors;
  final Map<String, Offset> labelPositions;
  final Map<String, Offset> scPositions;
  final Map<String, Offset> unitPositions;
  final String? activeOrderUnitProvince;
  final Set<String> validTargetProvinces;

  MapPainter({
    required this.paths,
    required this.provinceColors,
    required this.labelPositions,
    required this.scPositions,
    required this.unitPositions,
    this.activeOrderUnitProvince,
    required this.validTargetProvinces,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Provinces
    for (final entry in paths.entries) {
      final provinceId = entry.key;
      final path = entry.value;

      final paint = Paint()
        ..color = provinceColors[provinceId] ?? Colors.white
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
      final color = provinceColors[provinceId] ?? Colors.grey;
      
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
