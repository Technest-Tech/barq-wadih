<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AdImage extends Model
{
    use HasFactory;

    public $timestamps = false;

    protected $fillable = [
        'ad_id', 'image_url', 'thumbnail_url',
        'sort_order', 'file_size', 'width', 'height',
    ];

    protected $casts = [
        'sort_order' => 'integer',
        'file_size'  => 'integer',
        'width'      => 'integer',
        'height'     => 'integer',
        'created_at' => 'datetime',
    ];

    public function ad(): BelongsTo
    {
        return $this->belongsTo(Ad::class);
    }

    public function isPrimary(): bool
    {
        return $this->sort_order === 0;
    }
}
