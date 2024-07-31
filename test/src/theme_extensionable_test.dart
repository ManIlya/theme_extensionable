// ignore_for_file: prefer_const_constructors

import 'package:data_class/data_class.dart';
import 'package:flutter/material.dart';
import 'package:theme_extensionable/theme_extensionable.dart';

void main() {
}

@ThemeExtensionable()
class ThemeTest extends ThemeExtension<ThemeTest> {
  final Color color;
  final TextStyle textStyle;

  ThemeTest({
    required this.color,
    required this.textStyle,
  });
}
