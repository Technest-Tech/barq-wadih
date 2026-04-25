<?php

namespace App\Models;

use App\Enums\BoostType;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AdBoost extends Model
{
    use HasFactory;

    public $timestamps = false;

    protected $fillable = [
        'ad_id', 'user_id', 'boosted_at', 'expires_at', 'boost_type',
    ];

    protected $casts = [
        'boost_type' => BoostType::class,
        'boosted_at' => 'datetime',
        'expires_at' => 'datetime',
        'created_at' => 'datetime',
    ];

    public function ad(): BelongsTo
    {
        return $this->belongsTo(Ad::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function isExpired(): bool
    {
        return $this->expires_at !== null && $this->expires_at->isPast();
    }
}
