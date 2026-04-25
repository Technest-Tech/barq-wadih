import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final imageFile = File('/Users/ahmedomar/Documents/barq-wadih/barq-wadih-tech/logo.png');
  final original = img.decodeImage(imageFile.readAsBytesSync());
  if (original == null) return;
  
  // Smaller factor for width (1.6) to make it look wider
  // Larger factor for height (3.0) to make it look shorter
  int newWidth = (original.width * 1.6).round();
  int newHeight = (original.height * 3.0).round();
  
  final padded = img.Image(width: newWidth, height: newHeight);
  img.fill(padded, color: img.ColorRgba8(255, 255, 255, 255));
  
  int dx = (newWidth - original.width) ~/ 2;
  int dy = (newHeight - original.height) ~/ 2;
  img.compositeImage(padded, original, dstX: dx, dstY: dy);
  
  final outPath = '/Users/ahmedomar/Documents/barq-wadih/barq-wadih-tech/mobile/assets/images/logo_padded.png';
  File(outPath).writeAsBytesSync(img.encodePng(padded));
  print("Created padded logo at \$outPath!");
}
