<?php

namespace App\Models;

use App\Enums\SettingType;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Cache;

class SystemSetting extends Model
{
    use HasFactory;

    protected $fillable = ['key', 'value', 'type', 'group', 'description'];

    protected $casts = [
        'type' => SettingType::class,
    ];

    // ── Static helpers ───────────────────────────────────────────────────────

    /**
     * Get a typed setting value by key.
     * Falls back to a direct DB query if the cache store (Redis) is unavailable.
     */
    public static function get(string $key, mixed $default = null): mixed
    {
        try {
            $setting = Cache::remember(
                "setting:{$key}",
                now()->addHour(),
                fn () => static::where('key', $key)->first()
            );
        } catch (\Throwable) {
            // Redis unavailable (local dev without Docker) — hit DB directly
            $setting = static::where('key', $key)->first();
        }

        if (! $setting) {
            return $default;
        }

        return match ($setting->type) {
            SettingType::Integer => (int) $setting->value,
            SettingType::Decimal => (float) $setting->value,
            SettingType::Boolean => filter_var($setting->value, FILTER_VALIDATE_BOOLEAN),
            SettingType::Json    => json_decode($setting->value, true),
            default              => $setting->value,
        };
    }

    /**
     * Set a setting value and clear its cache.
     */
    public static function set(string $key, mixed $value): void
    {
        static::updateOrCreate(
            ['key' => $key],
            ['value' => is_array($value) ? json_encode($value) : (string) $value]
        );
        Cache::forget("setting:{$key}");
    }

    // ── Scopes ───────────────────────────────────────────────────────────────

    /** @param  \Illuminate\Database\Eloquent\Builder<SystemSetting>  $query */
    public function scopeByGroup($query, string $group): void
    {
        $query->where('group', $group);
    }
}
