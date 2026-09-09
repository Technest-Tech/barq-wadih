<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\UsernameGenerator;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class UserHandleTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_transliterates_an_arabic_name_into_a_handle(): void
    {
        $user = User::factory()->create(['name' => 'أحمد عمر', 'phone' => '+966500000001']);

        $this->assertSame('ahmd_aamr', $user->fresh()->username);
    }

    public function test_it_falls_back_to_a_neutral_base_when_the_name_has_no_letters(): void
    {
        $user = User::factory()->create(['name' => '🔥🔥', 'phone' => '+966500000002']);

        // "user" itself is reserved, so the neutral base is always id-suffixed.
        $this->assertSame('user_'.$user->id, $user->fresh()->username);
    }

    public function test_it_disambiguates_a_taken_handle_with_the_user_id(): void
    {
        $first = User::factory()->create(['name' => 'خالد', 'phone' => '+966500000003']);
        $second = User::factory()->create(['name' => 'خالد', 'phone' => '+966500000004']);

        $this->assertSame('khald', $first->fresh()->username);
        $this->assertSame('khald_'.$second->id, $second->fresh()->username);
    }

    public function test_it_never_hands_out_a_reserved_handle(): void
    {
        $user = User::factory()->create(['name' => 'Admin', 'phone' => '+966500000005']);

        $this->assertSame('admin_'.$user->id, $user->fresh()->username);
    }

    public function test_the_handle_survives_a_rename(): void
    {
        $user = User::factory()->create(['name' => 'سالم', 'phone' => '+966500000006']);
        $user->update(['name' => 'سالم الغامدي']);

        $this->assertSame('salm', $user->fresh()->username);
    }

    public function test_the_public_profile_resolves_by_handle_and_by_id(): void
    {
        $user = User::factory()->create(['name' => 'عضو 42 04290', 'phone' => '+966500000007']);
        $handle = $user->fresh()->username;

        $this->assertSame('aado_42_04290', $handle);

        $byId = $this->getJson("/api/v1/users/{$user->id}")->assertOk();
        $byHandle = $this->getJson("/api/v1/users/@{$handle}")->assertOk();

        $this->assertSame($byId->json('data'), $byHandle->json('data'));
        $byHandle->assertJsonPath('data.username', $handle);
        $byHandle->assertJsonPath('data.profile_url', config('app.frontend_url').'/@'.$handle);
    }

    public function test_the_handle_lookup_is_case_insensitive(): void
    {
        $user = User::factory()->create(['name' => 'فهد', 'phone' => '+966500000009']);

        $this->getJson('/api/v1/users/@FHD')
            ->assertOk()
            ->assertJsonPath('data.id', $user->id);
    }

    public function test_it_assigns_a_handle_to_a_row_that_has_none(): void
    {
        $first = User::factory()->create(['name' => 'ريم', 'phone' => '+966500000010']);
        $this->assertSame('rym', $first->fresh()->username);

        // A row that reached the database without a handle — what a partial
        // backfill, or a lost race against a concurrent signup, leaves behind.
        $id = DB::table('users')->insertGetId([
            'name' => 'ريم',
            'phone' => '+966500000011',
            'password' => 'x',
            'username' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        User::findOrFail($id)->assignUsername();

        $this->assertSame('rym_'.$id, User::findOrFail($id)->username);
    }

    public function test_a_malformed_id_is_not_found(): void
    {
        User::factory()->create(['name' => 'ليان', 'phone' => '+966500000012']);

        $this->getJson('/api/v1/users/1.5')->assertNotFound();
        $this->getJson('/api/v1/users/1abc')->assertNotFound();
    }

    public function test_an_unknown_handle_is_not_found(): void
    {
        $this->getJson('/api/v1/users/@nobody_here')->assertNotFound();
    }

    public function test_a_non_numeric_id_is_not_found(): void
    {
        User::factory()->create(['name' => 'نورة', 'phone' => '+966500000008']);

        $this->getJson('/api/v1/users/nwrh')->assertNotFound();
    }

    public function test_the_base_slug_is_capped_and_leaves_room_for_a_suffix(): void
    {
        $base = UsernameGenerator::base('محمد بن عبدالرحمن بن سالم الغامدي القحطاني');

        $this->assertLessThanOrEqual(18, strlen($base));
        $this->assertMatchesRegularExpression('/^[a-z0-9]+(_[a-z0-9]+)*$/', $base);
    }
}
