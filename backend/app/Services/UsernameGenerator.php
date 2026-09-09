<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Str;

/**
 * Builds the public @handle that identifies a user on shareable links
 * (barqwadih.com/@ahmd_aamr) and in the "share account" sheet.
 *
 * Handles are derived from the display name, transliterated to ASCII so an
 * Arabic name still produces a URL-safe, readable slug:
 *
 *   "أحمد عمر"  →  ahmd_aamr
 *   "عضو 42 04290" →  aado_42_04290
 *
 * They are assigned once, on user creation, and never change afterwards —
 * a link that has been shared must keep resolving.
 */
class UsernameGenerator
{
    /** Must match the users.username column length. */
    public const MAX_LENGTH = 30;

    /**
     * Longest base slug we keep, leaving room for a "_{id}" disambiguation
     * suffix without overflowing MAX_LENGTH.
     */
    private const MAX_BASE_LENGTH = 18;

    /**
     * Handles that would shadow a real website route (barqwadih.com/@admin is
     * fine, but these read as impersonation) or an API path segment.
     *
     * @var list<string>
     */
    private const RESERVED = [
        'about', 'admin', 'ads', 'api', 'auth', 'barq', 'barqwadih', 'contact',
        'favorites', 'fees', 'follows', 'help', 'login', 'me', 'messages',
        'my_ads', 'notifications', 'post_ad', 'privacy', 'profile', 'register',
        'root', 'settings', 'support', 'terms', 'user', 'users', 'wadih',
    ];

    /**
     * Transliterate a display name into a handle base. Pure — no DB access, so
     * migrations and tests can reuse it.
     */
    public static function base(?string $name): string
    {
        $slug = trim(Str::slug(Str::ascii((string) $name, 'ar'), '_'), '_');

        // Names that transliterate to nothing (emoji-only) or to digits alone
        // ("42") would make a confusing handle — fall back to a neutral base.
        if ($slug === '' || preg_match('/[a-z]/', $slug) !== 1) {
            return 'user';
        }

        return trim(Str::limit($slug, self::MAX_BASE_LENGTH, ''), '_');
    }

    public static function isReserved(string $handle): bool
    {
        return in_array($handle, self::RESERVED, strict: true);
    }

    /**
     * Handles to try for a user, best first: the bare name slug (Haraj-style),
     * then "{slug}_{id}", then random suffixes.
     *
     * Callers walk this lazily so they can also skip a candidate that a
     * concurrent signup claimed between the check and the insert.
     *
     * @return \Generator<int, string>
     */
    public static function candidates(?string $name, int $id): \Generator
    {
        $base = self::base($name);

        if (! self::isReserved($base)) {
            yield $base;
        }

        yield $base.'_'.$id;

        for ($attempt = 0; $attempt < 5; $attempt++) {
            yield $base.'_'.Str::lower(Str::random(6));
        }
    }

    /** Pick a free handle for a user. */
    public static function generate(?string $name, int $id): string
    {
        foreach (self::candidates($name, $id) as $candidate) {
            if (! self::isTaken($candidate)) {
                return $candidate;
            }
        }

        // Unreachable short of losing five random draws in a row.
        return self::base($name).'_'.$id.'_'.Str::lower(Str::random(6));
    }

    public static function isTaken(string $handle): bool
    {
        return User::withTrashed()->where('username', $handle)->exists();
    }
}
