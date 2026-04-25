<?php

namespace App\Exceptions;

use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;

class InsufficientPermissionException extends AccessDeniedHttpException
{
    public function __construct(string $message = 'ليس لديك صلاحية للقيام بهذا الإجراء')
    {
        parent::__construct($message);
    }
}
