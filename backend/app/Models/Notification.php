<?php

namespace App\Models;

use App\Enums\NotificationChannel;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Notification extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id', 'type', 'title_ar', 'title_en',
        'body_ar', 'body_en', 'data', 'channel',
        'is_read', 'read_at', 'sent_at',
    ];

    protected $casts = [
        'channel' => NotificationChannel::class,
        'data'    => 'array',
        'is_read' => 'boolean',
        'read_at' => 'datetime',
        'sent_at' => 'datetime',
    ];

    // ── Relationships ────────────────────────────────────────────────────────

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    // ── Scopes ───────────────────────────────────────────────────────────────

    /** @param  \Illuminate\Database\Eloquent\Builder<Notification>  $query */
    public function scopeUnread($query): void
    {
        $query->where('is_read', false);
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<Notification>  $query */
    public function scopeForUser($query, int $userId): void
    {
        $query->where('user_id', $userId);
    }
}
