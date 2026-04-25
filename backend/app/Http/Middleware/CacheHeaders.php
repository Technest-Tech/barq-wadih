<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Adds Cache-Control headers to public read-only API endpoints.
 * Attach to route groups to control browser/CDN caching.
 */
class CacheHeaders
{
    /**
     * @param  int  $maxAge  Seconds for max-age directive
     * @param  bool  $public  Whether the response is publicly cacheable
     * @param  int  $staleWhileRevalidate  Seconds for stale-while-revalidate
     */
    public function handle(Request $request, Closure $next, int $maxAge = 60, bool $public = true, int $staleWhileRevalidate = 0): Response
    {
        $response = $next($request);

        // Only cache GET requests with successful responses
        if ($request->isMethod('GET') && $response->isSuccessful()) {
            $directives = [];
            $directives[] = $public ? 'public' : 'private';
            $directives[] = "max-age={$maxAge}";

            if ($staleWhileRevalidate > 0) {
                $directives[] = "stale-while-revalidate={$staleWhileRevalidate}";
            }

            $response->headers->set('Cache-Control', implode(', ', $directives));
        }

        return $response;
    }
}
