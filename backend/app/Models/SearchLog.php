<?php

namespace App\Models;

use App\Enums\SearchPlatform;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SearchLog extends Model
{
    use HasFactory;

    public $timestamps = false;

    protected $fillable = [
        'user_id', 'query', 'category_id',
        'city_id', 'results_count', 'platform',
    ];

    protected $casts = [
        'platform'      => SearchPlatform::class,
        'results_count' => 'integer',
        'created_at'    => 'datetime',
    ];

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

    // ── Scopes ───────────────────────────────────────────────────────────────

    /** @param  \Illuminate\Database\Eloquent\Builder<SearchLog>  $query */
    public function scopeZeroResults($query): void
    {
        $query->where('results_count', 0);
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<SearchLog>  $query */
    public function scopeRecent($query, int $days = 90): void
    {
        $query->where('created_at', '>=', now()->subDays($days));
    }
}
