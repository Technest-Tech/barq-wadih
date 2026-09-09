<?php

namespace App\Contracts;

interface ChatDataEraser
{
    /**
     * Permanently remove every conversation and stored chat attachment linked
     * to the account. Implementations must throw when erasure cannot complete.
     */
    public function eraseForUser(int $userId): void;
}
