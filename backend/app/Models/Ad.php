<?php

namespace App\Models;

use App\Enums\AdStatus;
use App\Enums\CommissionStatus;
use App\Enums\ModerationStatus;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Laravel\Scout\Searchable;

class Ad extends Model
{
    use HasFactory, SoftDeletes, Searchable;

    protected $fillable = [
        'user_id', 'category_id', 'city_id', 'region_id', 'district_id', 'district_name_free',
        'latitude', 'longitude',
        'title', 'description', 'price', 'price_hidden',
        'is_negotiable', 'is_free',
        'status', 'moderation_status', 'moderation_note',
        'views_count', 'favorites_count', 'chats_count',
        'contact_phone', 'contact_whatsapp', 'show_phone_publicly',
        'commission_amount', 'commission_status', 'sale_declared_at',
        'payment_status', 'payment_amount', 'payment_provider', 'payment_reference', 'paid_at',
        'is_boosted', 'boosted_until',
        'pledge_accepted', 'expires_at', 'expiry_notified_at', 'published_at',
    ];

    protected $casts = [
        'status'              => AdStatus::class,
        'moderation_status'   => ModerationStatus::class,
        'commission_status'   => CommissionStatus::class,
        'price'               => 'decimal:2',
        'price_hidden'        => 'boolean',
        'commission_amount'   => 'decimal:2',
        'payment_amount'      => 'decimal:2',
        'paid_at'             => 'datetime',
        'is_negotiable'       => 'boolean',
        'is_free'             => 'boolean',
        'is_boosted'          => 'boolean',
        'pledge_accepted'     => 'boolean',
        'show_phone_publicly' => 'boolean',
        'latitude'            => 'float',
        'longitude'           => 'float',
        'expires_at'          => 'datetime',
        'boosted_until'       => 'datetime',
        'sale_declared_at'    => 'datetime',
        'expiry_notified_at'  => 'datetime',
        'published_at'        => 'datetime',
    ];

    // ── Relationships ────────────────────────────────────────────────────────

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function city(): BelongsTo
    {
        return $this->belongsTo(City::class);
    }

    public function region(): BelongsTo
    {
        return $this->belongsTo(Region::class);
    }

    public function district(): BelongsTo
    {
        return $this->belongsTo(District::class);
    }

    public function images(): HasMany
    {
        return $this->hasMany(AdImage::class)->orderBy('sort_order');
    }

    public function fieldValues(): HasMany
    {
        return $this->hasMany(AdFieldValue::class);
    }

    public function boosts(): HasMany
    {
        return $this->hasMany(AdBoost::class)->latest('boosted_at');
    }

    public function favorites(): HasMany
    {
        return $this->hasMany(Favorite::class);
    }

    public function ratings(): HasMany
    {
        return $this->hasMany(Rating::class);
    }

    public function reports(): HasMany
    {
        return $this->hasMany(Report::class);
    }

    public function commissionPayments(): HasMany
    {
        return $this->hasMany(CommissionPayment::class);
    }

    // ── Scopes ───────────────────────────────────────────────────────────────

    /** @param  \Illuminate\Database\Eloquent\Builder<Ad>  $query */
    public function scopeActive($query): void
    {
        $query->where('status', AdStatus::Active->value)
              ->where('moderation_status', ModerationStatus::Approved->value);
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<Ad>  $query */
    public function scopeBoosted($query): void
    {
        $query->where('is_boosted', true)
              ->where('boosted_until', '>', now());
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<Ad>  $query */
    public function scopeByCity($query, int $cityId): void
    {
        $query->where('city_id', $cityId);
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<Ad>  $query */
    public function scopeByCategory($query, int $categoryId): void
    {
        $query->where('category_id', $categoryId);
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<Ad>  $query */
    public function scopeByRegion($query, int $regionId): void
    {
        $query->where('region_id', $regionId);
    }

    /** Ads expiring within the next N days.
     *
     * @param  \Illuminate\Database\Eloquent\Builder<Ad>  $query
     */
    public function scopeExpiringSoon($query, int $days = 3): void
    {
        $query->active()
              ->whereNull('expiry_notified_at')
              ->whereBetween('expires_at', [now(), now()->addDays($days)]);
    }

    /** Main feed: newest first.
     *
     * @param  \Illuminate\Database\Eloquent\Builder<Ad>  $query
     */
    public function scopeFeed($query): void
    {
        $query->active()
              ->orderByDesc('published_at')
              ->orderByDesc('created_at');
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<Ad>  $query */
    public function scopePriceRange($query, ?float $min, ?float $max): void
    {
        if ($min !== null) {
            $query->where('price', '>=', $min);
        }
        if ($max !== null) {
            $query->where('price', '<=', $max);
        }
    }

    // ── Accessors ────────────────────────────────────────────────────────────

    /** @return AdImage|null */
    public function getPrimaryImageAttribute(): ?AdImage
    {
        $first = $this->images->first();
        return $first instanceof AdImage ? $first : null;
    }

    public function getIsExpiredAttribute(): bool
    {
        return $this->expires_at->isPast();
    }

    public function getIsOwnedByAttribute(): bool
    {
        return auth()->id() === $this->user_id;
    }

    // ── Scout / Meilisearch ──────────────────────────────────────────────────

    /** The Meilisearch index name. */
    public function searchableAs(): string
    {
        return 'ads';
    }

    /**
     * Fields sent to Meilisearch for indexing.
     * Keep in sync with scout.php index-settings → ads → searchableAttributes.
     */
    public function toSearchableArray(): array
    {
        return [
            'id'          => $this->id,
            'title'       => $this->title,
            'description' => $this->description,
            // Filterable / sortable fields
            'category_id' => $this->category_id,
            'city_id'     => $this->city_id,
            'region_id'   => $this->region_id,
            'price'       => $this->price ? (float) $this->price : null,
            'is_free'     => (int) $this->is_free,
            'is_boosted'  => (int) $this->is_boosted,
            'status'      => $this->status->value,
            'published_at'=> $this->published_at?->timestamp,
            'created_at'  => $this->created_at?->timestamp,
        ];
    }

    /**
     * Only index ads that are active AND moderation-approved.
     * Pending, rejected, expired, and deleted ads are never searchable.
     */
    public function shouldBeSearchable(): bool
    {
        return $this->status === AdStatus::Active
            && $this->moderation_status === ModerationStatus::Approved;
    }
}
