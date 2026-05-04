<?php

namespace App\Models;

use App\Traits\HasSlug;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class District extends Model
{
    use HasFactory, HasSlug;

    protected $fillable = [
        'region_id',
        'city_id',
        'name_ar',
        'name_en',
        'slug',
        'latitude',
        'longitude',
        'sort_order',
        'is_active',
    ];

    protected $casts = [
        'latitude'   => 'float',
        'longitude'  => 'float',
        'is_active'  => 'boolean',
        'sort_order' => 'integer',
    ];

    public function region(): BelongsTo
    {
        return $this->belongsTo(Region::class);
    }

    public function city(): BelongsTo
    {
        return $this->belongsTo(City::class);
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<District>  $query */
    public function scopeActive($query): void
    {
        $query->where('is_active', true);
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<District>  $query */
    public function scopeByCity($query, int $cityId): void
    {
        $query->where('city_id', $cityId);
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<District>  $query */
    public function scopeOrdered($query): void
    {
        $query->orderBy('sort_order')->orderBy('name_ar');
    }

    public function getSlugSourceAttribute(): string
    {
        return $this->name_en ?? $this->name_ar;
    }
}
