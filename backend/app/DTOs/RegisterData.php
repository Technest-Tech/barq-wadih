<?php

namespace App\DTOs;

use App\Enums\UserRole;

readonly class RegisterData
{
    public function __construct(
        public string  $name,
        public ?string $phone,
        public ?string $email,
        public ?string $password,
        public ?int    $regionId,
        public ?int    $cityId,
        public string  $locale = 'ar',
    ) {}

    public static function fromRequest(array $data): self
    {
        return new self(
            name:     $data['name'],
            phone:    $data['phone'] ?? null,
            email:    $data['email'] ?? null,
            password: $data['password'] ?? null,
            regionId: $data['region_id'] ?? null,
            cityId:   $data['city_id'] ?? null,
            locale:   $data['locale'] ?? 'ar',
        );
    }
}
