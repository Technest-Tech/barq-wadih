<?php

namespace App\Models;

use App\Enums\BillingCycle;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SubscriptionPlan extends Model
{
    use HasFactory;

    protected $fillable = [
        'name_ar', 'name_en', 'description_ar', 'description_en',
        'price', 'duration_days', 'billing_cycle', 'features',
        'is_active', 'sort_order',
    ];

    protected $casts = [
        'billing_cycle' => BillingCycle::class,
        'features'      => 'array',
        'price'         => 'decimal:2',
        'is_active'     => 'boolean',
        'duration_days' => 'integer',
        'sort_order'    => 'integer',
    ];

    public function subscriptions(): HasMany
    {
        return $this->hasMany(UserSubscription::class, 'plan_id');
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<SubscriptionPlan>  $query */
    public function scopeActive($query): void
    {
        $query->where('is_active', true)->orderBy('sort_order');
    }
}
