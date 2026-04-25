<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AdFieldValue extends Model
{
    use HasFactory;

    protected $fillable = [
        'ad_id',
        'category_field_id',
        'value',
    ];

    // ── Relationships ────────────────────────────────────────────────────────

    public function ad(): BelongsTo
    {
        return $this->belongsTo(Ad::class);
    }

    public function field(): BelongsTo
    {
        return $this->belongsTo(CategoryField::class, 'category_field_id');
    }

    // ── Accessors ────────────────────────────────────────────────────────────

    /**
     * Cast value based on field_type (resolved via eager-loaded field relation).
     */
    public function getCastedValueAttribute(): mixed
    {
        if (! $this->relationLoaded('field')) {
            return $this->value;
        }

        /** @var CategoryField $categoryField */
        $categoryField = $this->field;

        return match ($categoryField->field_type) {
            \App\Enums\FieldType::Number      => (float) $this->value,
            \App\Enums\FieldType::Year         => (int) $this->value,
            \App\Enums\FieldType::Boolean      => filter_var($this->value, FILTER_VALIDATE_BOOLEAN),
            \App\Enums\FieldType::MultiSelect  => json_decode($this->value, true) ?? [],
            default => $this->value,
        };
    }
}
