<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $contentAr = <<<'HTML'
<h2>حذف الحساب في تطبيق برق واضح</h2>
<p>يمكنك بدء حذف حسابك وبياناته من داخل تطبيق <strong>برق واضح</strong> دون الحاجة إلى التواصل مع الدعم.</p>

<h2>خطوات الحذف من التطبيق</h2>
<ol>
  <li>سجّل الدخول وافتح <strong>الملف الشخصي</strong>.</li>
  <li>اضغط <strong>حذف الحساب والبيانات نهائيًا</strong>.</li>
  <li>راجع أثر الحذف، واكتب كلمة «حذف»، ثم أكّد العملية.</li>
</ol>
<p>يُلغى الوصول إلى الحساب وتُحذف بيانات تسجيل الدخول والملف العام والإعلانات وصورها فور نجاح الطلب. الحذف نهائي ولا يمكن التراجع عنه.</p>

<h2>إذا تعذر الدخول إلى الحساب</h2>
<p>استخدم <a href="/ar/contact">صفحة التواصل</a> أو راسل <a href="mailto:support@barqwadih.com">support@barqwadih.com</a> مع رقم الجوال المسجّل. سنطلب ما يلزم للتحقق من ملكية الحساب قبل تنفيذ الطلب.</p>

<h2>البيانات التي قد نحتفظ بها</h2>
<p>قد نحتفظ بسجلات محدودة مثل المعاملات والمدفوعات وبلاغات السلامة وسجلات مكافحة الاحتيال للمدة التي يفرضها النظام أو اللازمة لحماية المستخدمين. تُفصل هذه السجلات عن الملف العام ولا يمكن استخدامها لتسجيل الدخول.</p>
HTML;

        $contentEn = <<<'HTML'
<h2>Deleting Your Barq Wadih Account</h2>
<p>You can initiate deletion of your account and associated data directly inside the <strong>Barq Wadih</strong> app without contacting support.</p>

<h2>Delete from the app</h2>
<ol>
  <li>Sign in and open your <strong>Profile</strong>.</li>
  <li>Tap <strong>Permanently delete account and data</strong>.</li>
  <li>Review the consequences, enter the confirmation word, and confirm.</li>
</ol>
<p>After a successful request, account access is revoked and sign-in data, the public profile, listings, and listing images are removed immediately. Deletion is permanent and cannot be undone.</p>

<h2>If you cannot access the account</h2>
<p>Use the <a href="/en/contact">Contact page</a> or email <a href="mailto:support@barqwadih.com">support@barqwadih.com</a> with the registered phone number. We will verify account ownership before processing the request.</p>

<h2>Limited retention</h2>
<p>We may retain limited transaction, payment, safety-report, and anti-fraud records for the period required by law or necessary to protect users. Retained records are separated from the public profile and cannot be used to sign in.</p>
HTML;

        DB::table('static_pages')->where('slug', 'delete-account')->update([
            'content_ar' => $contentAr,
            'content_en' => $contentEn,
            'meta_description_ar' => 'حذف حساب برق واضح وبياناته مباشرةً من داخل التطبيق.',
            'meta_description_en' => 'Delete your Barq Wadih account and data directly from inside the app.',
            'updated_at' => now(),
        ]);

        $privacy = DB::table('static_pages')->where('slug', 'privacy')->first();
        if (! $privacy) {
            return;
        }

        $arOld = '<p>يمكنك طلب حذف حسابك وجميع بياناتك الشخصية في أي وقت عبر <a href="/ar/contact">صفحة التواصل</a> — تواصل مع فريق الدعم مع توضيح رقم الجوال المسجّل. حذف الحساب نهائي ولا يمكن التراجع عنه.</p>\n<p>سنحذف بياناتك خلال 30 يومًا من استلام الطلب، باستثناء ما يلزم الاحتفاظ به لأغراض قانونية أو تنظيمية.</p>';
        $arNew = '<p>يمكنك بدء حذف حسابك من داخل التطبيق: افتح الملف الشخصي، واضغط «حذف الحساب والبيانات نهائيًا»، ثم أكّد الطلب. تُحذف بيانات تسجيل الدخول والملف العام والإعلانات فور نجاح الطلب، ولا يمكن التراجع.</p>\n<p>قد نحتفظ فقط بسجلات محدودة يفرض النظام الاحتفاظ بها، مثل المعاملات والمدفوعات وبلاغات السلامة ومكافحة الاحتيال، وتُفصل عن ملفك العام. إذا تعذر عليك الدخول، استخدم <a href="/ar/contact">صفحة التواصل</a>.</p>';
        $enOld = '<p>You can request deletion of your account and all personal data at any time via our <a href="/en/contact">Contact page</a> — contact our support team and include your registered phone number. Account deletion is permanent and cannot be undone.</p>\n<p>We will delete your data within 30 days of the request, except where retention is required for legal or regulatory purposes.</p>';
        $enNew = '<p>You can initiate account deletion inside the app: open Profile, tap “Permanently delete account and data,” and confirm. Sign-in data, the public profile, listings, and listing images are removed after a successful request, and deletion cannot be undone.</p>\n<p>We retain only limited records required by law or needed for payment, safety-report, and anti-fraud purposes; these are separated from your public profile. If you cannot sign in, use the <a href="/en/contact">Contact page</a>.</p>';

        $arOld = str_replace('\n', "\n", $arOld);
        $arNew = str_replace('\n', "\n", $arNew);
        $enOld = str_replace('\n', "\n", $enOld);
        $enNew = str_replace('\n', "\n", $enNew);

        DB::table('static_pages')->where('id', $privacy->id)->update([
            'content_ar' => str_replace($arOld, $arNew, $privacy->content_ar),
            'content_en' => str_replace($enOld, $enNew, $privacy->content_en),
            'updated_at' => now(),
        ]);
    }

    public function down(): void
    {
        // The previous instructions required an email request and are not
        // restored because in-app deletion is now the authoritative flow.
    }
};
