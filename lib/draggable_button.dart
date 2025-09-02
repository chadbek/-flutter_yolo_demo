import 'package:flutter/material.dart';

class DraggableThresholdButton extends StatefulWidget {
  final double min;
  final double max;
  final Function(double value) onChanged;

  const DraggableThresholdButton({
    Key? key,
    this.min = 0.2,
    this.max = 0.9,
    required this.onChanged,
  }) : super(key: key);

  @override
  _DraggableThresholdButtonState createState() =>
      _DraggableThresholdButtonState();
}

class _DraggableThresholdButtonState extends State<DraggableThresholdButton> {
  double _value = 0.2;
  double _knobX = 0;

  final double trackWidth = 300;
  final double knobSize = 40;

  void _updateKnobPosition(Offset localPosition) {
    double x = localPosition.dx.clamp(0, trackWidth);
    setState(() {
      _knobX = x;
      _value = widget.min +
          ((x / trackWidth) * (widget.max - widget.min));
    });
    widget.onChanged(_value);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: trackWidth + knobSize,
      height: 80,
      child: GestureDetector(
        onPanUpdate: (details) {
          _updateKnobPosition(Offset(_knobX + details.delta.dx, 0));
        },
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Positioned(
              left: knobSize / 2,
              right: knobSize / 2,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Positioned(
              left: _knobX,
              child: Container(
                width: knobSize,
                height: knobSize,
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  _value.toStringAsFixed(2),
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}