<?php

namespace App\Models;

use App\Enums\SearchPlatform;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class BannerClick extends Model
{
    use HasFactory;

    public $timestamps = false;

    protected $fillable = [
        'banner_id', 'user_id', 'ip_address',
        'user_agent', 'platform', 'clicked_at',
    ];

    protected $casts = [
        'platform'   => SearchPlatform::class,
        'clicked_at' => 'datetime',
    ];

    public function banner(): BelongsTo
    {
        return $this->belongsTo(Banner::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
