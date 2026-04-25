<?php

namespace App\Models;

use App\Enums\CampaignStatus;
use App\Enums\CampaignTargetType;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NotificationCampaign extends Model
{
    use HasFactory;

    protected $fillable = [
        'admin_id', 'title_ar', 'title_en', 'body_ar', 'body_en',
        'target_type', 'target_city_id', 'target_category_id',
        'target_user_ids', 'data', 'status',
        'scheduled_at', 'sent_at', 'recipients_count', 'delivered_count',
    ];

    protected $casts = [
        'target_type'     => CampaignTargetType::class,
        'status'          => CampaignStatus::class,
        'target_user_ids' => 'array',
        'data'            => 'array',
        'scheduled_at'    => 'datetime',
        'sent_at'         => 'datetime',
    ];

    // ── Relationships ────────────────────────────────────────────────────────

    public function admin(): BelongsTo
    {
        return $this->belongsTo(User::class, 'admin_id');
    }

    public function targetCity(): BelongsTo
    {
        return $this->belongsTo(City::class, 'target_city_id');
    }

    public function targetCategory(): BelongsTo
    {
        return $this->belongsTo(Category::class, 'target_category_id');
    }

    // ── Scopes ───────────────────────────────────────────────────────────────

    /** @param  \Illuminate\Database\Eloquent\Builder<NotificationCampaign>  $query */
    public function scopeDraft($query): void
    {
        $query->where('status', CampaignStatus::Draft->value);
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<NotificationCampaign>  $query */
    public function scopeScheduled($query): void
    {
        $query->where('status', CampaignStatus::Scheduled->value)
              ->where('scheduled_at', '<=', now());
    }
}
