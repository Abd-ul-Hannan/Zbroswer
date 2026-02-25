import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/TabViewerController.dart';

class TabViewer extends StatefulWidget {
  final List<Widget> children;
  final Function(int)? onTabSelected;
  final bool useGridLayout; // Toggle between carousel and grid

  const TabViewer({
    super.key,
    required this.children,
    this.onTabSelected,
    this.useGridLayout = false, // Default to carousel style
  });

  @override
  State<TabViewer> createState() => _TabViewerState();
}

class _TabViewerState extends State<TabViewer> {
  late TabViewerController _controller;
  PageController? _pageController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    // Safely get or create controller
    if (Get.isRegistered<TabViewerController>()) {
      _controller = Get.find<TabViewerController>();
      debugPrint('TabViewer: Found existing controller');
    } else {
      _controller = Get.put(TabViewerController());
      debugPrint('TabViewer: Created new controller');
    }

    final currentTabIndex = _controller.currentIndex.value
        .clamp(0, (widget.children.length - 1).clamp(0, double.infinity).toInt());
    
    _controller.initialize(widget.children.length, currentTabIndex);

    // Only create PageController for carousel layout
    if (!widget.useGridLayout) {
      _pageController = PageController(
        initialPage: currentTabIndex,
        viewportFraction: 0.85,
      );

      _pageController!.addListener(() {
        if (_pageController!.hasClients) {
          _controller.updatePageOffset(_pageController!.page ?? 0.0);
        }
      });
    }

    _isInitialized = true;
  }

  @override
  void didUpdateWidget(TabViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.children.length != widget.children.length) {
      debugPrint('TabViewer: Children count changed, reinitializing');
      final newIndex = _controller.currentIndex.value
          .clamp(0, (widget.children.length - 1).clamp(0, double.infinity).toInt());
      _controller.initialize(widget.children.length, newIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || widget.children.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: widget.useGridLayout 
            ? _buildGridLayout() 
            : _buildCarouselLayout(),
      ),
    );
  }

  // Carousel Layout (Chrome Mobile Style)
  Widget _buildCarouselLayout() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Expanded(
          child: Obx(() {
            final offset = _controller.pageOffset.value;
            
            return PageView.builder(
              controller: _pageController,
              itemCount: widget.children.length,
              onPageChanged: (index) {
                _controller.currentIndex.value = index;
              },
              itemBuilder: (context, index) {
                return _buildTabCard(
                  index,
                  offset,
                  widget.children[index],
                );
              },
            );
          }),
        ),
        _buildTabIndicator(),
        const SizedBox(height: 20),
      ],
    );
  }

  // Grid Layout (Chrome Desktop Style)
  Widget _buildGridLayout() {
    return Column(
      children: [
        _buildTabIndicator(),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: widget.children.length,
            itemBuilder: (context, index) {
              return Obx(() {
                final isSelected = _controller.currentIndex.value == index;
                
                return GestureDetector(
                  onTap: () {
                    _controller.changeTab(index);
                    widget.onTabSelected?.call(index);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected 
                          ? Border.all(color: Colors.blue, width: 3)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: widget.children[index],
                    ),
                  ),
                );
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTabCard(int index, double pageOffset, Widget child) {
    final difference = (index - pageOffset).abs();
    final scale = 1.0 - (difference * 0.1).clamp(0.0, 0.3);
    final opacity = (1.0 - (difference * 0.3)).clamp(0.5, 1.0);

    return AnimatedBuilder(
      animation: _pageController!,
      builder: (context, childWidget) {
        return Center(
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: GestureDetector(
                onTap: () {
                  if (index != _controller.currentIndex.value) {
                    // Animate to this tab
                    _controller.animateToTab(index);
                    _pageController!.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  } else {
                    // If already on this tab, open it
                    widget.onTabSelected?.call(index);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: childWidget,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildTabIndicator() {
    return Obx(() {
      final currentIndex = _controller.currentIndex.value;
      
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Previous button (only for carousel)
            if (!widget.useGridLayout) ...[
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: currentIndex > 0
                    ? () {
                        _controller.animateToTab(currentIndex - 1);
                        _pageController?.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    : null,
              ),
            ],
            
            // Tab counter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${currentIndex + 1} / ${widget.children.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            
            // Next button (only for carousel)
            if (!widget.useGridLayout) ...[
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: currentIndex < widget.children.length - 1
                    ? () {
                        _controller.animateToTab(currentIndex + 1);
                        _pageController?.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    : null,
              ),
            ],
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }
}