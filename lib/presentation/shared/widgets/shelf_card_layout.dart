import 'package:flutter/material.dart';

/// Square cover + text block layout for horizontal carousel shelves.
///
/// When the parent passes a bounded max height (typical in home carousels),
/// the cover shrinks so title + subtitle fit without overflow.
class ShelfCardLayout extends StatelessWidget {
  final double cardWidth;
  final double? maxCoverSize;
  final CrossAxisAlignment crossAxisAlignment;
  final Widget Function(double coverSize) coverBuilder;
  final List<Widget> textBlock;

  const ShelfCardLayout({
    super.key,
    required this.cardWidth,
    required this.coverBuilder,
    required this.textBlock,
    this.maxCoverSize,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final coverMax = maxCoverSize ?? cardWidth;

    return SizedBox(
      width: cardWidth,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.hasBoundedHeight) {
            return Column(
              crossAxisAlignment: crossAxisAlignment,
              children: [
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: cardWidth,
                      maxHeight: coverMax,
                    ),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: LayoutBuilder(
                        builder: (context, coverConstraints) {
                          return coverBuilder(coverConstraints.maxWidth);
                        },
                      ),
                    ),
                  ),
                ),
                ...textBlock,
              ],
            );
          }

          return Column(
            crossAxisAlignment: crossAxisAlignment,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: cardWidth,
                height: coverMax,
                child: coverBuilder(coverMax),
              ),
              ...textBlock,
            ],
          );
        },
      ),
    );
  }
}
