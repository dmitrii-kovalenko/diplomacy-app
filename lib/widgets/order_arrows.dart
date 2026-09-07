import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum OrderType { move, support, convoy, hold }

class Order {
  final OrderType type;
  final Offset start;
  final Offset end; // Target location
  final Offset? supportTarget; // For support orders, the unit being supported

  Order({
    required this.type,
    required this.start,
    required this.end,
    this.supportTarget,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Order &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          start == other.start &&
          end == other.end &&
          supportTarget == other.supportTarget;

  @override
  int get hashCode =>
      type.hashCode ^ start.hashCode ^ end.hashCode ^ supportTarget.hashCode;
}

class OrderArrowsPainter extends CustomPainter {
  final List<Order> orders;

  OrderArrowsPainter(this.orders);

  @override
  void paint(Canvas canvas, Size size) {
    for (final order in orders) {
      if (order.type == OrderType.move) {
        _drawMoveArrow(canvas, order.start, order.end);
      } else if (order.type == OrderType.support) {
        if (order.supportTarget != null) {
          _drawSupportArrow(canvas, order.start, order.supportTarget!);
        } else {
          _drawSupportArrow(canvas, order.start, order.end);
        }
      } else if (order.type == OrderType.convoy) {
        _drawConvoyArrow(canvas, order.start, order.end);
      }
    }
  }

  void _drawMoveArrow(Canvas canvas, Offset start, Offset end) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(start.dx, start.dy);

    // Calculate control point for a slight arc
    final midX = (start.dx + end.dx) / 2;
    final midY = (start.dy + end.dy) / 2;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final length = sqrt(dx * dx + dy * dy);
    
    if (length == 0) return;

    // Perpendicular vector for the curve
    final nx = -dy / length;
    final ny = dx / length;
    
    const arcAmount = 20.0; // Distance of the control point from the midpoint
    final ctrlX = midX + nx * arcAmount;
    final ctrlY = midY + ny * arcAmount;

    path.quadraticBezierTo(ctrlX, ctrlY, end.dx, end.dy);
    canvas.drawPath(path, paint);

    _drawArrowHead(canvas, ctrlX, ctrlY, end.dx, end.dy, Colors.black);
  }

  void _drawSupportArrow(Canvas canvas, Offset start, Offset end) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Dashed line
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final length = sqrt(dx * dx + dy * dy);
    
    if (length == 0) return;

    const dashWidth = 5.0;
    const dashSpace = 5.0;
    var distance = 0.0;
    
    while (distance < length) {
      final t1 = distance / length;
      final t2 = (distance + dashWidth) / length;
      
      final startPoint = Offset(start.dx + dx * t1, start.dy + dy * t1);
      final endPoint = Offset(start.dx + dx * min(t2, 1.0), start.dy + dy * min(t2, 1.0));
      
      canvas.drawLine(startPoint, endPoint, paint);
      distance += dashWidth + dashSpace;
    }

    _drawArrowHead(canvas, start.dx, start.dy, end.dx, end.dy, Colors.green);
  }

  void _drawConvoyArrow(Canvas canvas, Offset start, Offset end) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, end, paint);
    _drawArrowHead(canvas, start.dx, start.dy, end.dx, end.dy, Colors.blue);
  }

  void _drawArrowHead(Canvas canvas, double startX, double startY, double endX, double endY, Color color) {
    final dx = endX - startX;
    final dy = endY - startY;
    final angle = atan2(dy, dx);

    const arrowLength = 10.0;
    const arrowAngle = pi / 6;

    final path = Path();
    path.moveTo(endX, endY);
    path.lineTo(
      endX - arrowLength * cos(angle - arrowAngle),
      endY - arrowLength * sin(angle - arrowAngle),
    );
    path.lineTo(
      endX - arrowLength * cos(angle + arrowAngle),
      endY - arrowLength * sin(angle + arrowAngle),
    );
    path.close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant OrderArrowsPainter oldDelegate) {
    return !listEquals(oldDelegate.orders, orders);
  }
}
