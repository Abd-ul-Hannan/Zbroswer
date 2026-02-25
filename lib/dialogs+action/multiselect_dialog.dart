import 'package:flutter/material.dart';
import 'package:get/get.dart';

const EdgeInsets _defaultInsetPadding =
    EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0);

class MultiSelectDialogItem<V> {
  const MultiSelectDialogItem({required this.value, required this.label});

  final V value;
  final String label;
}

class MultiSelectController<V> extends GetxController {
  final selectedValues = <V>{}.obs;
  
  @override
  void onInit() {
    super.onInit();
    // Initialize here if needed
  }

  void initialize(Set<V>? initialValues) {
    if (initialValues != null) {
      selectedValues.value = initialValues.toSet();
    }
  }

  void onItemCheckedChange(V itemValue, bool checked) {
    if (checked) {
      selectedValues.add(itemValue);
    } else {
      selectedValues.remove(itemValue);
    }
    selectedValues.refresh(); // Force update
  }

  void onCancelTap() {
    Get.back();
  }

  void onSubmitTap() {
    Get.back(result: selectedValues.toSet());
  }
  
  @override
  void onClose() {
    // Clean up if needed
    super.onClose();
  }
}

class MultiSelectDialog<V> extends StatelessWidget {
  const MultiSelectDialog({
    super.key,
    this.title,
    this.titlePadding,
    this.titleTextStyle,
    this.contentPadding = const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
    this.contentTextStyle,
    this.actionsPadding = EdgeInsets.zero,
    this.actionsOverflowDirection,
    this.actionsOverflowButtonSpacing,
    this.buttonPadding,
    this.backgroundColor,
    this.elevation,
    this.semanticLabel,
    this.insetPadding = _defaultInsetPadding,
    this.clipBehavior = Clip.none,
    this.shape,
    this.items,
    this.initialSelectedValues,
  });

  final Widget? title;
  final EdgeInsetsGeometry? titlePadding;
  final TextStyle? titleTextStyle;
  final EdgeInsetsGeometry contentPadding;
  final TextStyle? contentTextStyle;
  final EdgeInsetsGeometry actionsPadding;
  final VerticalDirection? actionsOverflowDirection;
  final double? actionsOverflowButtonSpacing;
  final EdgeInsetsGeometry? buttonPadding;
  final Color? backgroundColor;
  final double? elevation;
  final String? semanticLabel;
  final EdgeInsets insetPadding;
  final Clip clipBehavior;
  final ShapeBorder? shape;
  final List<MultiSelectDialogItem<V>>? items;
  final Set<V>? initialSelectedValues;

  @override
  Widget build(BuildContext context) {
    // Create controller with unique tag to avoid conflicts
    final String controllerTag = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Put controller with unique tag
    final controller = Get.put(
      MultiSelectController<V>(),
      tag: controllerTag,
    );
    
    // Initialize with initial values
    controller.initialize(initialSelectedValues);
    
    return WillPopScope(
      onWillPop: () async {
        // Clean up controller when dialog closes
        Get.delete<MultiSelectController<V>>(tag: controllerTag);
        return true;
      },
      child: AlertDialog(
        title: title,
        content: SingleChildScrollView(
          child: ListTileTheme(
            contentPadding: const EdgeInsets.fromLTRB(14.0, 0.0, 24.0, 0.0),
            child: ListBody(
              children: items?.map((item) => _buildItem(item, controller)).toList() ?? 
                  <Widget>[],
            ),
          ),
        ),
        actions: <Widget>[
          ElevatedButton(
            onPressed: () {
              controller.onCancelTap();
              Get.delete<MultiSelectController<V>>(tag: controllerTag);
            },
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              controller.onSubmitTap();
              Get.delete<MultiSelectController<V>>(tag: controllerTag);
            },
            child: const Text('OK'),
          ),
        ],
        titlePadding: titlePadding,
        titleTextStyle: titleTextStyle,
        contentPadding: contentPadding,
        contentTextStyle: contentTextStyle,
        actionsPadding: actionsPadding,
        actionsOverflowDirection: actionsOverflowDirection,
        actionsOverflowButtonSpacing: actionsOverflowButtonSpacing,
        buttonPadding: buttonPadding,
        backgroundColor: backgroundColor,
        elevation: elevation,
        semanticLabel: semanticLabel,
        insetPadding: insetPadding,
        clipBehavior: clipBehavior,
        shape: shape,
      ),
    );
  }

  Widget _buildItem(
    MultiSelectDialogItem<V> item,
    MultiSelectController<V> controller,
  ) {
    return Obx(() {
      final checked = controller.selectedValues.contains(item.value);
      return CheckboxListTile(
        value: checked,
        title: Text(item.label),
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: (checked) {
          if (checked != null) {
            controller.onItemCheckedChange(item.value, checked);
          }
        },
      );
    });
  }
}