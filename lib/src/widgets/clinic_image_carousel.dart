import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Slider-type image viewer for clinic establishment photos.
///
/// Accepts `List<dynamic>` because the Supabase `establishment_images` column
/// is `text[]` but raw rows may contain non-String entries (upload-path bug,
/// wrong column type, stale cache, etc.). Non-String values are dropped and
/// logged so the patient flow never crashes with a subtype cast error.
class ClinicImageCarousel extends StatefulWidget {
  final List<dynamic> imageUrls;
  final double height;
  final BorderRadius borderRadius;

  const ClinicImageCarousel({
    super.key,
    required this.imageUrls,
    this.height = 220,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  State<ClinicImageCarousel> createState() => _ClinicImageCarouselState();
}

class _ClinicImageCarouselState extends State<ClinicImageCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  /// Only valid, non-empty String URLs. Non-String values from the raw
  /// `widget.imageUrls` are filtered out here and never reach Image.network.
  late List<String> _validUrls = _filterValidUrls(widget.imageUrls);

  @override
  void initState() {
    super.initState();
    _validUrls = _filterValidUrls(widget.imageUrls);
  }

  @override
  void didUpdateWidget(covariant ClinicImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.imageUrls, widget.imageUrls)) {
      final next = _filterValidUrls(widget.imageUrls);
      if (!listEquals(_validUrls, next)) {
        _validUrls = next;
        if (_currentPage >= _validUrls.length) {
          _currentPage = 0;
          _pageController.jumpToPage(0);
        }
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static List<String> _filterValidUrls(List<dynamic> raw) {
    if (raw.isEmpty) return const [];

    final dropped = <dynamic>[];
    final out = <String>[];

    for (final item in raw) {
      if (item is String && item.isNotEmpty) {
        out.add(item);
      } else if (item != null) {
        dropped.add(item);
      }
    }

    if (dropped.isNotEmpty) {
      debugPrint(
        'ClinicImageCarousel: dropped ${dropped.length} non-String image '
        'entry(ies): $dropped. Check establishment_images column type and '
        'the image upload path.',
      );
    }

    return out;
  }

  void _openFullscreen(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenGallery(
          imageUrls: _validUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_validUrls.isEmpty) {
      return ClipRRect(
        borderRadius: widget.borderRadius,
        child: Container(
          height: widget.height,
          width: double.infinity,
          color: Colors.teal.shade50,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 48,
                color: Colors.teal.shade200,
              ),
              const SizedBox(height: 8),
              Text(
                'No clinic photos yet',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _validUrls.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) {
                final url = _validUrls[index];
                return GestureDetector(
                  onTap: () => _openFullscreen(index),
                  child: Image.network(
                    url,
                    width: double.infinity,
                    height: widget.height,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: widget.height,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_validUrls.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DotsRow(
                  count: _validUrls.length,
                  current: _currentPage,
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _openFullscreen(_currentPage),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.zoom_in, size: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Swipe dots shown over the carousel.
class DotsRow extends StatelessWidget {
  final int count;
  final int current;

  const DotsRow({super.key, required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          count,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: current == index ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: current == index
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fullscreen gallery opened when a carousel image is tapped.
class _FullscreenGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullscreenGallery({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_current + 1} of ${widget.imageUrls.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.imageUrls.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer(
              maxScale: 4.0,
              child: Image.network(
                widget.imageUrls[index],
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
