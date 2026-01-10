import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/colors.dart';
import '../tokens/radii.dart';

class BarzStepperTouch extends StatefulWidget {
  final int initialValue;
  final int minValue;
  final int maxValue;
  final ValueChanged<int> onChanged;
  final Axis direction;
  final Color? buttonsColor;
  final Color? counterColor;
  final Color? dragButtonColor;

  const BarzStepperTouch({
    super.key,
    this.initialValue = 1,
    this.minValue = 1,
    this.maxValue = 99,
    required this.onChanged,
    this.direction = Axis.horizontal,
    this.buttonsColor,
    this.counterColor,
    this.dragButtonColor,
  });

  @override
  State<BarzStepperTouch> createState() => _BarzStepperTouchState();
}

class _BarzStepperTouchState extends State<BarzStepperTouch> {
  late int _value;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  void _increment() {
    if (_value < widget.maxValue) {
      HapticFeedback.lightImpact();
      setState(() => _value++);
      widget.onChanged(_value);
    }
  }

  void _decrement() {
    if (_value > widget.minValue) {
      HapticFeedback.lightImpact();
      setState(() => _value--);
      widget.onChanged(_value);
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += widget.direction == Axis.horizontal
          ? details.delta.dx
          : -details.delta.dy;
    });

    if (_dragOffset > 30) {
      _increment();
      _dragOffset = 0;
    } else if (_dragOffset < -30) {
      _decrement();
      _dragOffset = 0;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() => _dragOffset = 0);
  }

  @override
  Widget build(BuildContext context) {
    final buttonsColor = widget.buttonsColor ?? barzDark;
    final counterColor = widget.counterColor ?? barzGold;
    final dragButtonColor = widget.dragButtonColor ?? Colors.white;

    return widget.direction == Axis.horizontal
        ? _buildHorizontal(buttonsColor, counterColor, dragButtonColor)
        : _buildVertical(buttonsColor, counterColor, dragButtonColor);
  }

  Widget _buildHorizontal(Color buttonsColor, Color counterColor, Color dragButtonColor) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: buttonsColor,
        borderRadius: BorderRadius.circular(BarzRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(Icons.remove, _decrement, buttonsColor),
          GestureDetector(
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: dragButtonColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$_value',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: counterColor,
                  ),
                ),
              ),
            ),
          ),
          _buildButton(Icons.add, _increment, buttonsColor),
        ],
      ),
    );
  }

  Widget _buildVertical(Color buttonsColor, Color counterColor, Color dragButtonColor) {
    return Container(
      width: 56,
      decoration: BoxDecoration(
        color: buttonsColor,
        borderRadius: BorderRadius.circular(BarzRadii.full),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(Icons.add, _increment, buttonsColor),
          GestureDetector(
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: dragButtonColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$_value',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: counterColor,
                  ),
                ),
              ),
            ),
          ),
          _buildButton(Icons.remove, _decrement, buttonsColor),
        ],
      ),
    );
  }

  Widget _buildButton(IconData icon, VoidCallback onTap, Color color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BarzRadii.full),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
