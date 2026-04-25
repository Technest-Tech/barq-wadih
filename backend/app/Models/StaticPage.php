<?php

namespace App\Models;

use App\Traits\HasSlug;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class StaticPage extends Model
{
    use HasFactory, HasSlug;

    protected $fillable = [
        'slug', 'title_ar', 'title_en',
        'content_ar', 'content_en', 'is_published',
        'meta_description_ar', 'meta_description_en',
    ];

    protected $casts = [
        'is_published' => 'boolean',
    ];

    // ── Scopes ───────────────────────────────────────────────────────────────

    /** @param  \Illuminate\Database\Eloquent\Builder<StaticPage>  $query */
    public function scopePublished($query): void
    {
        $query->where('is_published', true);
    }

    public function getSlugSourceAttribute(): string
    {
        return $this->title_en;
    }
}
