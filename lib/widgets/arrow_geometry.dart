/// Arrow geometry, ported from `com.badfrog.conspiracy.app.map.*` (MapSign,
/// Arrow, ArrowAttSupp, ArrowDefSupp, ArrowConv, ArrowConvoyed) in the
/// decompiled Conspiracy APK, via the JS port at
/// `DjangoProject/assets/maps/arrows.js` in the Conspa repo.
///
/// In the original game, arrows are generated geometrically at draw time, not
/// loaded from assets. Each order type renders as a different glyph:
///
///   movePath(from, to)            -> curved cubic with arrowhead
///   attackSupportPath(supp, from, to)
///                                 -> short dashed line from supporter to the
///                                    midpoint of the supported move's curve,
///                                    plus a small circle at that midpoint
///   defenseSupportPath(supp, dest)
///                                 -> curved dashed line plus a square at the
///                                    defended unit
///   convoyedPath([p0, p1, ..., pN])
///                                 -> multi-hop curve through every convoying
///                                    fleet, single arrowhead at the end
///   attackSupportConvoyedPath(supp, chain)
///                                 -> attack-support dashed line pointed at a
///                                    convoyed move's arc instead of a plain
///                                    curve
///
/// Every point is an [Offset] in map space — the same space `MapPainter`
/// paints province geometry in, since `OrderArrowsPainter` is a
/// `foregroundPainter` on the same `CustomPaint`. `scale` defaults to 1
/// (matching what the original game uses at 1:1 zoom; it passes a per-frame
/// scale that grows with map zoom, but this port never rescales the geometry
/// itself — `InteractiveViewer` does the zooming around it — so callers can
/// leave it at the default).
///
/// This file only builds the shapes. Stroke width, colour, dash pattern and
/// opacity are all a rendering decision, made by `order_arrows.dart` — the
/// same split `arrows.js` (geometry) and `arrows_overlay.js` (styling) draw
/// in the Mini App.
library;

import 'dart:math' as math;
import 'dart:ui';

// ---------------------------------------------------------------- constants
// All copied verbatim from MapSign / Arrow* in Java.
const double kRemoveLength = 12.0;
const double kSmallArrowLimit = 45.0;

// Index 0 = short arrows, 1 = normal arrows (matches Java's `c` selector).
const List<(double, double)> kControlPointRatio = [
  (0.30, 0.30),
  (0.30, 0.45),
];
const double kArrowheadLengthDown = 4.5;
const double kArrowheadLengthUp = 1.5;
const double kArrowheadWidth = 4.0;

// Support-arrow specifics.
const double kAttSuppCircleRadius = 7.0; // ArrowAttSupp.CIRCLE_RADIUS_0
const double kDefSuppDiamSize = 11.0; // ArrowDefSupp.DIAM_DIM_0
const double kConvPentLength = 7.5; // ArrowConv.CONV_LENGTH_0
const double kShortRatio = 3.5; // MapSign.SHORT_RATIO (used by DefSupp asymmetric trim)

double _hypotOr1(double dx, double dy) {
  final len = math.sqrt(dx * dx + dy * dy);
  return len == 0 ? 1 : len;
}

/// The endpoints and control points of a cubic-Bezier curve, plus the
/// ready-to-paint [path] itself — callers that need to derive a midpoint,
/// attach an arrowhead, or chain another curve on (as [convoyedPath] does)
/// need the raw points, not just the finished path.
class CurveResult {
  final Offset p1;
  final Offset p2;
  final Offset c1;
  final Offset c2;
  final Path path;
  const CurveResult(this.p1, this.p2, this.c1, this.c2, this.path);
}

/// Core: cubic-Bezier curve between two points, mirroring
/// `MapSign.constructPath`.
CurveResult buildCurve(
  Offset from,
  Offset to, {
  double? trimStart,
  double? trimEnd,
  double scale = 1,
  bool mirror = false,
}) {
  final ts0 = trimStart ?? kRemoveLength;
  final te0 = trimEnd ?? kRemoveLength;

  final dx0 = to.dx - from.dx;
  final dy0 = to.dy - from.dy;
  final len0 = _hypotOr1(dx0, dy0);
  final tx = dx0 / len0;
  final ty = dy0 / len0;

  // Quartic damping for short arrows so trim doesn't eat the whole stroke.
  final short = len0 < kSmallArrowLimit;
  var damp = 1.0;
  if (short) {
    final r = len0 / kSmallArrowLimit;
    damp = r * r * r * r;
  }
  // Java sets `c=1` when short, picks CONTROL_POINT_RATIO[c]; otherwise c=0.
  final ratio = kControlPointRatio[short ? 1 : 0];

  // The Java `z2 = z && dx<0` trick: mirror only applies when going right
  // -to-left. This keeps curves visually consistent regardless of direction.
  final flip = mirror && dx0 < 0;

  // Perpendicular vector. Default is (ty, -tx). When flipped, it's (-ty, tx).
  final px = flip ? -ty : ty;
  final py = flip ? tx : -tx;

  // Endpoint shifts: forward by trim*damp along tangent, perpendicular by
  // (a different) trim*damp. Java uses the same trim for both axes so the
  // start lifts off the unit icon at ~45°.
  final ts = ts0 * scale * damp;
  final te = te0 * scale * damp;
  final p1 = Offset(from.dx + ts * tx + ts * px, from.dy + ts * ty + ts * py);
  final p2 = Offset(to.dx - te * tx + te * px, to.dy - te * ty + te * py);

  // Recompute direction after the shift (length changed).
  final dx = p2.dx - p1.dx;
  final dy = p2.dy - p1.dy;
  final len = _hypotOr1(dx, dy);
  final ux = dx / len;
  final uy = dy / len;
  final qx = flip ? -uy : uy;
  final qy = flip ? ux : -ux;

  final a = ratio.$1 * len; // along tangent
  final b = ratio.$2 * len; // along perpendicular
  final c1 = Offset(p1.dx + a * ux + b * qx, p1.dy + a * uy + b * qy);
  final c2 = Offset(p2.dx - a * ux + b * qx, p2.dy - a * uy + b * qy);

  final path = Path()
    ..moveTo(p1.dx, p1.dy)
    ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);

  return CurveResult(p1, p2, c1, c2, path);
}

/// Cubic Bezier midpoint at t=0.5: (P0 + 3*C1 + 3*C2 + P3) / 8.
/// Used by support arrows to pick where the support line should meet the
/// move.
Offset curveMid(Offset p1, Offset c1, Offset c2, Offset p2) {
  return Offset(
    (p1.dx + 3 * c1.dx + 3 * c2.dx + p2.dx) / 8,
    (p1.dy + 3 * c1.dy + 3 * c2.dy + p2.dy) / 8,
  );
}

/// The two-line arrowhead at [tip], pointing away from [towards] — the
/// curve's second control point, or any point "behind" the tip along the
/// incoming direction.
Path arrowHeadD(Offset tip, Offset towards) {
  final dx = tip.dx - towards.dx;
  final dy = tip.dy - towards.dy;
  final len = _hypotOr1(dx, dy);
  final ax = dx / len;
  final ay = dy / len;
  final px = -ay;
  final py = ax;

  final tipPoint = Offset(tip.dx + kArrowheadLengthUp * ax, tip.dy + kArrowheadLengthUp * ay);
  final base = Offset(tip.dx - kArrowheadLengthDown * ax, tip.dy - kArrowheadLengthDown * ay);
  final left = Offset(base.dx - kArrowheadWidth * px, base.dy - kArrowheadWidth * py);
  final right = Offset(base.dx + kArrowheadWidth * px, base.dy + kArrowheadWidth * py);

  return Path()
    ..moveTo(tipPoint.dx, tipPoint.dy)
    ..lineTo(left.dx, left.dy)
    ..moveTo(tipPoint.dx, tipPoint.dy)
    ..lineTo(right.dx, right.dy);
}

// =========================================================================
// 1. MOVE arrow: curved cubic + two-line arrowhead.
// =========================================================================
Path movePath(Offset from, Offset to, {double scale = 1, bool mirror = false}) {
  final curve = buildCurve(from, to, scale: scale, mirror: mirror);
  final path = Path()..addPath(curve.path, Offset.zero);
  path.addPath(arrowHeadD(curve.p2, curve.c2), Offset.zero);
  return path;
}

/// `attackSupportPath`'s and `attackSupportConvoyedPath`'s three pieces: the
/// faint ghost of the move being supported, the dashed line from supporter
/// to the meeting point, and the circle marker at that point.
typedef AttackSupportGlyph = ({Path supported, Path line, Path circle});

// =========================================================================
// 2. ATTACK SUPPORT: dashed line from supporter to the curve midpoint of
//                     the supported move, with a small circle at the meet.
// Java reference: ArrowAttSupp.constructSupportedPath + constructPath.
// =========================================================================
AttackSupportGlyph attackSupportPath(
  Offset supporter,
  Offset attackFrom,
  Offset attackTo, {
  double scale = 1,
}) {
  // Build the supported move's curve (so we know its control points).
  final supported = buildCurve(attackFrom, attackTo, scale: scale);
  final mid = curveMid(supported.p1, supported.c1, supported.c2, supported.p2);

  // The supported-arrow itself is drawn dimly (or dotted, if orphaned) so
  // the player sees what is being supported, without it reading as a
  // confirmed move.
  final supportedPath = Path()..addPath(supported.path, Offset.zero);
  supportedPath.addPath(arrowHeadD(supported.p2, supported.c2), Offset.zero);

  // Short straight line from supporter to mid, trimmed so it leaves the
  // supporter and stops at the circle. Java's `f7` term: 3 for short, 12 for
  // normal arrows — that's the trim near the supporter unit.
  final dist = _hypotOr1(mid.dx - supporter.dx, mid.dy - supporter.dy);
  final ux = (mid.dx - supporter.dx) / dist;
  final uy = (mid.dy - supporter.dy) / dist;
  final trimSupp = scale * (dist < 48.0 ? 3.0 : 12.0);
  final circleR = kAttSuppCircleRadius * scale;
  final lineP1 = Offset(supporter.dx + ux * trimSupp, supporter.dy + uy * trimSupp);
  final lineP2 = Offset(mid.dx - ux * circleR, mid.dy - uy * circleR);

  final line = Path()
    ..moveTo(lineP1.dx, lineP1.dy)
    ..lineTo(lineP2.dx, lineP2.dy);
  final circle = Path()..addOval(Rect.fromCircle(center: mid, radius: circleR));

  return (supported: supportedPath, line: line, circle: circle);
}

/// `defenseSupportPath`'s two pieces: the dashed curve to the defended unit,
/// and the square marker on it.
typedef DefenseSupportGlyph = ({Path line, Path square});

// =========================================================================
// 3. DEFENSE SUPPORT: dashed curve from supporter to defended unit, plus a
//                      square marker at the defended unit.
// Java reference: ArrowDefSupp.constructPath / constructDiam.
// =========================================================================
DefenseSupportGlyph defenseSupportPath(
  Offset supporter,
  Offset defended, {
  double scale = 1,
}) {
  // Asymmetric trim: full at the supporter side, short at the defended side
  // (Java: trim1 = f * 12, trim2 = trim1 / 3.5).
  final curve = buildCurve(
    supporter,
    defended,
    trimStart: kRemoveLength,
    trimEnd: kRemoveLength / kShortRatio,
    scale: scale,
  );

  final s = kDefSuppDiamSize * scale / 2;
  final square = Path()
    ..moveTo(defended.dx - s, defended.dy - s)
    ..lineTo(defended.dx + s, defended.dy - s)
    ..lineTo(defended.dx + s, defended.dy + s)
    ..lineTo(defended.dx - s, defended.dy + s)
    ..close();

  return (line: curve.path, square: square);
}

// =========================================================================
// 4. CONVOYED: the convoyed unit's path through 2+ convoying fleets.
//               Sequence of curves with trim only at the very start and end.
// Java reference: ArrowConvoyed.constructKnownConvPath.
// =========================================================================
Path convoyedPath(List<Offset> points, {double scale = 1, bool mirror = false}) {
  if (points.length < 2) return Path();
  final n = points.length;
  final path = Path();
  CurveResult? lastCurve;
  for (var i = 0; i < n - 1; i++) {
    final trimStart = i == 0 ? kRemoveLength : 0.0;
    final trimEnd = i == n - 2 ? kRemoveLength : 0.0;
    final seg = buildCurve(
      points[i],
      points[i + 1],
      trimStart: trimStart,
      trimEnd: trimEnd,
      scale: scale,
      mirror: mirror,
    );
    path.addPath(seg.path, Offset.zero);
    lastCurve = seg;
  }
  if (lastCurve != null) {
    path.addPath(arrowHeadD(lastCurve.p2, lastCurve.c2), Offset.zero);
  }
  return path;
}

// Compact alias — `attackSupportConvoyedPath` returns the same three pieces
// as `attackSupportPath`, just built from a multi-hop arc instead of a
// single curve.
typedef AttackSupportConvoyedGlyph = AttackSupportGlyph;

/// Attack-support for a move that is itself convoyed: the dashed line still
/// points at the supported unit's route, but that route is now the whole
/// fleet chain's arc rather than one curve.
AttackSupportConvoyedGlyph attackSupportConvoyedPath(
  Offset supporter,
  List<Offset> chain, {
  double scale = 1,
}) {
  // Build the multi-hop convoy arc for the supported move.
  final supported = convoyedPath(chain, scale: scale);

  // We need a point on the arc to point the dashed line to. In Diplomacy,
  // support is aimed at the destination, so use the midpoint of the curve
  // from the last fleet to the destination.
  final n = chain.length;
  final lastFleet = chain[n - 2];
  final tgt = chain[n - 1];
  final curve = buildCurve(lastFleet, tgt, trimStart: 0, scale: scale);
  final mid = curveMid(curve.p1, curve.c1, curve.c2, curve.p2);

  final dist = _hypotOr1(mid.dx - supporter.dx, mid.dy - supporter.dy);
  final ux = (mid.dx - supporter.dx) / dist;
  final uy = (mid.dy - supporter.dy) / dist;
  final trimSupp = scale * (dist < 48.0 ? 3.0 : 12.0);
  final circleR = kAttSuppCircleRadius * scale;
  final lineP1 = Offset(supporter.dx + ux * trimSupp, supporter.dy + uy * trimSupp);
  final lineP2 = Offset(mid.dx - ux * circleR, mid.dy - uy * circleR);

  final line = Path()
    ..moveTo(lineP1.dx, lineP1.dy)
    ..lineTo(lineP2.dx, lineP2.dy);
  final circle = Path()..addOval(Rect.fromCircle(center: mid, radius: circleR));

  return (supported: supported, line: line, circle: circle);
}

// =========================================================================
// 5. CONVOY SUPPORT marker: inscribed pentagon, copied from
//    `ArrowConv.constructPent`. Pointing up, on the unit circle scaled by
//    `CONV_PENT_LENGTH * scale`.
//
// `arrows_overlay.js` doesn't dispatch to the pentagon-marker glyph this
// belongs to (`ArrowConv.constructPath`) today — a support of a convoy order
// itself isn't drawn with its own marker in the Mini App either, only the
// convoyed move's arc is. Ported anyway, alongside the rest of this file's
// direct port of `arrows.js`, for whichever ticket adds that marker.
// =========================================================================
Path pentagonD(Offset at, {double scale = 1}) {
  final r = kConvPentLength * scale;
  final pts = [
    Offset(0, -r),
    Offset(0.951 * r, -0.309 * r),
    Offset(0.5878 * r, 0.809 * r),
    Offset(-0.5878 * r, 0.809 * r),
    Offset(-0.951 * r, -0.309 * r),
  ];
  final path = Path()..moveTo(at.dx + pts[0].dx, at.dy + pts[0].dy);
  for (var i = 1; i < pts.length; i++) {
    path.lineTo(at.dx + pts[i].dx, at.dy + pts[i].dy);
  }
  path.close();
  return path;
}
