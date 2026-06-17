<?php

namespace App\Services;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class ImageService
{
    private string $disk;

    /**
     * Resized variants generated for every uploaded image.
     * Format: 'name' => [maxWidth, quality]. Images are never upscaled —
     * only downscaled when wider than maxWidth.
     *
     *  - thumbnail: feed / listing cards (small, served everywhere)
     *  - image:     detail view (web carousel + mobile full image)
     */
    private const VARIANTS = [
        'thumbnail' => [400, 72],
        'image'     => [1280, 80],
    ];

    /** Cache for one year — variant filenames are content-unique, so they're immutable. */
    private const CACHE_CONTROL = 'public, max-age=31536000, immutable';

    public function __construct()
    {
        $configured = config('filesystems.default', 'local');
        // 'local' disk has no public URL — fall back to 'public' for local dev.
        $this->disk = $configured === 'local' ? 'public' : $configured;
    }

    /**
     * Store an uploaded file and return its relative path.
     *
     * Kept for non-photo uploads (avatars, documents, …). Ad photos should use
     * {@see storeVariants()} so clients receive small, resized WebP images.
     */
    public function store(UploadedFile $file, string $directory): string
    {
        $path = Storage::disk($this->disk)->putFile($directory, $file, 'public');

        if ($path === false) {
            throw new \RuntimeException("فشل تخزين الصورة في المسار: {$directory}");
        }

        return $path;
    }

    /**
     * Generate resized WebP variants from a source image and upload each one.
     *
     * This is what makes ad images load fast: instead of serving the multi-MB
     * camera original, we store a ~25 KB thumbnail and a ~120 KB detail image.
     *
     * @param  string  $sourcePath  Absolute path to a readable source image.
     * @return array{thumbnail_url:string, image_url:string, width:int, height:int, file_size:int}
     */
    public function storeVariants(string $sourcePath, string $directory): array
    {
        $format = $this->variantFormat();
        $ext    = $format === 'webp' ? 'webp' : 'jpg';
        $mime   = $format === 'webp' ? 'image/webp' : 'image/jpeg';
        $base   = trim($directory, '/') . '/' . Str::random(40);

        $urls      = [];
        $imageBytes = 0;
        $width      = 0;
        $height     = 0;

        foreach (self::VARIANTS as $name => [$maxWidth, $quality]) {
            [$blob, $w, $h] = $this->encodeVariant($sourcePath, $maxWidth, $quality, $format);

            $path = "{$base}_{$name}.{$ext}";
            Storage::disk($this->disk)->put($path, $blob, [
                'visibility'   => 'public',
                'CacheControl' => self::CACHE_CONTROL,
                'ContentType'  => $mime,
            ]);

            $urls[$name] = Storage::disk($this->disk)->url($path);

            // Record the dimensions/size of the larger "image" variant.
            if ($name === 'image') {
                $imageBytes = strlen($blob);
                $width      = $w;
                $height     = $h;
            }
        }

        return [
            'thumbnail_url' => $urls['thumbnail'],
            'image_url'     => $urls['image'],
            'width'         => $width,
            'height'        => $height,
            'file_size'     => $imageBytes,
        ];
    }

    /**
     * Download a stored object (by relative path or full URL) to a temp file.
     * Used by the backfill command to re-process existing originals.
     *
     * @return string|null  Temp file path, or null if the object is missing.
     */
    public function downloadToTemp(string $pathOrUrl): ?string
    {
        $path = $this->resolvePath($pathOrUrl);

        if (! $path || ! Storage::disk($this->disk)->exists($path)) {
            return null;
        }

        $tmp = tempnam(sys_get_temp_dir(), 'imgvar_');
        file_put_contents($tmp, Storage::disk($this->disk)->get($path));

        return $tmp;
    }

    /**
     * Delete a file by relative path or full URL.
     */
    public function delete(string $pathOrUrl): void
    {
        $path = $this->resolvePath($pathOrUrl);
        if ($path && Storage::disk($this->disk)->exists($path)) {
            Storage::disk($this->disk)->delete($path);
        }
    }

    /**
     * Return the full public URL for a stored path.
     */
    public function url(string $path): string
    {
        return Storage::disk($this->disk)->url($path);
    }

    /**
     * Get image dimensions from an uploaded file.
     *
     * @return array{width: int, height: int}
     */
    public function dimensions(UploadedFile $file): array
    {
        $size = @getimagesize($file->getRealPath());

        return [
            'width'  => $size ? (int) $size[0] : 0,
            'height' => $size ? (int) $size[1] : 0,
        ];
    }

    /**
     * Encode a single resized variant. Prefers Imagick (with WebP); falls back
     * to GD when Imagick is unavailable.
     *
     * @return array{0:string,1:int,2:int}  [blob, width, height]
     */
    private function encodeVariant(string $sourcePath, int $maxWidth, int $quality, string $format): array
    {
        if (extension_loaded('imagick')) {
            $img = new \Imagick($sourcePath);
            $img->setIteratorIndex(0); // first frame (animated sources)

            if (method_exists($img, 'autoOrient')) {
                $img->autoOrient(); // honour EXIF rotation before stripping it
            }
            $img->stripImage(); // drop EXIF/ICC bloat

            if ($img->getImageWidth() > $maxWidth) {
                $img->resizeImage($maxWidth, 0, \Imagick::FILTER_LANCZOS, 1);
            }

            if ($format === 'webp') {
                $img->setImageFormat('webp');
                $img->setOption('webp:method', '4');
            } else {
                $img->setImageFormat('jpeg');
                $img->setImageCompression(\Imagick::COMPRESSION_JPEG);
            }
            $img->setImageCompressionQuality($quality);

            $blob = $img->getImageBlob();
            $w    = $img->getImageWidth();
            $h    = $img->getImageHeight();

            $img->clear();
            $img->destroy();

            return [$blob, $w, $h];
        }

        return $this->encodeVariantGd($sourcePath, $maxWidth, $quality, $format);
    }

    /**
     * GD fallback encoder.
     *
     * @return array{0:string,1:int,2:int}  [blob, width, height]
     */
    private function encodeVariantGd(string $sourcePath, int $maxWidth, int $quality, string $format): array
    {
        $info = @getimagesize($sourcePath);
        if (! $info) {
            throw new \RuntimeException("تعذّر قراءة الصورة: {$sourcePath}");
        }

        $src = match ($info[2]) {
            IMAGETYPE_JPEG => imagecreatefromjpeg($sourcePath),
            IMAGETYPE_PNG  => imagecreatefrompng($sourcePath),
            IMAGETYPE_WEBP => imagecreatefromwebp($sourcePath),
            IMAGETYPE_GIF  => imagecreatefromgif($sourcePath),
            default        => throw new \RuntimeException('صيغة صورة غير مدعومة'),
        };

        $srcW = imagesx($src);
        $srcH = imagesy($src);

        if ($srcW > $maxWidth) {
            $dstW = $maxWidth;
            $dstH = (int) round($srcH * ($maxWidth / $srcW));
        } else {
            $dstW = $srcW;
            $dstH = $srcH;
        }

        $dst = imagecreatetruecolor($dstW, $dstH);
        imagealphablending($dst, false);
        imagesavealpha($dst, true);
        imagecopyresampled($dst, $src, 0, 0, 0, 0, $dstW, $dstH, $srcW, $srcH);

        ob_start();
        if ($format === 'webp' && function_exists('imagewebp')) {
            imagewebp($dst, null, $quality);
        } else {
            imagejpeg($dst, null, $quality);
        }
        $blob = (string) ob_get_clean();

        imagedestroy($src);
        imagedestroy($dst);

        return [$blob, $dstW, $dstH];
    }

    /**
     * Choose the best output format available on this host (WebP preferred).
     */
    private function variantFormat(): string
    {
        static $format = null;
        if ($format !== null) {
            return $format;
        }

        if (extension_loaded('imagick') && ! empty(\Imagick::queryFormats('WEBP'))) {
            return $format = 'webp';
        }
        if (function_exists('imagewebp')) {
            return $format = 'webp';
        }

        return $format = 'jpg';
    }

    /**
     * Extract the relative storage path from a full URL or return the path as-is.
     * Needed because some callers persist full URLs (e.g. ad_images.image_url).
     */
    private function resolvePath(string $pathOrUrl): string
    {
        if (! str_starts_with($pathOrUrl, 'http')) {
            return $pathOrUrl;
        }

        // Strip the disk's base URL prefix to get the relative path.
        // We use a non-empty placeholder key to derive the base URL — passing
        // an empty string to S3-compatible drivers triggers an AWS SDK
        // validation error ("GetObject Key expected string length >= 1").
        $placeholder    = '__base__';
        $placeholderUrl = Storage::disk($this->disk)->url($placeholder);
        $baseUrl        = rtrim(substr($placeholderUrl, 0, -strlen($placeholder)), '/');

        if ($baseUrl && str_starts_with($pathOrUrl, $baseUrl . '/')) {
            return substr($pathOrUrl, strlen($baseUrl) + 1);
        }

        // Fallback: use only the URL path component, stripped of leading slash.
        return ltrim(parse_url($pathOrUrl, PHP_URL_PATH) ?? '', '/');
    }
}
