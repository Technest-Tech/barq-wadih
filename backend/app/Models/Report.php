<?php

namespace App\Models;

use App\Enums\AdminAction;
use App\Enums\ReportReason;
use App\Enums\ReportStatus;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Report extends Model
{
    use HasFactory;

    protected $fillable = [
        'reporter_id', 'ad_id', 'reason', 'description',
        'status', 'admin_id', 'admin_action', 'admin_note', 'resolved_at',
    ];

    protected $casts = [
        'reason'       => ReportReason::class,
        'status'       => ReportStatus::class,
        'admin_action' => AdminAction::class,
        'resolved_at'  => 'datetime',
    ];

    // ── Relationships ────────────────────────────────────────────────────────

    public function reporter(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reporter_id');
    }

    public function ad(): BelongsTo
    {
        return $this->belongsTo(Ad::class);
    }

    public function admin(): BelongsTo
    {
        return $this->belongsTo(User::class, 'admin_id');
    }

    // ── Scopes ───────────────────────────────────────────────────────────────

    /** @param  \Illuminate\Database\Eloquent\Builder<Report>  $query */
    public function scopePending($query): void
    {
        $query->where('status', ReportStatus::Pending->value);
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<Report>  $query */
    public function scopeResolved($query): void
    {
        $query->where('status', ReportStatus::Resolved->value);
    }
}
