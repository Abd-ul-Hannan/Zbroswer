import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class JavaScriptConsoleResult extends StatelessWidget {
  final String data;
  final Color textColor;
  final Color backgroundColor;
  final IconData? iconData;
  final Color? iconColor;

  const JavaScriptConsoleResult({
    super.key,
    this.data = "",
    this.textColor = Colors.black,
    this.backgroundColor = Colors.transparent,
    this.iconData,
    this.iconColor,
  });

  void _copyToClipboard() {
    if (data.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: data));
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<InlineSpan> textSpanChildren = [];

    if (iconData != null) {
      textSpanChildren.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(right: 5.0),
            child: Icon(
              iconData,
              color: iconColor,
              size: 14,
            ),
          ),
        ),
      );
    }

    textSpanChildren.add(
      TextSpan(
        text: data,
        style: TextStyle(color: textColor),
      ),
    );

    return Material(
      color: backgroundColor,
      child: InkWell(
        onTap: _copyToClipboard,
        borderRadius: BorderRadius.circular(4), // Better ripple effect
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
          child: RichText(
            text: TextSpan(children: textSpanChildren),
            overflow: TextOverflow.ellipsis,
            maxLines: 3, // Optional: prevent overflow in console
          ),
        ),
      ),
    );
  }
}