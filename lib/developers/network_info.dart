// import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:mime/mime.dart';

import 'package:zbrowser/tools/custom_image.dart';

import 'package:zbrowser/models/webview_model.dart';
import 'package:zbrowser/models/window_model.dart';

class NetworkInfo extends StatelessWidget {
  const NetworkInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GetBuilder<WindowModel>(
          builder: (windowModel) {
            final webViewModel = windowModel.getCurrentTab()?.webViewModel;
            
            if (webViewModel == null) {
              return const Center(child: Text('No active tab'));
            }
            
            return GetBuilder<WebViewModel>(
              init: webViewModel,
              id: 'network_resources',
              builder: (_) {
                final loadedResources = webViewModel.loadedResources;
                const textStyle = TextStyle(fontSize: 14.0);

                // Resources Rows (reversed - latest first)
                return ListView.builder(
                  itemCount: loadedResources.length + 1, // +1 for header
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Header Row
                      return Row(
                        children: [
                          Container(
                            width: constraints.maxWidth / 3.0,
                            alignment: Alignment.center,
                            child: const Text(
                              "Name",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                            ),
                          ),
                          Container(
                            width: constraints.maxWidth / 4,
                            alignment: Alignment.center,
                            child: const Text(
                              "Domain",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                            ),
                          ),
                          Container(
                            width: constraints.maxWidth / 4,
                            alignment: Alignment.center,
                            child: const Text(
                              "Type",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                            ),
                          ),
                          Flexible(
                            child: Container(
                              alignment: Alignment.center,
                              child: const Text(
                                "Time",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    
                    // Resource row (reversed index)
                    final resourceIndex = loadedResources.length - index;
                    final resource = loadedResources[resourceIndex];
                    final url = resource.url ?? Uri.parse("about:blank");
                    final path = url.path;
                    final resourceName = path.substring(path.lastIndexOf('/') + 1);
                    final domain = url.host.replaceFirst("www.", "");

                    IconData iconData;
                    switch (resource.initiatorType) {
                      case "script":
                        iconData = Icons.format_align_left;
                        break;
                      case "css":
                        iconData = Icons.color_lens;
                        break;
                      case "xmlhttprequest":
                        iconData = Icons.http;
                        break;
                      case "link":
                        iconData = Icons.link;
                        break;
                      default:
                        iconData = Icons.insert_drive_file;
                    }

                    final mimeType = lookupMimeType(url.toString());

                    Widget icon;
                    if (mimeType != null && mimeType.startsWith("image/") && mimeType != "image/svg+xml") {
                      icon = CustomImage(
                        url: url, 
                        maxWidth: 20.0, 
                        height: 20.0,
                      );
                    } else if (mimeType == "image/svg+xml") {
                      icon = SvgPicture.network(
                        url.toString(), 
                        width: 20.0, 
                        height: 20.0,
                        placeholderBuilder: (_) => Icon(iconData, size: 20.0),
                      );
                    } else {
                      icon = Icon(iconData, size: 20.0);
                    }

                    return Row(
                      children: [
                        // Name + Icon (click to copy URL)
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: resource.url?.toString() ?? ''));
                            Get.snackbar(
                              'Copied',
                              'URL copied to clipboard',
                              snackPosition: SnackPosition.BOTTOM,
                              duration: const Duration(seconds: 1),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 2.5),
                            width: constraints.maxWidth / 3.0,
                            child: Row(
                              children: [
                                SizedBox(height: 20.0, width: 20.0, child: icon),
                                const SizedBox(width: 10.0),
                                Expanded(
                                  child: Text(
                                    resourceName,
                                    overflow: TextOverflow.ellipsis,
                                    style: textStyle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Domain
                        Container(
                          width: constraints.maxWidth / 4,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 2.5),
                          child: Text(
                            domain,
                            overflow: TextOverflow.ellipsis,
                            style: textStyle,
                          ),
                        ),

                        // Type
                        Container(
                          width: constraints.maxWidth / 4,
                          padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 2.5),
                          alignment: Alignment.center,
                          child: Text(
                            resource.initiatorType ?? "",
                            style: textStyle,
                          ),
                        ),

                        // Time
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 2.5),
                            child: Text(
                              resource.duration != null
                                  ? "${resource.duration!.toStringAsFixed(2)} ms"
                                  : "",
                              style: textStyle,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}