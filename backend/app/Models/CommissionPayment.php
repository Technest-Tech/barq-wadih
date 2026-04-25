<?php

namespace App\Models;

use App\Enums\CommissionStatus;
use App\Enums\PaymentMethod;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CommissionPayment extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id', 'ad_id', 'sale_price', 'commission_rate',
        'commission_amount', 'is_flat_fee', 'payment_status',
        'payment_method', 'payment_gateway', 'gateway_transaction_id',
        'gateway_response', 'paid_at',
    ];

    protected $casts = [
        'payment_status'    => CommissionStatus::class,
        'payment_method'    => PaymentMethod::class,
        'sale_price'        => 'decimal:2',
        'commission_rate'   => 'decimal:4',
        'commission_amount' => 'decimal:2',
        'is_flat_fee'       => 'boolean',
        'gateway_response'  => 'array',
        'paid_at'           => 'datetime',
    ];

    // ── Relationships ────────────────────────────────────────────────────────

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function ad(): BelongsTo
    {
        return $this->belongsTo(Ad::class);
    }

    // ── Scopes ───────────────────────────────────────────────────────────────

    /** @param  \Illuminate\Database\Eloquent\Builder<CommissionPayment>  $query */
    public function scopePaid($query): void
    {
        $query->where('payment_status', CommissionStatus::Paid->value);
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<CommissionPayment>  $query */
    public function scopePending($query): void
    {
        $query->where('payment_status', CommissionStatus::Pending->value);
    }
}
