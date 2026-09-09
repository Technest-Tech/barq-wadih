<?php

namespace Tests\Feature;

use App\Enums\AdStatus;
use App\Jobs\SendCommissionReviewNotificationJob;
use App\Jobs\SendSaleFeeNotificationJob;
use App\Models\Ad;
use App\Models\Category;
use App\Models\City;
use App\Models\Notification;
use App\Models\Region;
use App\Models\User;
use App\Services\ChatService;
use App\Services\PushService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Kreait\Firebase\Contract\Auth as FirebaseAuth;
use Kreait\Firebase\Contract\Messaging;
use Tests\TestCase;

/**
 * A seller running several listings needs every notification to say which ad
 * it is about. Without that, "رسالة جديدة من فلان" or a bare rejection reason
 * is unactionable.
 */
class NotificationAdContextTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['scout.driver' => null]);

        // No device tokens are registered in these tests, so FCM is never
        // dispatched — the mocks only satisfy the constructors.
        $this->app->instance(Messaging::class, \Mockery::mock(Messaging::class));
        $this->app->instance(FirebaseAuth::class, \Mockery::mock(FirebaseAuth::class));
    }

    private function makeAd(User $seller, string $title): Ad
    {
        $suffix = uniqid();
        $region = Region::create([
            'name_ar' => 'الرياض', 'name_en' => 'Riyadh',
            'slug' => "riyadh-{$suffix}", 'is_active' => true,
        ]);
        $city = City::create([
            'region_id' => $region->id, 'name_ar' => 'الرياض', 'name_en' => 'Riyadh',
            'slug' => "riyadh-city-{$suffix}", 'is_active' => true,
        ]);
        $category = Category::create([
            'name_ar' => 'سيارات', 'name_en' => 'Cars',
            'slug' => "cars-{$suffix}", 'is_active' => true,
        ]);

        return Ad::create([
            'user_id'      => $seller->id,
            'category_id'  => $category->id,
            'city_id'      => $city->id,
            'region_id'    => $region->id,
            'title'        => $title,
            'description'  => 'وصف الإعلان للاختبار',
            'price'        => 5000,
            'status'       => AdStatus::Active,
            'published_at' => now(),
            'expires_at'   => Ad::nextExpiry(),
        ]);
    }

    public function test_chat_notification_names_the_ad(): void
    {
        $seller = User::factory()->create();
        $buyer = User::factory()->create(['name' => 'سالم']);
        $ad = $this->makeAd($seller, 'كامري 2020');

        $conversationId = ChatService::conversationId($ad->id, $buyer->id, $seller->id);

        $this->app->make(ChatService::class)->notifyNewMessage(
            conversationId: $conversationId,
            receiverId: $seller->id,
            messagePreview: 'كم آخر سعر؟',
            sender: $buyer,
        );

        $notification = Notification::where('user_id', $seller->id)->firstOrFail();

        $this->assertStringContainsString('سالم', $notification->title_ar);
        $this->assertStringContainsString('كامري 2020', $notification->body_ar);
        $this->assertStringContainsString('كم آخر سعر؟', $notification->body_ar);
        $this->assertSame('كامري 2020', $notification->data['ad_title']);
        $this->assertSame($ad->id, $notification->data['ad_id']);
    }

    public function test_conversation_id_round_trips_to_its_ad(): void
    {
        $this->assertSame(7, ChatService::adIdFromConversationId('ad7_u1_u2'));
        $this->assertNull(ChatService::adIdFromConversationId('not-a-conversation'));
        $this->assertNull(ChatService::adIdFromConversationId('ad7_u1'));
    }

    public function test_rating_notification_names_the_ad(): void
    {
        $seller = User::factory()->create();
        $rater = User::factory()->create(['name' => 'نورة']);
        $ad = $this->makeAd($seller, 'آيفون 15');

        \Laravel\Sanctum\Sanctum::actingAs($rater);

        $this->postJson("/api/v1/ads/{$ad->id}/ratings", [
            'stars'           => 5,
            'comment'         => 'بائع ممتاز',
            'pledge_accepted' => true,
        ])->assertCreated();

        $notification = Notification::where('user_id', $seller->id)
            ->where('type', 'new_rating')
            ->firstOrFail();

        $this->assertStringContainsString('آيفون 15', $notification->body_ar);
        $this->assertSame('آيفون 15', $notification->data['ad_title']);
    }

    public function test_sale_fee_notification_names_the_ad_in_its_title(): void
    {
        $seller = User::factory()->create();
        $ad = $this->makeAd($seller, 'ثلاجة سامسونج');

        (new SendSaleFeeNotificationJob($ad->id))->handle($this->app->make(PushService::class));

        $notification = Notification::where('user_id', $seller->id)->firstOrFail();

        $this->assertStringContainsString('ثلاجة سامسونج', $notification->title_ar);
        $this->assertStringContainsString('ثلاجة سامسونج', $notification->body_ar);
        $this->assertSame('ثلاجة سامسونج', $notification->data['ad_title']);
    }

    public function test_commission_rejection_names_the_ad_even_with_a_reason(): void
    {
        $seller = User::factory()->create();
        $ad = $this->makeAd($seller, 'لابتوب ديل');

        // The reason branch used to replace the ad name rather than join it.
        (new SendCommissionReviewNotificationJob($ad->id, false, 'الإيصال غير واضح'))
            ->handle($this->app->make(PushService::class));

        $notification = Notification::where('user_id', $seller->id)->firstOrFail();

        $this->assertStringContainsString('لابتوب ديل', $notification->body_ar);
        $this->assertStringContainsString('الإيصال غير واضح', $notification->body_ar);
    }
}
