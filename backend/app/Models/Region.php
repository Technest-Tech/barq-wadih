<?php

namespace App\Models;

use App\Traits\HasSlug;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Region extends Model
{
    use HasFactory, HasSlug;

    protected $fillable = [
        'name_ar',
        'name_en',
        'slug',
        'sort_order',
        'is_active',
    ];

    protected $casts = [
        'is_active'  => 'boolean',
        'sort_order' => 'integer',
    ];

    // ── Relationships ────────────────────────────────────────────────────────

    public function cities(): HasMany
    {
        return $this->hasMany(City::class);
    }

    // ── Scopes ───────────────────────────────────────────────────────────────

    /** @param  \Illuminate\Database\Eloquent\Builder<Region>  $query */
    public function scopeActive($query): void
    {
        $query->where('is_active', true);
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<Region>  $query */
    public function scopeOrdered($query): void
    {
        $query->orderBy('sort_order')->orderBy('name_ar');
    }

    // ── Accessors ────────────────────────────────────────────────────────────

    public function getSlugSourceAttribute(): string
    {
        return $this->name_en;
    }
}
