import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback, rootBundle;
import 'package:xml/xml.dart';
import 'package:path_drawing/path_drawing.dart';
import '../theme/app_theme.dart';
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

  /// Every `data-adj*` attribute this province's SVG node carries — `data-adj`
  /// itself, `data-adj-river` (fleet edges across a river mouth), and any
  /// `data-adj-<coast>` (split-coast fleet edges), each already split on
  /// whitespace — keyed by the full attribute name. `reachability.dart`'s
  /// `adjListOf(code, attr)` reads straight out of this instead of the widget
  /// re-parsing the SVG per lookup, mirroring `orders_ui.js`'s `adjListOf`,
  /// which reads the live DOM node directly. [adjacencies] is exactly
  /// `adjAttrs['data-adj']`, kept as its own field only because it predates
  /// this map; nothing in this codebase reads [adjacencies] any more.
  final Map<String, List<String>> adjAttrs;

  ProvinceData({
    required this.id,
    required this.type,
    required this.adjacencies,
    required this.path,
    required this.cssClass,
    this.adjAttrs = const {},
  });
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

/// One province-code label baked into the SVG's `g#labels`: the code, the
/// position the map author drew it at, and its class (`lbl-sea` / `lbl-land`
/// — the sea/land distinction has no DB equivalent, so the SVG is the only
/// source for it). `MapPainter` overrides the position with
/// `labelPositions[code]` when the DB has moved it, the same precedence
/// `applyLabelPositions` uses in the Mini App, but always keeps the class.
///
/// Kept as a list, not a `Map<String, MapLabel>`: a split-coast province can
/// carry two `<text>` nodes sharing one code, and a map keyed by code would
/// silently drop one of them.
class MapLabel {
  final String code;
  final Offset position;
  final String cssClass;

  const MapLabel({required this.code, required this.position, required this.cssClass});
}

/// Cartography ink for a province-code label, mirroring the `.lbl-sea` /
/// `.lbl-land` rules every shipped map's `<style>` block defines. This is the
/// map author's ink, not UI chrome, so — like `_neutralStyles` and the
/// supply-centre red below — it deliberately does not live in `AppColors`.
const Map<String, TextStyle> _labelStyles = {
  'lbl-sea': TextStyle(color: Color(0xFF1A4A6A), fontSize: 11, fontStyle: FontStyle.italic, fontFamily: 'serif'),
  'lbl-land': TextStyle(color: Color(0xFF222222), fontSize: 11, fontWeight: FontWeight.bold),
};

/// One unit already resolved from a province code to what the painter needs
/// to draw it: its own screen position (unit_x/unit_y, the label+16
/// fallback, or a coast-specific position — all the caller's job, since only
/// the caller knows province codes), which icon to pick, its owner's colour,
/// and whether it is mid-retreat.
///
/// Distinct from [MapViewer.unitPositions]/[MapViewer.unitColors] — the flat
/// maps every caller still passes today. Those carry no type or dislodged
/// state at all, which is exactly T04's problem, so [MapPainter] only draws
/// real army/fleet icons once a caller supplies this list; until
/// `game_screen.dart`/`preview_screen.dart` are wired to build one, it keeps
/// drawing the old flat dot from the flat maps below rather than guess a
/// shape from data that was never sent.
class MapUnit {
  final String province;

  /// 'army' or 'fleet'; anything else is treated as an army so a payload
  /// with an unrecognised value still gets *a* shape.
  final String type;
  final Offset position;
  final Color color;
  final bool isDislodged;

  const MapUnit({
    required this.province,
    required this.type,
    required this.position,
    required this.color,
    this.isDislodged = false,
  });

  @override
  bool operator ==(Object other) =>
      other is MapUnit &&
      other.province == province &&
      other.type == type &&
      other.position == position &&
      other.color == color &&
      other.isDislodged == isDislodged;

  @override
  int get hashCode => Object.hash(province, type, position, color, isDislodged);
}

/// One army/fleet icon's paths, parsed once per map from the bundled
/// `assets/maps/units/<kind>_<suffix>.svg` — mirrors the Mini App's
/// `loadUnitIcons`/`makeUnitGroup`. `filled` mirrors the source SVG's own
/// `class="fill"` (painted in the empire colour, with a dark outline) versus
/// `class="stroke"` (outline-only linework); together they turn a flat
/// two-tone icon into the layered look the source art is authored with.
class UnitIcon {
  final Size viewBox;
  final List<(Path path, bool filled)> paths;

  const UnitIcon(this.viewBox, this.paths);
}

/// Per-map unit icon suffix, keyed by the SVG's own untranslated basename
/// (e.g. `diplomacy_classic`) rather than `map.js`'s `guessUnitSuffix`, which
/// keys off the *English* map name. `game/api/serializers.py` sends that name
/// untranslated for a live game but translated for a preview (T04's risk
/// note), so keying off the SVG basename — always untranslated, since
/// `_map_svg_url` always builds it from the file name — is the one lookup
/// that works for both. A slug this table doesn't recognise falls back to
/// itself with underscores stripped, then to `classic` if that file doesn't
/// exist either (`_tryLoadUnitIcon`).
const Map<String, String> _unitIconSuffixByMapSlug = {
  'diplomacy_classic': 'classic',
  'cold_war': 'coldwar',
  'ancient_med': 'ancientmed',
  'hundred': 'hundred',
  'canton': 'canton',
  'known_world_901': 'knownworld901',
  'south_america': 'southamerica',
  'north_america': 'northamerica',
};

/// Target icon size in SVG (map) pixels, ported from `map.js`'s
/// `UNIT_SIZES` and keyed the same way as the suffix table above. Ranges
/// from 22px (Known World 901, 269 provinces) to 50px (Hundred Years War) —
/// a fixed size swamps the small maps and vanishes on the big one.
const Map<String, double> _unitIconSizeByMapSlug = {
  'diplomacy_classic': 44,
  'europe_duel': 44,
  'europe_extended': 44,
  'cold_war': 44,
  'ancient_med': 44,
  'hundred': 50,
  'canton': 36,
  'known_world_901': 22,
  'north_america': 33,
  'south_america': 44,
};

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

  /// Units ready to draw as real army/fleet tokens, with position, type,
  /// colour and dislodged state already resolved by the caller. See
  /// [MapUnit] for why this is a separate list rather than more flat maps.
  final List<MapUnit> units;

  /// The untranslated SVG basename (e.g. `diplomacy_classic`) — used only to
  /// pick the right per-map unit icon set and size (see
  /// `_unitIconSuffixByMapSlug`/`_unitIconSizeByMapSlug`). Deliberately not
  /// the payload's `map_name`: that field is translated on the preview
  /// endpoint but not the live one, so keying icon lookup off it would
  /// silently fall back to `classic` for every non-English preview.
  final String? mapSlug;

  final List<Order> orders;

  /// True when [orders] came from a resolved history phase rather than the
  /// live board — forwarded to [OrderArrowsPainter] so it knows whether
  /// `Order.result` means anything yet (see its `history` field doc).
  final bool ordersFromHistory;

  final Function(String) onProvinceTapped;

  /// Fired on a long-press that lands inside a province, resolved with the
  /// same `_paths` hit test [_handleTap] uses. Null (the default) omits the
  /// long-press recognizer entirely rather than adding one that always
  /// no-ops — callers with nothing to show (none today) don't pay for the
  /// extra entry in the gesture arena.
  final void Function(String provinceCode)? onProvinceLongPressed;

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
    this.units = const [],
    this.mapSlug,
    this.orders = const [],
    this.ordersFromHistory = false,
    required this.onProvinceTapped,
    this.onProvinceLongPressed,
    this.onSvgParsed,
    this.activeOrderUnitProvince,
    this.validTargetProvinces = const {},
    this.isReadOnly = false,
  });

  @override
  State<MapViewer> createState() => _MapViewerState();
}

/// A [LongPressGestureRecognizer] that rejects itself the instant a second
/// pointer joins, instead of Flutter's default of quietly tracking only the
/// first ("primary") pointer and ignoring the rest.
///
/// That default is the actual bug behind T19's defect 1: the recognizer's
/// deadline timer is armed once, for the first pointer, and fires
/// unconditionally 600ms later regardless of what else has touched down
/// since. `GestureRecognizer.resolve()` settles every arena the recognizer is
/// still a member of — both pointers' arenas once a second finger has
/// arrived — so that unconditional `resolve(accepted)` doesn't just fire the
/// toast, it evicts every other recognizer sharing either pointer's arena,
/// including `InteractiveViewer`'s own pinch recognizer. A pinch that was
/// mid-gesture is left with no recognizer to finish it, which is why a slow
/// two-finger spread was losing its zoom entirely, not just gaining a stray
/// toast. Rejecting outright on the second pointer, before either arena has
/// a chance to resolve in this recognizer's favour, hands both pointers back
/// to `InteractiveViewer` immediately — mirroring `map.js`'s `setupPanZoom`,
/// which only arms its long-press timer while `pointers.size === 1`.
class _SinglePointerLongPressRecognizer extends LongPressGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    final isFirstPointer = state == GestureRecognizerState.ready;
    super.addAllowedPointer(event);
    if (!isFirstPointer) {
      resolve(GestureDisposition.rejected);
    }
  }
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
  // Province-code labels baked into the SVG's own `g#labels` — parsed once
  // per SVG alongside everything else in `_parseSvg`, same reasoning as
  // `_svgScPositions`: the sea/land distinction (`cssClass`) has no DB
  // equivalent, so this widget is the only source for it.
  final List<MapLabel> _svgLabels = [];
  Size _mapSize = const Size(1000, 1000); // Default, updated on parse

  // Unit icon paths for the current `widget.mapSlug`, loaded lazily from the
  // bundled per-map SVGs and cached here so sixteen small files are parsed
  // once per map open, not once per frame. Null after a failed load (or
  // before the first load completes) — `MapPainter` falls back to the
  // lettered circle in that case.
  UnitIcon? _armyIcon;
  UnitIcon? _fleetIcon;
  // The slug `_armyIcon`/`_fleetIcon` were loaded for, so `_ensureUnitIcons`
  // can tell "loaded for null (no slug given, using classic)" apart from
  // "never loaded yet" — both would otherwise look like `_iconsLoadedForSlug
  // == null`.
  bool _iconsLoadedOnce = false;
  String? _iconsLoadedForSlug;

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
    _ensureUnitIcons();
  }

  @override
  void didUpdateWidget(covariant MapViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.svgString != widget.svgString) {
      _parseSvg().then((_) {
        if (mounted) setState(() {});
      });
    }
    if (oldWidget.mapSlug != widget.mapSlug) {
      _ensureUnitIcons();
    }
  }

  // Loads (and caches) the army/fleet icon set for `widget.mapSlug`. A no-op
  // once already loaded for that slug — safe to call from both `initState`
  // and `didUpdateWidget` unconditionally.
  Future<void> _ensureUnitIcons() async {
    final slug = widget.mapSlug;
    if (_iconsLoadedOnce && _iconsLoadedForSlug == slug) return;
    final suffix = slug != null ? (_unitIconSuffixByMapSlug[slug] ?? slug.replaceAll('_', '')) : 'classic';
    final army = await _loadUnitIcon('army', suffix);
    final fleet = await _loadUnitIcon('fleet', suffix);
    if (!mounted) return;
    setState(() {
      _armyIcon = army;
      _fleetIcon = fleet;
      _iconsLoadedForSlug = slug;
      _iconsLoadedOnce = true;
    });
  }

  // Mirrors `loadUnitIcons`'s `load()`: try the map-specific file, and if it
  // is missing or fails to parse, fall back to the classic pair rather than
  // leave the unit with no icon at all.
  Future<UnitIcon?> _loadUnitIcon(String kind, String suffix) async {
    final direct = await _tryLoadUnitIcon(kind, suffix);
    if (direct != null) return direct;
    if (suffix == 'classic') return null;
    return _tryLoadUnitIcon(kind, 'classic');
  }

  Future<UnitIcon?> _tryLoadUnitIcon(String kind, String suffix) async {
    try {
      final raw = await rootBundle.loadString('assets/maps/units/${kind}_$suffix.svg');
      final document = XmlDocument.parse(raw);
      final svgElement = document.findAllElements('svg').first;
      var viewBox = const Size(44, 24);
      final viewBoxAttr = svgElement.getAttribute('viewBox');
      if (viewBoxAttr != null) {
        final parts = viewBoxAttr.split(RegExp(r'\s+'));
        if (parts.length >= 4) {
          viewBox = Size(double.parse(parts[2]), double.parse(parts[3]));
        }
      }
      final paths = <(Path, bool)>[];
      for (final element in document.findAllElements('path')) {
        final d = element.getAttribute('d');
        if (d == null) continue;
        final cssClass = element.getAttribute('class') ?? '';
        paths.add((parseSvgPathData(d), cssClass.contains('fill')));
      }
      if (paths.isEmpty) return null; // parser error or empty SVG
      return UnitIcon(viewBox, paths);
    } catch (_) {
      return null;
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
    final svgLabels = <MapLabel>[];
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

      // Province-code labels the map author drew — the only source for a
      // province the DB has never carried a `label_x`/`label_y` for. Read as
      // a flat list, not a map: a split-coast province (T05's own risk note)
      // can carry two `<text>` nodes sharing one code, and folding them into
      // a `Map<String, MapLabel>` would silently drop one.
      final gLabels = document.findAllElements('g').where((e) => e.getAttribute('id') == 'labels').firstOrNull;
      if (gLabels != null) {
        for (final text in gLabels.findAllElements('text')) {
          final code = text.innerText.trim();
          final x = double.tryParse(text.getAttribute('x') ?? '');
          final y = double.tryParse(text.getAttribute('y') ?? '');
          if (code.isEmpty || x == null || y == null) continue;
          svgLabels.add(MapLabel(code: code, position: Offset(x, y), cssClass: text.getAttribute('class') ?? 'lbl-land'));
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
          // Every data-adj* attribute this node carries (data-adj itself,
          // data-adj-river, and any per-coast data-adj-nc/sc/ec/wc), not just
          // the plain one — reachability.dart's fleet-edge and split-coast
          // rules need the whole set (T18).
          final adjAttrs = <String, List<String>>{};
          for (final attribute in element.attributes) {
            final name = attribute.name.local;
            if (!name.startsWith('data-adj')) continue;
            final value = attribute.value.trim();
            adjAttrs[name] = value.isNotEmpty ? value.split(RegExp(r'\s+')) : const [];
          }
          provinceDataMap[id] = ProvinceData(
            id: id,
            type: type,
            adjacencies: adjacencies,
            path: path,
            cssClass: cssClass,
            adjAttrs: adjAttrs,
          );
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
    _svgLabels
      ..clear()
      ..addAll(svgLabels);
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

  // Deliberately not gated on `widget.isReadOnly` — that flag only guards
  // giving orders, and reading a province's name is exactly as safe on the
  // read-only lobby preview as on a live board (arguably more useful there:
  // T19's whole premise is a new player learning an unfamiliar map before
  // they've joined). `details.localPosition` is already in map space here,
  // the same as `_handleTap`'s: this recognizer sits inside
  // `InteractiveViewer` as a sibling of the `SizedBox` the paths are
  // defined against, so Flutter's hit-testing has already undone the pan/
  // zoom transform by the time this callback runs.
  //
  // No pointer-count check here: by the time `onLongPressStart` ever fires,
  // `_SinglePointerLongPressRecognizer` has already guaranteed a second
  // pointer never let it win the arena, so there is nothing left to check.
  void _handleLongPress(LongPressStartDetails details) {
    final callback = widget.onProvinceLongPressed;
    if (callback == null) return;
    for (final entry in _paths.entries) {
      if (entry.value.contains(details.localPosition)) {
        HapticFeedback.mediumImpact();
        callback(entry.key);
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
          child: RawGestureDetector(
            // A plain `GestureDetector` can only ever hand out its own stock
            // `LongPressGestureRecognizer`, which is exactly the one with
            // the two-pointer bug `_SinglePointerLongPressRecognizer` exists
            // to fix — so tap and long-press are wired up here by hand
            // instead, one recognizer factory each, rather than through
            // `GestureDetector`'s `onTapUp`/`onLongPressStart` shorthand.
            gestures: {
              TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                () => TapGestureRecognizer(),
                (recognizer) => recognizer.onTapUp = _handleTap,
              ),
              // Only registered when there is a callback to fire — see
              // [MapViewer.onProvinceLongPressed]'s doc for why a caller
              // with nothing to show doesn't pay for the extra arena entry.
              if (widget.onProvinceLongPressed != null)
                _SinglePointerLongPressRecognizer: GestureRecognizerFactoryWithHandlers<_SinglePointerLongPressRecognizer>(
                  () => _SinglePointerLongPressRecognizer(),
                  (recognizer) => recognizer.onLongPressStart = _handleLongPress,
                ),
            },
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
                    svgLabels: _svgLabels,
                    // A caller-supplied position list wins exclusively over
                    // the SVG's own circles once it is non-empty — a DB that
                    // has dropped a supply centre must be able to remove the
                    // dot, which a plain merge could never do. Only when the
                    // caller has passed nothing at all (still true of both
                    // `game_screen.dart` and `preview_screen.dart` today) does
                    // this fall back to what the SVG was authored with.
                    scPositions: widget.scPositions.isNotEmpty ? widget.scPositions : _svgScPositions,
                    unitPositions: widget.unitPositions,
                    unitColors: widget.unitColors,
                    units: widget.units,
                    armyIcon: _armyIcon,
                    fleetIcon: _fleetIcon,
                    unitIconSize: widget.mapSlug != null ? (_unitIconSizeByMapSlug[widget.mapSlug] ?? 22) : 22,
                    activeOrderUnitProvince: widget.activeOrderUnitProvince,
                    validTargetProvinces: widget.validTargetProvinces,
                    // The selection stroke is the design system's single
                    // accent (AppColors.of(context).accent, patina teal
                    // 0xFF7CDED8) — never re-inline that hex in a screen or
                    // a painter.
                    selectionColor: AppColors.of(context).accent,
                  ),
                  // Deliberately a `foregroundPainter`, not folded into
                  // `MapPainter`: an order arrow originates AT a unit token
                  // (or a label anchor, for a target with no unit) and has to
                  // stay legible drawn over it, an SC dot, and a province
                  // label alike — the same reason `arrows_overlay.js`'s SVG
                  // group is appended after `drawUnits()`/`drawSupplyCenters()`
                  // in the Mini App, putting arrows last in paint order there
                  // too.
                  foregroundPainter: OrderArrowsPainter(widget.orders,
                      history: widget.ordersFromHistory),
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
  final List<MapLabel> svgLabels;
  final Map<String, Offset> scPositions;
  final Map<String, Offset> unitPositions;
  final Map<String, Color> unitColors;
  final List<MapUnit> units;
  final UnitIcon? armyIcon;
  final UnitIcon? fleetIcon;
  final double unitIconSize;
  final String? activeOrderUnitProvince;
  final Set<String> validTargetProvinces;

  /// The design system's single accent, used for the 3px selection stroke
  /// (T18). Required, with no default — the one construction site always
  /// passes `AppColors.of(context).accent`, and a painter must never inline
  /// its own guess at the value (a stale note once called this colour brass;
  /// it's patina teal, `0xFF7CDED8`).
  final Color selectionColor;

  MapPainter({
    required this.neutralShapes,
    required this.paths,
    required this.provinceClasses,
    required this.parseGeneration,
    required this.provinceColors,
    required this.labelPositions,
    this.svgLabels = const [],
    required this.scPositions,
    required this.unitPositions,
    this.unitColors = const {},
    this.units = const [],
    this.armyIcon,
    this.fleetIcon,
    this.unitIconSize = 22,
    this.activeOrderUnitProvince,
    required this.validTargetProvinces,
    required this.selectionColor,
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

    // 2. Draw labels. Base position and style come from the SVG's own
    // `g#labels` — so every province the map author labelled gets a code
    // even if the DB has never touched it — overridden by
    // `labelPositions[code]` when the DB has moved it, the same precedence
    // `applyLabelPositions` uses in the Mini App. A DB code with no matching
    // SVG `<text>` (e.g. a province the admin renamed) still gets drawn,
    // using the land style, since sea/land is SVG-only information.
    final labelledCodes = <String>{};
    for (final label in svgLabels) {
      labelledCodes.add(label.code);
      final position = labelPositions[label.code] ?? label.position;
      _drawLabel(canvas, label.code, position, _labelStyles[label.cssClass] ?? _labelStyles['lbl-land']!);
    }
    for (final entry in labelPositions.entries) {
      if (labelledCodes.contains(entry.key)) continue;
      _drawLabel(canvas, entry.key, entry.value, _labelStyles['lbl-land']!);
    }

    // 3. Draw supply centres — after the province fills so the dot always
    // reads against finished terrain, and before the unit tokens below so an
    // occupied centre reads as "a unit standing on a centre" rather than the
    // token being punched through by the dot. Colour and shape mirror the
    // Mini App's `drawSupplyCenters` and every shipped map's own `.sc` style;
    // this is cartography ink, not UI state, hence the literal hex instead of
    // `AppColors` (same reasoning as `_neutralStyles` and the label styles
    // above).
    for (final offset in scPositions.values) {
      _drawSupplyCentre(canvas, offset);
    }

    // 4. Draw units. A caller that has resolved real `MapUnit`s (type,
    // dislodged state, coast already worked out) gets real army/fleet icons
    // in its empire's colour; a caller that has only handed over the flat
    // `unitPositions`/`unitColors` maps — every caller today — still gets the
    // plain dot, since guessing a shape from data that was never sent would
    // be actively misleading, not a fix.
    if (units.isNotEmpty) {
      _drawUnitTokens(canvas);
    } else {
      _drawLegacyUnitDots(canvas);
    }

    // 5. Draw the dim veil, then the selection stroke on top of it.
    if (activeOrderUnitProvince != null) {
      // Pad the dim rect (and the saveLayer it's drawn into) by the map's
      // own width/height in every direction, mirroring orders_ui.js's
      // applyDimOverlay — it pads by max(bbox.w, bbox.h, 1000) so the veil
      // never falls short when the SVG is panned. The outer clipRect above
      // already bounds this whole canvas to exactly `size` (this CustomPaint
      // IS the map, panned/zoomed as one texture by the InteractiveViewer
      // around it, not scrolled within a larger canvas), so today nothing
      // outside `size` is ever visible — this padding is defence-in-depth
      // against that invariant changing, at the cost of one oversized rect.
      final pad = (size.width > size.height ? size.width : size.height)
          .clamp(1000.0, double.infinity);
      final dimRect = Rect.fromLTRB(-pad, -pad, size.width + pad, size.height + pad);
      canvas.saveLayer(dimRect, Paint());

      canvas.drawRect(dimRect, Paint()..color = Colors.black54);

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

      // Accent selection stroke on the acting unit's own province, drawn
      // AFTER the dim layer (not punched into it) so the selected province
      // reads as visually distinct from an ordinary un-dimmed legal target —
      // mirrors orders_ui.js's `.prov-selected` rule (mini_app.css), which
      // is the only thing that told the two apart there too.
      final selectedPath = paths[activeOrderUnitProvince];
      if (selectedPath != null) {
        canvas.drawPath(
          selectedPath,
          Paint()
            ..color = selectionColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
    }
  }

  void _drawLabel(Canvas canvas, String code, Offset position, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: code, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(position.dx - textPainter.width / 2, position.dy - textPainter.height / 2));
  }

  void _drawSupplyCentre(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 6, Paint()..color = const Color(0xFFCC0000));
    canvas.drawCircle(
      center,
      6,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );
  }

  // The pre-T04 rendering: an identical dot for every unit, coloured by its
  // owner (or, failing that, by the province's own supply-centre tint).
  // Still the only option when the caller hasn't resolved a `MapUnit` list —
  // see the comment above `_drawUnitTokens`'s call site.
  void _drawLegacyUnitDots(Canvas canvas) {
    for (final entry in unitPositions.entries) {
      final provinceId = entry.key;
      final offset = entry.value;
      // A unit's own colour comes from ITS owner, not the province's supply-
      // center tint — those differ whenever a unit sits in a non-SC province,
      // or holds a center a different empire currently owns.
      final color = unitColors[provinceId] ?? provinceColors[provinceId] ?? Colors.grey;

      canvas.drawCircle(offset, 10, Paint()..color = color..style = PaintingStyle.fill);
      canvas.drawCircle(
        offset,
        10,
        Paint()
          ..color = Colors.black
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke,
      );
    }
  }

  // Real army/fleet icons, scaled to this map's own unit size and recoloured
  // to each unit's empire — mirrors `makeUnitGroup`. Icons already scale with
  // zoom for free: they're drawn in the same map-space coordinates as
  // everything else on this canvas, and `InteractiveViewer` scales the whole
  // `CustomPaint` as one unit, not this painter's pixels individually.
  void _drawUnitTokens(Canvas canvas) {
    for (final unit in units) {
      final icon = unit.type == 'fleet' ? fleetIcon : armyIcon;
      if (icon == null) {
        _drawLetteredUnit(canvas, unit);
        continue;
      }

      final scale = unitIconSize / (icon.viewBox.width > icon.viewBox.height ? icon.viewBox.width : icon.viewBox.height);
      final opacity = unit.isDislodged ? 0.55 : 1.0;

      // Dashed halo only for a dislodged unit — visually flags the emergency
      // retreat state, matching `makeUnitGroup`'s own halo (and its opacity,
      // since the JS applies 0.55 to the whole unit group, halo included).
      if (unit.isDislodged) {
        final haloPath = dashPath(
          Path()..addOval(Rect.fromCircle(center: unit.position, radius: 14 * (unitIconSize / 22))),
          dashArray: CircularIntervalList<double>(const [3, 2]),
        );
        canvas.drawPath(
          haloPath,
          Paint()
            ..color = const Color(0xFFB03030).withOpacity(opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      canvas.save();
      canvas.translate(
        unit.position.dx - icon.viewBox.width * scale / 2,
        unit.position.dy - icon.viewBox.height * scale / 2,
      );
      canvas.scale(scale);
      for (final (path, filled) in icon.paths) {
        // `class="fill"` → paint in the empire colour, with the icon's own
        // dark outline. `class="stroke"` → that outline IS the whole path,
        // with no fill underneath it — mirrors `makeUnitGroup`'s two
        // branches without a separate code path per class.
        if (filled) {
          canvas.drawPath(path, Paint()..style = PaintingStyle.fill..color = unit.color.withOpacity(opacity));
        }
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFF1F2A36).withOpacity(opacity),
        );
      }
      canvas.restore();
    }
  }

  // Fallback for when an icon failed to load (or hasn't finished loading
  // yet): the old flat dot, but sized by this map's own unit size and
  // labelled A/F so it is at least informative — mirrors `makeUnitGroup`'s
  // own `if (!icon)` branch, including the smaller radius for a dislodged
  // unit (there is no halo in this branch in the Mini App either).
  void _drawLetteredUnit(Canvas canvas, MapUnit unit) {
    final r = (unit.isDislodged ? 6.0 : 9.0) * (unitIconSize / 22);
    canvas.drawCircle(unit.position, r, Paint()..color = unit.color);
    canvas.drawCircle(
      unit.position,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF1A1A2E),
    );
    final textPainter = TextPainter(
      text: TextSpan(
        text: unit.type == 'fleet' ? 'F' : 'A',
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, unit.position - Offset(textPainter.width / 2, textPainter.height / 2));
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
        !listEquals(oldDelegate.units, units) ||
        oldDelegate.armyIcon != armyIcon ||
        oldDelegate.fleetIcon != fleetIcon ||
        oldDelegate.unitIconSize != unitIconSize ||
        !mapEquals(oldDelegate.labelPositions, labelPositions) ||
        !mapEquals(oldDelegate.scPositions, scPositions) ||
        oldDelegate.activeOrderUnitProvince != activeOrderUnitProvince ||
        oldDelegate.selectionColor != selectionColor ||
        !setEquals(oldDelegate.validTargetProvinces, validTargetProvinces);
  }
}
