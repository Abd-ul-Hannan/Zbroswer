import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AnimatedFlutterBrowserLogoController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late AnimationController animationController;
  late Animation<double> scaleAnimation;
  
  final Duration animationDuration;
  final double size;

  AnimatedFlutterBrowserLogoController({
    this.animationDuration = const Duration(milliseconds: 1000),
    this.size = 100.0,
  });

  @override
  void onInit() {
    super.onInit();
    _initializeAnimation();
  }

  void _initializeAnimation() {
    animationController = AnimationController(
      duration: animationDuration,
      vsync: this,
    );

    scaleAnimation = Tween<double>(begin: 0.75, end: 1.25).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Curves.easeInOut,
      ),
    );

    animationController.repeat(reverse: true);
  }

  void startAnimation() {
    if (!animationController.isAnimating) {
      animationController.repeat(reverse: true);
    }
  }

  void stopAnimation() {
    animationController.stop();
  }

  void resetAnimation() {
    animationController.reset();
  }

  @override
  void onClose() {
    animationController.dispose();
    super.onClose();
  }
}

class AnimatedFlutterBrowserLogo extends StatelessWidget {
  final Duration animationDuration;
  final double size;
  final String? tag;

  const AnimatedFlutterBrowserLogo({
    super.key,
    this.animationDuration = const Duration(milliseconds: 1000),
    this.size = 100.0,
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    // Use unique tag for each instance
    final String controllerTag = tag ?? 
        'animated_logo_${DateTime.now().millisecondsSinceEpoch}';

    // Put controller with unique tag
    final controller = Get.put(
      AnimatedFlutterBrowserLogoController(
        animationDuration: animationDuration,
        size: size,
      ),
      tag: controllerTag,
    );

    return WillPopScope(
      onWillPop: () async {
        // Clean up controller when widget is removed
        Get.delete<AnimatedFlutterBrowserLogoController>(tag: controllerTag);
        return true;
      },
      child: ScaleTransition(
        scale: controller.scaleAnimation,
        child: SizedBox(
          height: size,
          width: size,
          child: const CircleAvatar(
            backgroundImage: AssetImage("assets/icon/icon.png"),
          ),
        ),
      ),
    );
  }
}

// ==================== ALTERNATIVE: WITH STATEFUL WIDGET ====================
// Better approach for widgets with animations
class AnimatedFlutterBrowserLogoStateful extends StatefulWidget {
  final Duration animationDuration;
  final double size;

  const AnimatedFlutterBrowserLogoStateful({
    super.key,
    this.animationDuration = const Duration(milliseconds: 1000),
    this.size = 100.0,
  });

  @override
  State<AnimatedFlutterBrowserLogoStateful> createState() =>
      _AnimatedFlutterBrowserLogoStatefulState();
}

class _AnimatedFlutterBrowserLogoStatefulState
    extends State<AnimatedFlutterBrowserLogoStateful>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.25).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: SizedBox(
        height: widget.size,
        width: widget.size,
        child: const CircleAvatar(
          backgroundImage: AssetImage("assets/icon/icon.png"),
        ),
      ),
    );
  }
}

// ==================== ADVANCED: WITH MORE OPTIONS ====================
class AnimatedBrowserLogoController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late AnimationController animationController;
  late Animation<double> scaleAnimation;
  late Animation<double> rotationAnimation;
  late Animation<double> opacityAnimation;

  final Duration animationDuration;
  final double size;
  final bool enableRotation;
  final bool enableOpacity;
  final Curve curve;

  AnimatedBrowserLogoController({
    this.animationDuration = const Duration(milliseconds: 1000),
    this.size = 100.0,
    this.enableRotation = false,
    this.enableOpacity = false,
    this.curve = Curves.easeInOut,
  });

  @override
  void onInit() {
    super.onInit();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    animationController = AnimationController(
      duration: animationDuration,
      vsync: this,
    );

    // Scale animation
    scaleAnimation = Tween<double>(begin: 0.75, end: 1.25).animate(
      CurvedAnimation(
        parent: animationController,
        curve: curve,
      ),
    );

    // Rotation animation (optional)
    if (enableRotation) {
      rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: animationController,
          curve: curve,
        ),
      );
    }

    // Opacity animation (optional)
    if (enableOpacity) {
      opacityAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(
          parent: animationController,
          curve: curve,
        ),
      );
    }

    animationController.repeat(reverse: true);
  }

  void startAnimation() {
    if (!animationController.isAnimating) {
      animationController.repeat(reverse: true);
    }
  }

  void stopAnimation() {
    animationController.stop();
  }

  void resetAnimation() {
    animationController.reset();
    animationController.repeat(reverse: true);
  }

  @override
  void onClose() {
    animationController.dispose();
    super.onClose();
  }
}

class AnimatedBrowserLogo extends StatelessWidget {
  final Duration animationDuration;
  final double size;
  final bool enableRotation;
  final bool enableOpacity;
  final Curve curve;
  final String imagePath;
  final String? tag;

  const AnimatedBrowserLogo({
    super.key,
    this.animationDuration = const Duration(milliseconds: 1000),
    this.size = 100.0,
    this.enableRotation = false,
    this.enableOpacity = false,
    this.curve = Curves.easeInOut,
    this.imagePath = "assets/icon/icon.png",
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    final String controllerTag =
        tag ?? 'animated_browser_logo_${DateTime.now().millisecondsSinceEpoch}';

    final controller = Get.put(
      AnimatedBrowserLogoController(
        animationDuration: animationDuration,
        size: size,
        enableRotation: enableRotation,
        enableOpacity: enableOpacity,
        curve: curve,
      ),
      tag: controllerTag,
    );

    Widget logo = CircleAvatar(
      backgroundImage: AssetImage(imagePath),
    );

    // Apply scale animation
    logo = ScaleTransition(
      scale: controller.scaleAnimation,
      child: SizedBox(
        height: size,
        width: size,
        child: logo,
      ),
    );

    // Apply rotation if enabled
    if (enableRotation) {
      logo = RotationTransition(
        turns: controller.rotationAnimation,
        child: logo,
      );
    }

    // Apply opacity if enabled
    if (enableOpacity) {
      logo = FadeTransition(
        opacity: controller.opacityAnimation,
        child: logo,
      );
    }

    return logo;
  }
}