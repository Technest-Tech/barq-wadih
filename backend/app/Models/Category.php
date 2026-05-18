<?php

namespace App\Models;

use App\Traits\HasSlug;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Laravel\Scout\Searchable;

class Category extends Model
{
    use HasFactory, HasSlug, Searchable;

    protected $fillable = [
        'parent_id',
        'name_ar',
        'name_en',
        'slug',
        'icon',
        'image',
        'description_ar',
        'description_en',
        'sort_order',
        'is_active',
        'is_free',
        'commission_rate',
        'publish_fee_individual',
        'publish_fee_dealer',
        'fee_deductible_from_commission',
        'deferred_commission_individual',
        'deferred_commission_dealer',
        'commission_trigger',
        'meta_keywords',
        'ads_count',
        'prohibited_keywords',
    ];

    protected $casts = [
        'is_active'                      => 'boolean',
        'is_free'                        => 'boolean',
        'commission_rate'                => 'decimal:4',
        'publish_fee_individual'           => 'decimal:2',
        'publish_fee_dealer'               => 'decimal:2',
        'fee_deductible_from_commission'   => 'boolean',
        'deferred_commission_individual'   => 'decimal:2',
        'deferred_commission_dealer'       => 'decimal:2',
        'ads_count'                      => 'integer',
        'sort_order'                     => 'integer',
        'prohibited_keywords'            => 'array',
    ];

    // ── Relationships ────────────────────────────────────────────────────────

    public function parent(): BelongsTo
    {
        return $this->belongsTo(Category::class, 'parent_id');
    }

    public function children(): HasMany
    {
        return $this->hasMany(Category::class, 'parent_id')->orderBy('sort_order');
    }

    public function fields(): HasMany
    {
        return $this->hasMany(CategoryField::class)->orderBy('sort_order');
    }

    public function ads(): HasMany
    {
        return $this->hasMany(Ad::class);
    }

    public function follows(): HasMany
    {
        return $this->hasMany(CategoryFollow::class);
    }

    // ── Scopes ───────────────────────────────────────────────────────────────

    /** @param  \Illuminate\Database\Eloquent\Builder<Category>  $query */
    public function scopeActive($query): void
    {
        $query->where('is_active', true);
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<Category>  $query */
    public function scopeTopLevel($query): void
    {
        $query->whereNull('parent_id');
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<Category>  $query */
    public function scopeOrdered($query): void
    {
        $query->orderBy('sort_order')->orderBy('name_ar');
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<Category>  $query */
    public function scopeWithActiveChildren($query): void
    {
        $query->with(['children' => fn ($q) => $q->active()->ordered()]);
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    public function isTopLevel(): bool
    {
        return $this->parent_id === null;
    }

    public function getSlugSourceAttribute(): string
    {
        return $this->name_en;
    }

    // ── Laravel Scout ────────────────────────────────────────────────────────

    /**
     * The name of the Meilisearch index for categories.
     */
    public function searchableAs(): string
    {
        return 'categories';
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
            'icon'      => $this->icon,
            'parent_id' => $this->parent_id,
            'is_active' => $this->is_active,
        ];
    }

    /**
     * Only index active categories.
     */
    public function shouldBeSearchable(): bool
    {
        return $this->is_active;
    }
}
