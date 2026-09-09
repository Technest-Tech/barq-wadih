<?php

// Enable only after the release is downloadable in all intended storefronts.
// Store-native checks still work when a policy is disabled or not configured.
return [
    'ios' => [
        'published' => env('APP_UPDATE_IOS_PUBLISHED', false),
        'version' => env('APP_UPDATE_IOS_VERSION'),
        'minimum_os' => env('APP_UPDATE_IOS_MINIMUM_OS'),
    ],
    'android' => [
        'published' => env('APP_UPDATE_ANDROID_PUBLISHED', false),
        'version' => env('APP_UPDATE_ANDROID_VERSION'),
        'build' => env('APP_UPDATE_ANDROID_BUILD'),
        'minimum_sdk' => env('APP_UPDATE_ANDROID_MINIMUM_SDK'),
    ],
];
