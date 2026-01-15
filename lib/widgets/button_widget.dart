import 'package:flutter/material.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';

class ButtonWidget extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final double? width;
  final double? fontSize;
  final double? height;
  final double? radius;
  final Color color;
  final Color? textColor;
  final bool? isLoading;
  final Widget? icon;
  final bool? isOutlined;

  const ButtonWidget({
    super.key,
    this.radius = 100,
    required this.label,
    this.textColor = Colors.white,
    required this.onPressed,
    this.width = 275,
    this.fontSize = 18,
    this.height = 60,
    this.color = primary,
    this.isLoading = false,
    this.icon,
    this.isOutlined = false,
  });

  @override
  State<ButtonWidget> createState() => _ButtonWidgetState();
}

class _ButtonWidgetState extends State<ButtonWidget>
    with TickerProviderStateMixin {
  late AnimationController _scaleAnimationController;
  late AnimationController _rippleAnimationController;
  late Animation<double> _scaleAnimation;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    _scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _rippleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _scaleAnimationController.dispose();
    _rippleAnimationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
    _scaleAnimationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
    _scaleAnimationController.reverse();
  }

  void _handleTapCancel() {
    setState(() {
      _isPressed = false;
    });
    _scaleAnimationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [_scaleAnimationController, _rippleAnimationController]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.isOutlined! ? Colors.transparent : widget.color,
              borderRadius: BorderRadius.circular(widget.radius!),
              border: widget.isOutlined!
                  ? Border.all(
                      color: widget.color,
                      width: 2.0,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: widget.isOutlined!
                      ? Colors.transparent
                      : widget.color.withValues(alpha: 0.3),
                  blurRadius: _isPressed ? 4 : 8,
                  offset: Offset(0, _isPressed ? 2 : 4),
                  spreadRadius: _isPressed ? 0 : 1,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.isLoading! ? null : widget.onPressed,
                onTapDown: widget.isLoading! ? null : _handleTapDown,
                onTapUp: widget.isLoading! ? null : _handleTapUp,
                onTapCancel: widget.isLoading! ? null : _handleTapCancel,
                borderRadius: BorderRadius.circular(widget.radius!),
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: Center(
                    child: widget.isLoading!
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: widget.isOutlined!
                                  ? widget.color
                                  : widget.textColor,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (widget.icon != null) ...[
                                widget.icon!,
                                const SizedBox(width: 8),
                              ],
                              TextWidget(
                                text: widget.label,
                                fontSize: widget.fontSize!,
                                color: widget.isOutlined!
                                    ? widget.color
                                    : widget.textColor,
                                fontFamily: 'Bold',
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
