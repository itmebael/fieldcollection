import 'package:flutter/material.dart';

class TabIconData {
  TabIconData({
    this.iconData,
    this.imagePath,
    this.selectedImagePath,
    this.label,
    this.index = 0,
    this.isSelected = false,
    this.animationController,
  });

  IconData? iconData;
  String? imagePath;
  String? selectedImagePath;
  String? label;
  int index;
  bool isSelected;
  AnimationController? animationController;
}
