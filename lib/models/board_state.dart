import 'package:flutter/material.dart';

/// Turns a game-state (or preview-state) payload into the maps `MapViewer`
/// paints with.
///
/// Unit, label and supply-centre positions are DB-owned at runtime: the
/// server serializes `Province.label_x/y` and each unit's `unit_x/unit_y`
/// straight from the database (game/api/serializers.py), and the map SVG's
/// own `<text>` / unit markup only seeds those columns on the very first
/// `import_map`. So this file never reads coordinates out of the SVG — it
/// only reads them off the payload, and both `GameScreen` (live games, with
/// history-mode payloads that lack `my_orders`/`is_mine`/a `phase`) and
/// `GamePreviewScreen` (a lobby preview, which never has any of those either)
/// share the same reading of it. Supply-centre marker positions are not
/// computed here at all — `MapViewer` self-parses those from the SVG's own
/// `<g id="supply-centers">`.
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
}
