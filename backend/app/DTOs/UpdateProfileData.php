<?php

namespace App\DTOs;

readonly class UpdateProfileData
{
    public function __construct(
        public ?string $name,
        public ?string $bio,
        public ?string $locale,
        public ?int    $regionId,
        public ?int    $cityId,
    ) {}

    public static function fromRequest(array $data): self
    {
        return new self(
            name:     $data['name'] ?? null,
            bio:      $data['bio'] ?? null,
            locale:   $data['locale'] ?? null,
            regionId: $data['region_id'] ?? null,
            cityId:   $data['city_id'] ?? null,
        );
    }

    public function toArray(): array
    {
        return array_filter([
            'name'      => $this->name,
            'bio'       => $this->bio,
            'locale'    => $this->locale,
            'region_id' => $this->regionId,
            'city_id'   => $this->cityId,
        ], fn ($v) => $v !== null);
    }
}
