import http from 'k6/http';
import { check, sleep } from 'k6';

const baseUrl = __ENV.BASE_URL || 'https://api.barqwadih.com/api/v1';
const requestHeaders = __ENV.AUTH_TOKEN
  ? { Authorization: `Bearer ${__ENV.AUTH_TOKEN}` }
  : {};

export const options = {
  vus: Number(__ENV.VUS || 10),
  duration: __ENV.DURATION || '20s',
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<1500'],
    'http_req_duration{endpoint:ads}': ['p(95)<1500'],
    'http_req_duration{endpoint:categories}': ['p(95)<1500'],
  },
};

export default function () {
  const responses = http.batch([
    [
      'GET',
      `${baseUrl}/ads`,
      null,
      { headers: requestHeaders, tags: { endpoint: 'ads' } },
    ],
    [
      'GET',
      `${baseUrl}/categories`,
      null,
      { headers: requestHeaders, tags: { endpoint: 'categories' } },
    ],
  ]);

  check(responses[0], {
    'ads returns 200': (response) => response.status === 200,
  });
  check(responses[1], {
    'categories returns 200': (response) => response.status === 200,
  });

  // Approximate a user reading the loaded screen before refreshing again.
  sleep(1);
}
