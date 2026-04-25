<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class SetLocale
{
    /**
     * Set the application locale from Accept-Language header or ?lang= param.
     */
    public function handle(Request $request, Closure $next): Response
    {
        $locale = $request->query('lang')
            ?? $request->header('Accept-Language');

        if ($locale) {
            // Extract primary language (e.g., "ar" from "ar-SA,ar;q=0.9")
            $locale = strtolower(substr($locale, 0, 2));
        }

        if (in_array($locale, ['ar', 'en'], true)) {
            app()->setLocale($locale);
        }

        return $next($request);
    }
}
