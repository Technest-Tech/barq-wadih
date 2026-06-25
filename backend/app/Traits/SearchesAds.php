<?php

namespace App\Traits;

use Illuminate\Database\Eloquent\Builder;

/**
 * Shared keyword-search behaviour for ad listing endpoints (GET /ads and
 * GET /search). Provides Arabic-aware, OR-based matching so that:
 *
 *   • a multi-word query ("ساعة أرانب") returns every ad containing ANY of the
 *     words — the empty state is only reached when none of them match anywhere;
 *   • common Arabic spelling variants match each other (أ إ آ ٱ→ا, ة→ه, ى ئ→ي,
 *     ؤ→و, tatweel removed, case-folded), so "ساعه" matches a stored "ساعة".
 */
trait SearchesAds
{
    /**
     * Arabic normalization map, applied identically to the query and the column.
     *
     * @var array<string, string>
     */
    private array $arabicNormalizeMap = [
        'أ' => 'ا', 'إ' => 'ا', 'آ' => 'ا', 'ٱ' => 'ا',
        'ة' => 'ه',
        'ى' => 'ي', 'ئ' => 'ي',
        'ؤ' => 'و',
        'ـ' => '',
    ];

    /**
     * Split a search query into distinct words for OR-based matching.
     * De-duplicates and caps the token count to keep the generated SQL bounded.
     *
     * @return string[]
     */
    protected function searchTokens(string $q): array
    {
        $parts = preg_split('/\s+/u', trim($q), -1, PREG_SPLIT_NO_EMPTY) ?: [];

        return array_slice(array_values(array_unique($parts)), 0, 10);
    }

    /** Normalize a search string the same way normalizeColumnSql() normalizes a column. */
    protected function normalizeSearch(string $s): string
    {
        return strtr(mb_strtolower($s), $this->arabicNormalizeMap);
    }

    /**
     * Build a SQL expression that normalizes the given column the same way
     * normalizeSearch() normalizes the query, so LIKE comparisons are
     * variant-insensitive. The map holds only constant, hard-coded characters —
     * no user input — so inlining them into the SQL is safe.
     */
    protected function normalizeColumnSql(string $column): string
    {
        $expr = "LOWER({$column})";

        foreach ($this->arabicNormalizeMap as $from => $to) {
            $expr = "REPLACE({$expr}, '{$from}', '{$to}')";
        }

        return $expr;
    }

    /**
     * Apply OR-based, Arabic-normalized keyword matching across the title and
     * description columns. An ad matches when the whole phrase OR any single
     * word appears in either column.
     *
     * @param  Builder  $query
     */
    protected function applyKeywordFilter($query, string $q): void
    {
        if (trim($q) === '') {
            return;
        }

        $tokens = $this->searchTokens($q);
        $titleN = $this->normalizeColumnSql('title');
        $descN = $this->normalizeColumnSql('description');

        $query->where(function ($sub) use ($q, $tokens, $titleN, $descN) {
            // Whole-phrase match first (covers exact / multi-word substrings).
            $phrase = '%'.$this->normalizeSearch($q).'%';
            $sub->whereRaw("{$titleN} LIKE ?", [$phrase])
                ->orWhereRaw("{$descN} LIKE ?", [$phrase]);

            // Then each word independently (the OR fix).
            foreach ($tokens as $token) {
                $needle = '%'.$this->normalizeSearch($token).'%';
                $sub->orWhereRaw("{$titleN} LIKE ?", [$needle])
                    ->orWhereRaw("{$descN} LIKE ?", [$needle]);
            }
        });
    }
}
