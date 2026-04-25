<?php

namespace App\Models;

use App\Enums\DeviceType;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserDevice extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'fcm_token',
        'device_type',
        'device_name',
        'is_active',
    ];

    protected $casts = [
        'device_type' => DeviceType::class,
        'is_active'   => 'boolean',
    ];

    // ── Relationships ────────────────────────────────────────────────────────

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    // ── Scopes ───────────────────────────────────────────────────────────────

    /** @param  \Illuminate\Database\Eloquent\Builder<UserDevice>  $query */
    public function scopeActive($query): void
    {
        $query->where('is_active', true);
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<UserDevice>  $query */
    public function scopeForPlatform($query, DeviceType $platform): void
    {
        $query->where('device_type', $platform->value);
    }
}
