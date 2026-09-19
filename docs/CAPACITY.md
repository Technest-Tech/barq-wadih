# Capacity baseline

Last measured: 2026-09-17

## What the numbers mean

An install count is not a concurrency count. Ten thousand installs are normally
spread across the day, and an active user spends most of the session reading
instead of continuously requesting data. Capacity is therefore measured as
simultaneous active users, requests per second, latency, and error rate.

These results are a baseline for the public home-feed path. They do not certify
ten thousand simultaneous uploads, chats, searches, or payments. A separate
staging environment with production-sized data is required for that claim.

## Production host at the time of the test

- DigitalOcean `nyc1`, despite the app primarily serving Saudi Arabia
- 2 shared vCPUs and 4 GiB RAM
- Nginx, PHP-FPM, PostgreSQL, Redis, and Meilisearch on one host
- 10 PHP-FPM workers
- 114 users, 188 ads, and 126 active ads
- Media thumbnails served through the image CDN

## Measured results

The repeatable test is `backend/tests/Load/public_api.js`. Each virtual user
loads the first ads page and the category tree in parallel, waits one second,
then repeats. This is deliberately more aggressive than normal browsing.

| Scenario | Requests | Errors | Throughput | p95 latency | Server CPU |
| --- | ---: | ---: | ---: | ---: | ---: |
| 10 users, before edge cache | 246 | 0 | 11.5 req/s | 0.95 s | healthy |
| 25 users, before edge cache | 386 | 0 | 17.4 req/s | 2.01 s | saturated |
| 25 anonymous users, after 10-second cache | 774 | 0 | 36.3 req/s | 0.36 s | mostly below 8% |
| 25 token-bearing users, after cache | 440 | 0 | 20.1 req/s | 1.60 s overall; 1.94 s ads | saturated |

The short Nginx cache shares reference data for all callers and shares the ad
feed only for anonymous callers. Signed-in feeds bypass shared caching because
blocked sellers and owner-only fields can change the response. Publishing,
payments, chat, and every other write operation are never cached.

## Current conclusion

The current host can serve a ten-thousand-install product when usage is spread
normally, and the tested feed paths returned no errors. It cannot support ten
thousand simultaneous active users, and the two-CPU host has insufficient
headroom for a large launch spike. The test data set is also much smaller than
the future production catalog, so capacity must be re-tested as ad volume grows.

## Recommended production target

Before a large marketing launch:

1. Migrate the host from `nyc1` to `fra1`, which is substantially closer to the
   target market.
2. Start with at least 4 vCPUs and 8 GiB RAM. Production now uses the available
   Premium AMD 4-vCPU plan at USD 56/month; dedicated CPU is preferable if
   traffic is sustained rather than bursty.
3. Repeat the same test with 50, 100, and 250 realistic users against staging,
   including authenticated feeds, search, chat, and controlled uploads.
4. Add a second application node and load balancer before claiming thousands of
simultaneous active users. Move PostgreSQL to a separate managed or dedicated
host before database CPU or storage becomes the bottleneck.
5. Alert when p95 exceeds one second, API errors exceed one percent, CPU stays
above 70 percent, or PHP-FPM reports a worker limit warning.

The cross-region migration should use a snapshot to create a new host, test it
privately, synchronize the final database and uploads, switch DNS, and retain
the old host for rollback until the new deployment is verified.

## Production upgrade completed

On 2026-09-17 production moved to a Premium AMD Droplet in `fra1` with 4 vCPUs,
8 GiB RAM, 160 GB NVMe storage, and weekly automated backups. The public IP is
`165.232.120.115`. The former `nyc1` server at `192.81.212.150` remains online
temporarily as a reverse-proxy bridge and rollback point while DNS caches expire.

Private validation against the new host returned 100/100 successful ad-feed
requests at 25-way concurrency. All database, Redis, and Meilisearch health
checks passed, queues were empty, and no application errors were recorded after
cutover. This is a cutover smoke test; the broader authenticated scenarios above
still need to be repeated as the catalog and traffic grow.
