import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The official Saudi Riyal symbol, replacing the legacy "ر.س" / "ريال" text.
const String kRiyalAsset = 'assets/icons/saudi_riyal.svg';

/// Tokens in existing copy that stand for the currency. Longest first so
/// "ر.س." is consumed before "ر.س".
const List<String> _riyalTokens = ['ر.س.', 'ر.س', 'ريال'];

/// The Riyal glyph on its own. Tinted to [color] (defaults to the surrounding
/// text color), so it works on both the white cards and the blue headers.
class RiyalIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const RiyalIcon({super.key, required this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final tint =
        color ?? DefaultTextStyle.of(context).style.color ?? Colors.black;
    return SvgPicture.asset(
      kRiyalAsset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      semanticsLabel: 'ريال سعودي',
    );
  }
}

/// Drop-in replacement for [Text] that renders the Riyal glyph wherever the
/// copy says "ر.س" / "ريال". Keeping the tokens in the source strings means
/// price formatting (e.g. `Ad.priceDisplay`) stays a plain String and still
/// works for share sheets and other text-only contexts.
class RiyalText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final int? maxLines;
  final TextOverflow? overflow;

  const RiyalText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final effective = DefaultTextStyle.of(context).style.merge(style);
    return Text.rich(
      TextSpan(children: riyalSpans(data, style: effective)),
      style: style,
      textAlign: textAlign,
      textDirection: textDirection,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Splits [text] on the currency tokens and swaps each one for the glyph,
/// sized and tinted to match [style] so it sits on the text baseline.
List<InlineSpan> riyalSpans(String text, {required TextStyle style}) {
  // The glyph reads a touch large at the text's own size; 0.9 matches the
  // x-height of the Arabic numerals next to it.
  final size = (style.fontSize ?? 14) * 0.9;
  final spans = <InlineSpan>[];
  final buffer = StringBuffer();

  void flush() {
    if (buffer.isEmpty) return;
    spans.add(TextSpan(text: buffer.toString()));
    buffer.clear();
  }

  var i = 0;
  while (i < text.length) {
    final token = _riyalTokens.firstWhere(
      (t) => text.startsWith(t, i),
      orElse: () => '',
    );
    if (token.isEmpty) {
      buffer.write(text[i]);
      i++;
      continue;
    }
    flush();
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: RiyalIcon(size: size, color: style.color),
        ),
      ),
    );
    i += token.length;
  }
  flush();
  return spans;
}
