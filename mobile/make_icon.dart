import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final imageFile = File('/Users/ahmedomar/Documents/barq-wadih/barq-wadih-tech/logo.png');
  final original = img.decodeImage(imageFile.readAsBytesSync());
  if (original == null) { print('Failed to load image'); return; }

  print('Original size: ${original.width}x${original.height}');

  // Make the canvas square using the LARGER dimension
  // Then add padding on the shorter side to center the logo
  final size = original.width > original.height ? original.width : original.height;

  final square = img.Image(width: size, height: size);
  // Fill with white background — same as logo.png background
  img.fill(square, color: img.ColorRgba8(255, 255, 255, 255));

  // Center the original logo on the square canvas
  final dx = (size - original.width) ~/ 2;
  final dy = (size - original.height) ~/ 2;
  img.compositeImage(square, original, dstX: dx, dstY: dy);

  final outPath = '/Users/ahmedomar/Documents/barq-wadih/barq-wadih-tech/mobile/assets/images/logo_square.png';
  File(outPath).writeAsBytesSync(img.encodePng(square));
  print('Created square icon: ${square.width}x${square.height} → $outPath');
}
