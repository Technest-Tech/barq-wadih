<?php

namespace App\Models;

use App\Enums\FieldType;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class CategoryField extends Model
{
    use HasFactory;

    protected $fillable = [
        'category_id',
        'field_key',
        'label_ar',
        'label_en',
        'field_type',
        'options',
        'is_required',
        'is_filterable',
        'sort_order',
        'placeholder_ar',
        'placeholder_en',
        'validation_rules',
    ];

    protected $casts = [
        'field_type'       => FieldType::class,
        'options'          => 'array',
        'validation_rules' => 'array',
        'is_required'      => 'boolean',
        'is_filterable'    => 'boolean',
        'sort_order'       => 'integer',
    ];

    // ── Relationships ────────────────────────────────────────────────────────

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function adFieldValues(): HasMany
    {
        return $this->hasMany(AdFieldValue::class);
    }

    // ── Scopes ───────────────────────────────────────────────────────────────

    /** @param  \Illuminate\Database\Eloquent\Builder<CategoryField>  $query */
    public function scopeRequired($query): void
    {
        $query->where('is_required', true);
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<CategoryField>  $query */
    public function scopeFilterable($query): void
    {
        $query->where('is_filterable', true);
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<CategoryField>  $query */
    public function scopeOrdered($query): void
    {
        $query->orderBy('sort_order');
    }
}
