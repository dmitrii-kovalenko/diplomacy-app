import 'package:flutter/material.dart';

import '../blocs/game/order_bloc.dart' show kUnitFleet;
import '../widgets/map_viewer.dart' show MapUnit;

/// Turns a game-state (or preview-state) payload into the maps `MapViewer`
/// paints with.
///
/// Unit, label and supply-centre positions are DB-owned at runtime: the
/// server serializes `Province.label_x/y`, each unit's `unit_x/unit_y` and
/// each supply centre's `sc_x/sc_y` straight from the database
/// (game/api/serializers.py), and the map SVG's own `<text>` / `<circle
/// class="sc">` / unit markup only seed those columns on the very first
/// `import_map`. So this file never reads coordinates out of the SVG — it
/// only reads them off the payload, and both `GameScreen` (live games, with
/// history-mode payloads that lack `my_orders`/`is_mine`/a `phase`, and whose
/// `sc_ownership` rows lack `is_supply_center`/`sc_x`/`sc_y` entirely — see
/// [scPositions]) and `GamePreviewScreen` (a lobby preview, which never has
/// any of those either) share the same reading of it. `MapViewer` still
/// falls back to self-parsing supply-centre positions from the SVG's own
/// `<g id="supply-centers">`, but only when a caller passes it nothing — the
/// preview screen's own game-not-started case, per T03.
class BoardState {
  const BoardState._();

  /// Starting/current supply-centre ownership paint, keyed by province code.
  ///
  /// Takes the raw `sc_ownership` and `empires` lists rather than a whole
  /// game-state map: a history-mode row has neither `sc_x`/`sc_y` nor
  /// `is_supply_center`, and empire colours never come from the history
  /// payload even when the ownership list does, so the caller — not this
  /// function — decides which payload each list comes from.
  static Map<String, Color> provinceColors({
    required List<dynamic> scOwnership,
    required List<dynamic> empires,
  }) {
    final Map<String, Color> empireColors = {};
    for (final e in empires) {
      final code = e['code'] as String?;
      final colorStr = e['color'] as String?;
      if (code != null && colorStr != null) {
        if (colorStr.startsWith('#') && colorStr.length == 7) {
          final hex = colorStr.substring(1);
          empireColors[code] = Color(int.parse('0xFF$hex')).withOpacity(0.55);
        }
      }
    }

    final Map<String, Color> colors = {};
    for (final sc in scOwnership) {
      final prov = sc['province_code'] as String?;
      final emp = sc['empire_code'] as String?;
      if (prov != null && emp != null && empireColors.containsKey(emp)) {
        colors[prov] = empireColors[emp]!;
      }
    }
    return colors;
  }

  /// Province-code label anchors, from the payload's `label_positions`
  /// ({code: [x, y]}) rather than the SVG's own baked-in `<text>` elements —
  /// labels are static per map, so a live payload, a history payload and a
  /// preview payload all carry the same shape for this field.
  static Map<String, Offset> labelPositions(Map<String, dynamic>? raw) {
    if (raw == null) return {};
    final positions = <String, Offset>{};
    for (final entry in raw.entries) {
      final xy = entry.value as List<dynamic>?;
      if (xy != null && xy.length == 2) {
        final x = (xy[0] as num?)?.toDouble();
        final y = (xy[1] as num?)?.toDouble();
        if (x != null && y != null) positions[entry.key] = Offset(x, y);
      }
    }
    return positions;
  }

  /// Supply-centre marker positions, from `sc_ownership` rows the payload
  /// already ships (`game/api/serializers.py`'s `"sc_ownership"`), keeping
  /// only real supply centres with both coordinates set — mirrors the Mini
  /// App's `drawSupplyCenters`, which likewise skips a row whose
  /// `is_supply_center` is false rather than drawing a dot for every
  /// province the map file ever marked as one. `GameScreen`'s history-mode
  /// rows carry neither field at all (`_last_phase_payload` sends only
  /// `province_code`/`empire_code`), so this must always read off the live
  /// state, never `_historyPhase` — the caller's job, since only it knows
  /// which payload is which.
  static Map<String, Offset> scPositions(List<dynamic> scOwnership) {
    final positions = <String, Offset>{};
    for (final sc in scOwnership) {
      if (sc['is_supply_center'] != true) continue;
      final province = sc['province_code'] as String?;
      final x = (sc['sc_x'] as num?)?.toDouble();
      final y = (sc['sc_y'] as num?)?.toDouble();
      if (province == null || x == null || y == null) continue;
      positions[province] = Offset(x, y);
    }
    return positions;
  }

  /// Where each unit token sits, and what colour it should be — both come
  /// from the `units` list's own `unit_x`/`unit_y`/`color` fields, not from
  /// supply-centre ownership: a unit's position and its owner's colour are
  /// per-unit facts, unrelated to who (if anyone) holds the province as a
  /// supply center.
  ///
  /// Every row this function reads is shared by all three payload shapes: a
  /// live game's `units`, a history phase's unit rows (no `is_mine`, no
  /// `id`, but the same `color` per row per game/api/serializers.py
  /// `_last_phase_payload`), and a preview's one row per
  /// `EmpireStartingUnit`.
  ///
  /// Kept alongside [units] below rather than replaced by it: `GameScreen`
  /// still needs one position per province code (not a list of [MapUnit]s)
  /// to anchor order arrows in `_buildOrderArrows`, and an arrow's source is
  /// "wherever the acting unit visibly is" — a lookup this flat map already
  /// answers — not something T04 needs to touch.
  static (Map<String, Offset>, Map<String, Color>) unitPositionsAndColors(
    List<dynamic> units,
  ) {
    final positions = <String, Offset>{};
    final colors = <String, Color>{};
    for (final u in units) {
      final province = u['province_code'] as String?;
      if (province == null) continue;
      final x = (u['unit_x'] as num?)?.toDouble();
      final y = (u['unit_y'] as num?)?.toDouble();
      if (x != null && y != null) positions[province] = Offset(x, y);
      final colorStr = u['color'] as String?;
      if (colorStr != null &&
          colorStr.startsWith('#') &&
          colorStr.length == 7) {
        colors[province] = Color(int.parse('0xFF${colorStr.substring(1)}'));
      }
    }
    return (positions, colors);
  }

  /// Per-province coast pixel nudges, ported verbatim from `map.js`'s
  /// `COAST_OFFSETS` — tuned by hand for the classic map (STP/NC sits far up
  /// in the Barents, SPA/NC over Gascony, BUL/EC over the Black Sea) with
  /// generic 26px nudges as the default for any other map's split coasts.
  /// Only consulted once [_unitCenter] has no absolute `coast_positions`
  /// entry to use instead — an admin-set absolute position always wins.
  static const Map<String, (double, double)> _coastOffsets = {
    'STPNC': (-2, -217), 'STPSC': (8, 34),
    'SPANC': (-12, -55), 'SPASC': (8, 72),
    'BULEC': (52, -16), 'BULSC': (38, 36),
  };

  static Offset _coastOffset(String provinceCode, String coast) {
    if (coast.isEmpty) return Offset.zero;
    final tuned = _coastOffsets['$provinceCode${coast.toUpperCase()}'];
    if (tuned != null) return Offset(tuned.$1, tuned.$2);
    switch (coast.toUpperCase()) {
      case 'NC':
        return const Offset(0, -26);
      case 'SC':
        return const Offset(0, 26);
      case 'EC':
        return const Offset(26, 0);
      case 'WC':
        return const Offset(-26, 0);
      default:
        return Offset.zero;
    }
  }

  /// One unit row's screen position, mirroring `map.js`'s `unitCenter()`
  /// precedence exactly: an admin-set absolute `coast_positions[province]
  /// [coast]` wins outright (for a coastless army in a split-coast province,
  /// `army_coasts[province]` picks which coast's absolute position applies);
  /// otherwise `unit_x`/`unit_y` if the admin set them, else the label
  /// position dropped 16px (roughly the middle of the province), with
  /// [_coastOffset]'s per-coast nudge added on top so a split-coast fleet at
  /// least sits apart from its sibling coast even with no admin-tuned
  /// position at all. Returns null when the payload gives nothing to anchor
  /// on — mirrors `drawUnits`' own `if (u.label_x == null) return`, since a
  /// guessed position would be worse than not drawing the unit.
  static Offset? _unitCenter(
    Map<String, dynamic> u,
    Map<String, dynamic> coastPositions,
    Map<String, dynamic> armyCoasts,
  ) {
    final province = u['province_code'] as String? ?? '';
    final coast = (u['coast'] as String?) ?? '';
    final atCoast = coastPositions[province] as Map<String, dynamic>?;

    Offset? absoluteFor(String? key) {
      if (key == null || key.isEmpty) return null;
      final xy = atCoast?[key] as List<dynamic>?;
      if (xy == null || xy.length != 2) return null;
      final x = (xy[0] as num?)?.toDouble();
      final y = (xy[1] as num?)?.toDouble();
      return (x != null && y != null) ? Offset(x, y) : null;
    }

    if (coast.isNotEmpty) {
      final absolute = absoluteFor(coast);
      if (absolute != null) return absolute;
    } else {
      final absolute = absoluteFor(armyCoasts[province] as String?);
      if (absolute != null) return absolute;
    }

    final unitX = (u['unit_x'] as num?)?.toDouble();
    final unitY = (u['unit_y'] as num?)?.toDouble();
    final labelX = (u['label_x'] as num?)?.toDouble();
    final labelY = (u['label_y'] as num?)?.toDouble();
    final cx = unitX ?? labelX;
    final cy = unitY ?? (labelY != null ? labelY + 16 : null);
    if (cx == null || cy == null) return null;
    return Offset(cx, cy) + _coastOffset(province, coast);
  }

  /// The real per-unit list `MapViewer.units` draws army/fleet icons from —
  /// see [MapUnit] and T04. Reads the same `units` rows [unitPositionsAndColors]
  /// does, plus the payload's `coast_positions`/`army_coasts` for
  /// [_unitCenter]'s split-coast handling. `coast_positions`/`army_coasts`
  /// are static per map like `label_positions`, so a `GameScreen` in history
  /// mode passes the live state's copies here, not `_historyPhase`'s (which
  /// carries neither key at all).
  static List<MapUnit> units({
    required List<dynamic> units,
    Map<String, dynamic>? coastPositions,
    Map<String, dynamic>? armyCoasts,
  }) {
    final coastPositionsMap = coastPositions ?? const {};
    final armyCoastsMap = armyCoasts ?? const {};
    final result = <MapUnit>[];
    for (final raw in units) {
      final u = raw as Map<String, dynamic>;
      final province = u['province_code'] as String?;
      if (province == null) continue;
      final position = _unitCenter(u, coastPositionsMap, armyCoastsMap);
      if (position == null) continue;

      Color color = Colors.grey;
      final colorStr = u['color'] as String?;
      if (colorStr != null && colorStr.startsWith('#') && colorStr.length == 7) {
        color = Color(int.parse('0xFF${colorStr.substring(1)}'));
      }

      result.add(MapUnit(
        province: province,
        type: (u['unit_type'] as num?)?.toInt() == kUnitFleet ? 'fleet' : 'army',
        position: position,
        color: color,
        isDislodged: u['is_dislodged'] as bool? ?? false,
      ));
    }
    return result;
  }

  /// The SVG's own untranslated basename (e.g. `diplomacy_classic`), parsed
  /// out of `game.map_svg_url` (`/static/maps/<basename>.svg?v=<mtime>`,
  /// `_map_svg_url` in `serializers.py`) rather than trusting `map_name` —
  /// the live endpoint sends that field untranslated but the preview
  /// endpoint sends it through `str(_(...))`, so keying unit-icon lookup off
  /// `map_name` would silently fall back to the classic icon set for every
  /// non-English player previewing a game (T04's risk note).
  static String? mapSlugFromSvgUrl(String? url) {
    if (url == null) return null;
    final fileName = url.split('?').first.split('/').last;
    if (!fileName.endsWith('.svg')) return null;
    return fileName.substring(0, fileName.length - 4);
  }
}
