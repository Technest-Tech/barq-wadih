<?php

namespace App\Services;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

class ImageService
{
    private string $disk = 'public';

    /**
     * Store an uploaded file and return its relative path.
     */
    public function store(UploadedFile $file, string $directory): string
    {
        $path = Storage::disk($this->disk)->putFile($directory, $file);

        if ($path === false) {
            throw new \RuntimeException("فشل تخزين الصورة في المسار: {$directory}");
        }

        return $path;
    }

    /**
     * Delete a file from storage by its relative path.
     */
    public function delete(string $path): void
    {
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
}
