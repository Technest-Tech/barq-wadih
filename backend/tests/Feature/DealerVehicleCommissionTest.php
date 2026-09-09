<?php

namespace Tests\Feature;

use App\Http\Resources\AdResource;
use App\Models\Category;
use App\Models\City;
use App\Models\Region;
use App\Models\User;
use App\Services\AdService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

class DealerVehicleCommissionTest extends TestCase
{
    use RefreshDatabase;

    private Category $cars;

    private Category $vehicleLeaf;

    private Category $other;

    private City $city;

    protected function setUp(): void
    {
        parent::setUp();
        config(['scout.driver' => null]);
        Queue::fake();

        $this->cars = $this->category('cars', null, 99, 35);
        $this->vehicleLeaf = $this->category('cars-for-sale', $this->cars->id, 99, 35);
        $this->other = $this->category('electronics', null, 10, 10);

        $region = Region::create([
            'name_ar' => 'الرياض',
            'name_en' => 'Riyadh',
            'slug' => 'commission-test-region',
            'is_active' => true,
        ]);
        $this->city = City::create([
            'region_id' => $region->id,
            'name_ar' => 'الرياض',
            'name_en' => 'Riyadh',
            'slug' => 'commission-test-city',
            'is_active' => true,
        ]);
    }

    public function test_vehicle_commission_is_35_for_dealers_and_99_for_individuals(): void
    {
        $service = app(AdService::class);

        $this->assertSame(35.0, $service->calculateCommission(
            $this->vehicleLeaf->id,
            sellerType: 'dealer',
        ));
        $this->assertSame(99.0, $service->calculateCommission(
            $this->vehicleLeaf->id,
            sellerType: 'individual',
        ));
        $this->assertSame(10.0, $service->calculateCommission(
            $this->other->id,
            sellerType: 'dealer',
        ));
    }

    public function test_account_status_overrides_client_seller_type(): void
    {
        $dealer = User::factory()->create(['is_dealer' => true]);
        $ad = app(AdService::class)->create($dealer, $this->adData([
            'seller_type' => 'individual',
        ]), []);

        $this->assertSame('dealer', $ad->seller_type);
        $this->assertSame('35.00', $ad->commission_amount);
    }

    public function test_preview_ignores_spoofed_dealer_query_for_individual(): void
    {
        $individual = User::factory()->create(['is_dealer' => false]);

        $this->actingAs($individual)
            ->getJson('/api/v1/ads/commission-preview?category_id='.
                $this->vehicleLeaf->id.'&seller_type=dealer')
            ->assertOk()
            ->assertJsonPath('data.commission_amount', 99);
    }

    public function test_preview_exposes_both_rates_so_the_wizard_can_show_them(): void
    {
        $individual = User::factory()->create(['is_dealer' => false]);

        $this->actingAs($individual)
            ->getJson('/api/v1/ads/commission-preview?category_id='.$this->vehicleLeaf->id)
            ->assertOk()
            ->assertJsonPath('data.commission_amount', 99)
            ->assertJsonPath('data.commission_individual', 99)
            ->assertJsonPath('data.commission_dealer', 35)
            ->assertJsonPath(
                'data.note',
                'النشر مجاني. عمولة ثابتة (شاملة الضريبة) تُدفع بعد إتمام البيع: 35 ر.س للمعارض و99 ر.س للأفراد.',
            );
    }

    public function test_preview_keeps_a_single_rate_where_both_seller_types_pay_the_same(): void
    {
        $individual = User::factory()->create(['is_dealer' => false]);

        $this->actingAs($individual)
            ->getJson('/api/v1/ads/commission-preview?category_id='.$this->other->id)
            ->assertOk()
            ->assertJsonPath('data.commission_individual', 10)
            ->assertJsonPath('data.commission_dealer', 10)
            ->assertJsonPath(
                'data.note',
                'النشر مجاني. عمولة ثابتة 10 ر.س (شاملة الضريبة) تُدفع بعد إتمام البيع.',
            );
    }

    public function test_detail_marks_only_the_vehicle_tree_for_client_notice(): void
    {
        $dealer = User::factory()->create(['is_dealer' => true]);
        $vehicleAd = app(AdService::class)->create($dealer, $this->adData(), []);
        $vehicleAd->load(['images', 'fieldValues.field', 'category', 'city', 'region', 'district', 'user']);

        $vehicleData = (new AdResource($vehicleAd))->toArray(Request::create('/'));
        $this->assertTrue($vehicleData['is_vehicle_category']);

        $otherAd = app(AdService::class)->create($dealer, $this->adData([
            'category_id' => $this->other->id,
        ]), []);
        $otherAd->load(['images', 'fieldValues.field', 'category', 'city', 'region', 'district', 'user']);
        $otherData = (new AdResource($otherAd))->toArray(Request::create('/'));
        $this->assertFalse($otherData['is_vehicle_category']);
    }

    private function category(
        string $slug,
        ?int $parentId,
        float $individual,
        float $dealer,
    ): Category {
        return Category::create([
            'parent_id' => $parentId,
            'name_ar' => $slug,
            'name_en' => $slug,
            'slug' => $slug,
            'is_active' => true,
            'is_free' => false,
            'deferred_commission_individual' => $individual,
            'deferred_commission_dealer' => $dealer,
        ]);
    }

    /** @param array<string, mixed> $overrides */
    private function adData(array $overrides = []): array
    {
        return array_merge([
            'seller_type' => 'dealer',
            'category_id' => $this->vehicleLeaf->id,
            'city_id' => $this->city->id,
            'title' => 'سيارة للبيع',
            'description' => 'سيارة بحالة جيدة للبيع',
            'price' => 100000,
            'is_negotiable' => false,
            'show_phone_publicly' => false,
        ], $overrides);
    }
}
