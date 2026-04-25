<?php

namespace App\Traits;

use Illuminate\Support\Str;

trait HasSlug
{
    /**
     * Boot the trait and auto-generate slugs on creating.
     */
    public static function bootHasSlug(): void
    {
        static::creating(function ($model): void {
            if (empty($model->{$model->getSlugColumn()})) {
                $model->{$model->getSlugColumn()} = $model->generateUniqueSlug(
                    $model->{$model->getSlugSourceColumn()},
                );
            }
        });
    }

    /**
     * Get the column name for the slug.
     */
    public function getSlugColumn(): string
    {
        return property_exists($this, 'slugColumn') ? $this->slugColumn : 'slug';
    }

    /**
     * Get the column name used to generate the slug.
     */
    public function getSlugSourceColumn(): string
    {
        return property_exists($this, 'slugSourceColumn') ? $this->slugSourceColumn : 'title';
    }

    /**
     * Generate a unique slug from the given string.
     */
    protected function generateUniqueSlug(string $value): string
    {
        $slug = Str::slug($value);
        $originalSlug = $slug;
        $counter = 1;

        while (static::where($this->getSlugColumn(), $slug)->exists()) {
            $slug = $originalSlug.'-'.$counter;
            $counter++;
        }

        return $slug;
    }
}
