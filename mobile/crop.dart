import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final imageFile = File('/Users/ahmedomar/Documents/barq-wadih/barq-wadih-tech/logo-nobg.png');
  final image = img.decodeImage(imageFile.readAsBytesSync());
  if (image == null) return;
  
  // Find boundaries
  int minX = image.width, minY = image.height, maxX = 0, maxY = 0;
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      if (pixel.a > 0) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  
  // Add 10% padding so it doesn't touch the edges completely
  int pX = (maxX - minX) ~/ 10;
  int pY = (maxY - minY) ~/ 10;
  minX = (minX - pX).clamp(0, image.width);
  maxX = (maxX + pX).clamp(0, image.width);
  minY = (minY - pY).clamp(0, image.height);
  maxY = (maxY + pY).clamp(0, image.height);

  final cropped = img.copyCrop(image, x: minX, y: minY, width: maxX - minX, height: maxY - minY);
  final outPath = '/Users/ahmedomar/Documents/barq-wadih/barq-wadih-tech/mobile/assets/images/logo_nobg_cropped.png';
  File(outPath).writeAsBytesSync(img.encodePng(cropped));
  print("Saved cropped to \$outPath!");
}
