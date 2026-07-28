<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Add a dedicated "Delete Account" static page (slug: delete-account),
     * required by Google Play's Data safety form. It states the app/developer
     * name, the steps to request deletion, and which data is deleted vs kept.
     */
    public function up(): void
    {
        $contentAr = <<<'HTML'
<h2>طلب حذف الحساب في تطبيق برق واضح</h2>
<p>يوضّح هذا الدليل كيفية طلب حذف حسابك وبياناتك في تطبيق <strong>برق واضح</strong> (المطوّر: برق واضح).</p>

<h2>خطوات طلب الحذف</h2>
<ol>
  <li>افتح <a href="/ar/contact">صفحة التواصل</a> أو راسلنا على البريد الإلكتروني: <a href="mailto:support@barqwadih.com">support@barqwadih.com</a>.</li>
  <li>اكتب في رسالتك «طلب حذف الحساب» مع ذكر رقم الجوال المسجّل في حسابك.</li>
  <li>سيقوم فريقنا بالتحقق من هويتك ثم تنفيذ الحذف.</li>
</ol>

<h2>البيانات التي تُحذف</h2>
<ul>
  <li>حسابك ومعلوماتك الشخصية (الاسم، رقم الجوال، البريد الإلكتروني، الصورة الشخصية).</li>
  <li>إعلاناتك وصورها.</li>
  <li>محادثاتك ورسائلك الصوتية.</li>
</ul>

<h2>البيانات التي قد نحتفظ بها</h2>
<p>قد نحتفظ ببعض السجلات (مثل سجلات المعاملات والمدفوعات) للمدة التي يفرضها النظام لأغراض قانونية ومحاسبية، ثم تُحذف نهائيًا.</p>

<h2>مدة التنفيذ</h2>
<p>يتم حذف بياناتك خلال 30 يومًا من التحقق من الطلب، باستثناء ما يلزم الاحتفاظ به قانونيًا. حذف الحساب نهائي ولا يمكن التراجع عنه.</p>
HTML;

        $contentEn = <<<'HTML'
<h2>Requesting Account Deletion for the Barq Wadih App</h2>
<p>This guide explains how to request deletion of your account and data in the <strong>Barq Wadih</strong> app (Developer: Barq Wadih).</p>

<h2>Steps to request deletion</h2>
<ol>
  <li>Open the <a href="/en/contact">Contact page</a> or email us at <a href="mailto:support@barqwadih.com">support@barqwadih.com</a>.</li>
  <li>In your message, write "Account deletion request" and include the phone number registered on your account.</li>
  <li>Our team will verify your identity and process the deletion.</li>
</ol>

<h2>Data that is deleted</h2>
<ul>
  <li>Your account and personal information (name, phone, email, profile photo).</li>
  <li>Your listings and their photos.</li>
  <li>Your chats and voice messages.</li>
</ul>

<h2>Data we may retain</h2>
<p>We may keep certain records (such as transaction and payment records) for the period required by law for legal and accounting purposes, after which they are permanently deleted.</p>

<h2>Processing time</h2>
<p>Your data is deleted within 30 days of verifying the request, except where retention is legally required. Account deletion is permanent and cannot be undone.</p>
HTML;

        DB::table('static_pages')->updateOrInsert(
            ['slug' => 'delete-account'],
            [
                'title_ar'            => 'حذف الحساب',
                'title_en'            => 'Delete Account',
                'meta_description_ar' => 'كيفية طلب حذف حسابك وبياناتك في تطبيق برق واضح.',
                'meta_description_en' => 'How to request deletion of your account and data in the Barq Wadih app.',
                'content_ar'          => $contentAr,
                'content_en'          => $contentEn,
                'is_published'        => true,
                'created_at'          => now(),
                'updated_at'          => now(),
            ]
        );
    }

    public function down(): void
    {
        DB::table('static_pages')->where('slug', 'delete-account')->delete();
    }
};
