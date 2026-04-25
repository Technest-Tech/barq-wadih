<?php

namespace App\Exceptions;

use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class AdNotFoundException extends NotFoundHttpException
{
    public function __construct(string $message = 'الإعلان غير موجود')
    {
        parent::__construct($message);
    }
}
