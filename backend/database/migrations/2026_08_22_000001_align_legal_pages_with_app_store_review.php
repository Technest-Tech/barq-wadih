<?php

use App\Support\LegalContent;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('static_pages')->where('slug', 'privacy')->update([
            'content_ar' => LegalContent::privacyAr(),
            'content_en' => LegalContent::privacyEn(),
            'meta_description_ar' => 'كيفية جمع بيانات مستخدمي برق واضح واستخدامها وحذفها.',
            'meta_description_en' => 'How Barq Wadih collects, uses, protects, and deletes user data.',
            'updated_at' => now(),
        ]);

        $terms = DB::table('static_pages')->where('slug', 'terms')->first();
        if ($terms) {
            DB::table('static_pages')->where('id', $terms->id)->update([
                'content_ar' => LegalContent::termsAr($terms->content_ar),
                'content_en' => LegalContent::termsEn($terms->content_en),
                'updated_at' => now(),
            ]);
        }

        $fees = DB::table('static_pages')->where('slug', 'fees')->first();
        if ($fees) {
            $arMethods = <<<'HTML'
<p>طريقة الدفع المتاحة حالياً:</p>
<ul>
  <li>تحويل لحساب مؤسسة برق واضح</li>
  <li>إرفاق صورة إيصال التحويل من داخل التطبيق للمراجعة</li>
</ul>
HTML;
            $enMethods = <<<'HTML'
<p>The payment method currently available is:</p>
<ul>
  <li>Bank transfer to Barq Wadih Establishment account</li>
  <li>Upload the bank-transfer receipt inside the app for review</li>
</ul>
HTML;

            DB::table('static_pages')->where('id', $fees->id)->update([
                'content_ar' => preg_replace(
                    '/<p>ندعم طرق الدفع التالية:<\/p>\s*<ul>.*?<\/ul>/s',
                    $arMethods,
                    $fees->content_ar,
                ),
                'content_en' => preg_replace(
                    '/<p>We support the following payment methods:<\/p>\s*<ul>.*?<\/ul>/s',
                    $enMethods,
                    $fees->content_en,
                ),
                'meta_description_ar' => 'تعرّف على عمولات ما بعد البيع وطرق الدفع على منصة برق واضح. النشر مجاني.',
                'meta_description_en' => 'Learn about after-sale commissions and payment methods on Barq Wadih. Publishing is free.',
                'updated_at' => now(),
            ]);
        }

        $deletion = DB::table('static_pages')->where('slug', 'delete-account')->first();
        if ($deletion) {
            DB::table('static_pages')->where('id', $deletion->id)->update([
                'content_ar' => str_replace(
                    'بيانات تسجيل الدخول والملف العام والإعلانات وصورها',
                    'بيانات تسجيل الدخول والملف العام والإعلانات وصورها والمحادثات ووسائطها',
                    $deletion->content_ar,
                ),
                'content_en' => str_replace(
                    'sign-in data, the public profile, listings, and listing images',
                    'sign-in data, the public profile, listings and images, chats, and chat media',
                    $deletion->content_en,
                ),
                'updated_at' => now(),
            ]);
        }
    }

    public function down(): void
    {
        // Privacy disclosures and accurate fee language must not be rolled back.
    }
};
