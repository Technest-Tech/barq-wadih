<?php

namespace App\Traits;

use Illuminate\Database\Eloquent\Builder;

trait Filterable
{
    /**
     * Apply filters from the request to the query.
     *
     * @param  Builder<static>  $query
     * @param  array<string, mixed>  $filters
     * @return Builder<static>
     */
    public function scopeFilter(Builder $query, array $filters): Builder
    {
        foreach ($filters as $field => $value) {
            if ($value === null || $value === '') {
                continue;
            }

            $method = 'filter'.str_replace(' ', '', ucwords(str_replace('_', ' ', $field)));

            if (method_exists($this, $method)) {
                $this->{$method}($query, $value);
            } else {
                $query->where($field, $value);
            }
        }

        return $query;
    }

    /**
     * Apply search to the query.
     *
     * @param  Builder<static>  $query
     * @param  string  $term
     * @param  array<int, string>  $columns
     * @return Builder<static>
     */
    public function scopeSearch(Builder $query, string $term, array $columns = []): Builder
    {
        if (empty($columns)) {
            $columns = property_exists($this, 'searchable') ? $this->searchable : [];
        }

        if (empty($columns)) {
            return $query;
        }

        return $query->where(function (Builder $q) use ($term, $columns): void {
            foreach ($columns as $column) {
                $q->orWhere($column, 'LIKE', "%{$term}%");
            }
        });
    }
}
