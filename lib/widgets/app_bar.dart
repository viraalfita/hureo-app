import 'package:flutter/material.dart';

AppBar buildCustomAppBar({
  required String title,
  Widget? action,
  bool centerTitle = false,
  double titleSpacing = 0,
}) {
  return AppBar(
    backgroundColor: Colors.grey[100],
    foregroundColor: Colors.black,
    elevation: 0,
    titleSpacing: titleSpacing,
    centerTitle: centerTitle,
    title: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: centerTitle
            ? MainAxisAlignment.center
            : MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
          ),
          if (!centerTitle && action != null) action,
        ],
      ),
    ),
  );
}
