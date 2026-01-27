import 'package:flutter/material.dart';

class TextWidget extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color? color;
  final String? fontFamily;
  final TextDecoration? decoration;
  final bool? isItalize;
  final bool? isBold;
  final int? maxLines;
  final TextAlign align;

  const TextWidget(
      {super.key,
      this.decoration,
      this.align = TextAlign.start,
      this.maxLines = 2,
      this.isItalize = false,
      this.isBold = false,
      required this.text,
      required this.fontSize,
      this.color = Colors.black,
      this.fontFamily = 'Regular'});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      maxLines: maxLines,
      style: TextStyle(
          letterSpacing: 0,
          overflow: TextOverflow.ellipsis,
          fontStyle: isItalize! ? FontStyle.italic : null,
          decoration: decoration,
          fontWeight: isBold! ? FontWeight.w800 : FontWeight.normal,
          fontSize: fontSize,
          color: color,
          fontFamily: fontFamily),
    );
  }
}
