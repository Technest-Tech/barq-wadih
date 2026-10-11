<?php

// Ad lifecycle switches.
//
// `auto_expire` is off on purpose: expiry is paused at the owner's request
// until they ask for it back. While it is false nothing moves an ad into the
// expired state on its own — the daily schedule is not registered and
// `ads:expire` refuses to run even if invoked by hand or by a stale cached
// schedule. Set ADS_AUTO_EXPIRE=true (or flip the default) to restore the
// three-month visibility window; nothing else has to change.
return [
    'auto_expire' => env('ADS_AUTO_EXPIRE', false),
];
