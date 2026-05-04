<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class AdQuestion extends Model
{
    protected $fillable = ['ad_id', 'user_id', 'parent_id', 'body'];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function ad(): BelongsTo
    {
        return $this->belongsTo(Ad::class);
    }

    public function parent(): BelongsTo
    {
        return $this->belongsTo(AdQuestion::class, 'parent_id');
    }

    public function replies(): HasMany
    {
        return $this->hasMany(AdQuestion::class, 'parent_id')->with('user')->latest();
    }
}
