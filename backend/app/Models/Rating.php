<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class Rating extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'rater_id', 'rated_user_id', 'ad_id',
        'stars', 'comment', 'pledge_accepted',
        'is_approved', 'admin_note',
    ];

    protected $casts = [
        'stars'           => 'integer',
        'pledge_accepted' => 'boolean',
        'is_approved'     => 'boolean',
    ];

    // ── Relationships ────────────────────────────────────────────────────────

    public function rater(): BelongsTo
    {
        return $this->belongsTo(User::class, 'rater_id');
    }

    public function ratedUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'rated_user_id');
    }

    public function ad(): BelongsTo
    {
        return $this->belongsTo(Ad::class);
    }

    // ── Scopes ───────────────────────────────────────────────────────────────

    /** @param  \Illuminate\Database\Eloquent\Builder<Rating>  $query */
    public function scopeApproved($query): void
    {
        $query->where('is_approved', true);
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<Rating>  $query */
    public function scopeForUser($query, int $userId): void
    {
        $query->where('rated_user_id', $userId);
    }
}
