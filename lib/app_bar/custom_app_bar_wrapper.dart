import 'package:flutter/material.dart';
import 'package:zbrowser/app_bar/desktop_app_bar.dart';
import 'package:zbrowser/utils/util.dart';

const double _desktopAppBarHeight = 40.0;

class CustomAppBarWrapper extends StatelessWidget implements PreferredSizeWidget {
  final PreferredSizeWidget appBar;

  const CustomAppBarWrapper({super.key, required this.appBar});

  @override
  Size get preferredSize {
    if (Util.isMobile()) {
      return appBar.preferredSize;
    }
    return Size.fromHeight(appBar.preferredSize.height + _desktopAppBarHeight);
  }

  @override
  Widget build(BuildContext context) {
    if (!Util.isDesktop()) {
      return appBar;
    }

    return Column(
      children: [
        const DesktopAppBar(showTabs: false),
        appBar,
      ],
    );
  }
}