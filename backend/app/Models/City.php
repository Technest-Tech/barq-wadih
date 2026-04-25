<?php

namespace App\Models;

use App\Traits\HasSlug;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Laravel\Scout\Searchable;

class City extends Model
{
    use HasFactory, HasSlug, Searchable;

    protected $fillable = [
        'region_id',
        'name_ar',
        'name_en',
        'slug',
        'latitude',
        'longitude',
        'sort_order',
        'is_active',
        'ads_count',
    ];

    protected $casts = [
        'latitude'   => 'float',
        'longitude'  => 'float',
        'is_active'  => 'boolean',
        'sort_order' => 'integer',
        'ads_count'  => 'integer',
    ];

    // ── Relationships ────────────────────────────────────────────────────────

    public function region(): BelongsTo
    {
        return $this->belongsTo(Region::class);
    }

    public function ads(): HasMany
    {
        return $this->hasMany(Ad::class);
    }

    // ── Scopes ───────────────────────────────────────────────────────────────

    /** @param  \Illuminate\Database\Eloquent\Builder<City>  $query */
    public function scopeActive($query): void
    {
        $query->where('is_active', true);
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<City>  $query */
    public function scopeByRegion($query, int $regionId): void
    {
        $query->where('region_id', $regionId);
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<City>  $query */
    public function scopeOrdered($query): void
    {
        $query->orderBy('sort_order')->orderBy('name_ar');
    }

    /**
     * Scope to find cities within a given radius (km) using Haversine formula.
     *
     * @param  \Illuminate\Database\Eloquent\Builder<City>  $query
     */
    public function scopeNearby($query, float $lat, float $lng, float $radiusKm = 50): void
    {
        $query->selectRaw(
            '*, (6371 * acos(cos(radians(?)) * cos(radians(latitude)) * cos(radians(longitude) - radians(?)) + sin(radians(?)) * sin(radians(latitude)))) AS distance',
            [$lat, $lng, $lat]
        )
        ->having('distance', '<=', $radiusKm)
        ->orderBy('distance');
    }

    public function getSlugSourceAttribute(): string
    {
        return $this->name_en;
    }

    // ── Laravel Scout ────────────────────────────────────────────────────────

    /**
     * The name of the Meilisearch index for cities.
     */
    public function searchableAs(): string
    {
        return 'cities';
    }

    /**
     * Get the indexable data array for the model.
     *
     * @return array<string, mixed>
     */
    public function toSearchableArray(): array
    {
        return [
            'id'        => $this->id,
            'name_ar'   => $this->name_ar,
            'name_en'   => $this->name_en,
            'slug'      => $this->slug,
            'region_id' => $this->region_id,
            'latitude'  => $this->latitude,
            'longitude' => $this->longitude,
            'is_active' => $this->is_active,
        ];
    }

    /**
     * Only index active cities.
     */
    public function shouldBeSearchable(): bool
    {
        return $this->is_active;
    }
}
