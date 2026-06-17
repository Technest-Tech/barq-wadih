<?php

namespace App\Console\Commands;

use App\Models\AdImage;
use App\Services\ImageService;
use Illuminate\Console\Command;

class RegenerateAdImageVariants extends Command
{
    /**
     * The name and signature of the console command.
     */
    protected $signature = 'ads:regenerate-images
        {--chunk=100 : Number of images to process per batch}
        {--keep-originals : Do not delete the original full-size files after regenerating}';

    /**
     * The console command description.
     */
    protected $description = 'Generate resized WebP thumbnail/image variants for existing ad images';

    /**
     * Execute the console command.
     */
    public function handle(ImageService $images): int
    {
        $chunk         = (int) $this->option('chunk');
        $keepOriginals = (bool) $this->option('keep-originals');

        $processed = 0;
        $skipped   = 0;
        $failed    = 0;

        $this->info('Regenerating ad image variants…');

        AdImage::query()
            ->orderBy('id')
            ->chunkById($chunk, function ($rows) use ($images, $keepOriginals, &$processed, &$skipped, &$failed) {
                foreach ($rows as $image) {
                    // Already a generated variant — nothing to do.
                    if (str_contains((string) $image->image_url, '_image.webp')) {
                        $skipped++;
                        continue;
                    }

                    $tmp = null;
                    try {
                        $tmp = $images->downloadToTemp($image->image_url);
                        if ($tmp === null) {
                            $this->warn("  · #{$image->id}: source missing, skipped");
                            $skipped++;
                            continue;
                        }

                        $original = $image->image_url;
                        $variants = $images->storeVariants($tmp, "ads/{$image->ad_id}");

                        $image->update([
                            'image_url'     => $variants['image_url'],
                            'thumbnail_url' => $variants['thumbnail_url'],
                            'file_size'     => $variants['file_size'],
                            'width'         => $variants['width'],
                            'height'        => $variants['height'],
                        ]);

                        if (! $keepOriginals && $original !== $variants['image_url']) {
                            $images->delete($original);
                        }

                        $processed++;
                    } catch (\Throwable $e) {
                        $this->error("  · #{$image->id}: {$e->getMessage()}");
                        $failed++;
                    } finally {
                        if ($tmp !== null && file_exists($tmp)) {
                            @unlink($tmp);
                        }
                    }
                }

                $this->line("  …{$processed} done, {$skipped} skipped, {$failed} failed");
            });

        $this->newLine();
        $this->info("Finished: {$processed} regenerated, {$skipped} skipped, {$failed} failed.");

        return $failed > 0 ? self::FAILURE : self::SUCCESS;
    }
}
