<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    // Publish-fee payment driver. `mock` (default) auto-confirms in dev/staging;
    // set PAYMENT_DRIVER=moyasar in .env once the integration is live.
    'payment' => [
        'driver' => env('PAYMENT_DRIVER', 'mock'),
        'moyasar' => [
            'secret_key'      => env('MOYASAR_SECRET_KEY'),
            'webhook_secret'  => env('MOYASAR_WEBHOOK_SECRET'),
        ],
    ],

    'snapchat' => [
        'app_id' => env('SNAPCHAT_APP_ID'),
        'capi_token' => env('SNAPCHAT_CAPI_TOKEN'),
        'endpoint' => env('SNAPCHAT_CAPI_ENDPOINT', 'https://tr.snapchat.com/v3'),
        'event_source_url' => env('SNAPCHAT_EVENT_SOURCE_URL', 'https://barqwadih.com/app'),
    ],

];
