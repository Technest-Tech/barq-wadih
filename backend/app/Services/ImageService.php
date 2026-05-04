<?php

namespace App\Services;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

class ImageService
{
    private string $disk;

    public function __construct()
    {
        $configured = config('filesystems.default', 'local');
        // 'local' disk has no public URL — fall back to 'public' for local dev.
        $this->disk = $configured === 'local' ? 'public' : $configured;
    }

    /**
     * Store an uploaded file and return its relative path.
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
