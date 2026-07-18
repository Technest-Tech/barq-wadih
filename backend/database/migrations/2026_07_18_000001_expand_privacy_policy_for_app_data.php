<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Expand the privacy policy to cover mobile-app data the website policy
     * omitted (precise location, camera/photos, microphone/voice, device &
     * push identifiers), name Google Firebase as a processor, and add an
     * Account & Data Deletion section — required for Google Play review and
     * to stay consistent with the Data safety declaration.
     */
    public function up(): void
    {
        $page = DB::table('static_pages')->where('slug', 'privacy')->first();

        if (! $page) {
            return;
        }

        $contentAr = <<<'HTML'
<h2>١. مقدمة</h2>
<p>تلتزم <strong>برق واضح</strong> بحماية خصوصيتك. تُوضّح هذه السياسة كيفية جمع بياناتك الشخصية واستخدامها ومشاركتها وحمايتها، سواء عند استخدام موقعنا الإلكتروني أو تطبيق <strong>برق واضح</strong> على الأجهزة المحمولة.</p>

<h2>٢. البيانات التي نجمعها</h2>
<ul>
  <li><strong>بيانات الحساب:</strong> الاسم، رقم الجوال، البريد الإلكتروني (اختياري)، الصورة الشخصية.</li>
  <li><strong>بيانات الإعلانات:</strong> المنتج أو الخدمة، الصور، الموقع، معلومات الاتصال.</li>
  <li><strong>الموقع الجغرافي الدقيق:</strong> بموافقتك فقط، نستخدم موقع جهازك لعرض الإعلانات القريبة منك وحساب المسافات. يمكنك رفض الإذن أو إيقافه في أي وقت من إعدادات جهازك.</li>
  <li><strong>الصور والكاميرا:</strong> للسماح لك بالتقاط صور إعلاناتك أو اختيارها من معرض الصور.</li>
  <li><strong>الميكروفون والتسجيلات الصوتية:</strong> لإرسال الرسائل الصوتية داخل المحادثات (عند استخدامك لهذه الميزة).</li>
  <li><strong>مُعرّفات الجهاز والإشعارات:</strong> رمز الإشعارات (Push Token) ومعلومات الجهاز لإرسال التنبيهات المتعلقة بحسابك وإعلاناتك ومحادثاتك.</li>
  <li><strong>بيانات الاستخدام:</strong> الصفحات التي تزورها، عمليات البحث، الجهاز والمتصفح.</li>
  <li><strong>بيانات الدفع:</strong> تُعالَج عبر بوابة دفع آمنة ولا نحتفظ ببيانات بطاقتك الائتمانية.</li>
</ul>

<h2>٣. كيف نستخدم بياناتك</h2>
<ul>
  <li>تقديم خدمات المنصة وتشغيلها.</li>
  <li>التواصل معك بشأن حسابك وإعلاناتك.</li>
  <li>تحسين تجربة المستخدم وتطوير المنصة.</li>
  <li>إرسال إشعارات ترويجية (يمكنك إلغاء الاشتراك في أي وقت).</li>
  <li>الامتثال للمتطلبات القانونية والتنظيمية.</li>
</ul>

<h2>٤. مشاركة البيانات</h2>
<p>لا نبيع بياناتك لأطراف ثالثة. قد نشارك بياناتك فقط مع:</p>
<ul>
  <li>مزودي الخدمات اللازمين لتشغيل المنصة (بوابة الدفع، الاستضافة).</li>
  <li><strong>Google Firebase</strong> — لخدمات المصادقة عبر رقم الجوال (رمز التحقق OTP)، والمحادثات، وتخزين الملفات، وإرسال الإشعارات. للمزيد راجع <a href="https://firebase.google.com/support/privacy" target="_blank" rel="noopener">سياسة خصوصية Firebase</a>.</li>
  <li>الجهات الحكومية بموجب أمر قضائي أو إلزام قانوني.</li>
</ul>

<h2>٥. أمان البيانات</h2>
<p>نستخدم تشفير SSL وضوابط وصول صارمة لحماية بياناتك. ومع ذلك، لا يمكن ضمان الأمان الكامل لأي نظام إلكتروني.</p>

<h2>٦. ملفات تعريف الارتباط (Cookies)</h2>
<p>نستخدم ملفات تعريف الارتباط لتحسين تجربتك وتحليل الاستخدام. يمكنك ضبط متصفحك لرفضها، غير أن ذلك قد يؤثر على بعض وظائف المنصة.</p>

<h2>٧. حقوقك</h2>
<ul>
  <li>الاطلاع على بياناتك الشخصية وتصحيحها أو حذفها.</li>
  <li>إلغاء الاشتراك في الرسائل التسويقية.</li>
  <li>سحب أذونات الجهاز (الموقع، الكاميرا، الميكروفون، الإشعارات) في أي وقت من إعدادات جهازك.</li>
</ul>

<h2>٨. حذف الحساب والبيانات</h2>
<p>يمكنك طلب حذف حسابك وجميع بياناتك الشخصية في أي وقت عبر <a href="/ar/contact">صفحة التواصل</a> — تواصل مع فريق الدعم مع توضيح رقم الجوال المسجّل. حذف الحساب نهائي ولا يمكن التراجع عنه.</p>
<p>سنحذف بياناتك خلال 30 يومًا من استلام الطلب، باستثناء ما يلزم الاحتفاظ به لأغراض قانونية أو تنظيمية.</p>

<h2>٩. التواصل</h2>
<p>لأي استفسار بشأن هذه السياسة، تواصل معنا عبر <a href="/ar/contact">صفحة التواصل</a>.</p>

<p style="color:#888;font-size:0.85em;">آخر تحديث: يوليو 2026</p>
HTML;

        $contentEn = <<<'HTML'
<h2>1. Introduction</h2>
<p><strong>Barq Wadih</strong> is committed to protecting your privacy. This policy explains how we collect, use, share, and protect your personal data, whether you use our website or the <strong>Barq Wadih</strong> mobile app.</p>

<h2>2. Data We Collect</h2>
<ul>
  <li><strong>Account data:</strong> Name, phone number, email (optional), profile photo.</li>
  <li><strong>Listing data:</strong> Product/service details, photos, location, contact information.</li>
  <li><strong>Precise location:</strong> With your consent only, we use your device location to show nearby listings and calculate distances. You can deny or disable this permission at any time in your device settings.</li>
  <li><strong>Photos &amp; camera:</strong> To let you capture or select photos for your listings.</li>
  <li><strong>Microphone &amp; audio recordings:</strong> To send voice messages inside chats (when you use this feature).</li>
  <li><strong>Device &amp; notification identifiers:</strong> A push token and device information used to send alerts about your account, listings, and chats.</li>
  <li><strong>Usage data:</strong> Pages visited, searches performed, device and browser information.</li>
  <li><strong>Payment data:</strong> Processed through a secure payment gateway — we do not store card details.</li>
</ul>

<h2>3. How We Use Your Data</h2>
<ul>
  <li>Providing and operating platform services.</li>
  <li>Communicating with you about your account and listings.</li>
  <li>Improving user experience and platform development.</li>
  <li>Sending promotional notifications (opt-out available at any time).</li>
  <li>Complying with legal and regulatory requirements.</li>
</ul>

<h2>4. Data Sharing</h2>
<p>We do not sell your data to third parties. We may share your data only with:</p>
<ul>
  <li>Service providers required to operate the platform (payment gateway, hosting).</li>
  <li><strong>Google Firebase</strong> — for phone-number authentication (OTP), chat, file storage, and push notifications. See the <a href="https://firebase.google.com/support/privacy" target="_blank" rel="noopener">Firebase Privacy Policy</a>.</li>
  <li>Government authorities under a court order or legal obligation.</li>
</ul>

<h2>5. Data Security</h2>
<p>We use SSL encryption and strict access controls to protect your data. However, no electronic system can guarantee complete security.</p>

<h2>6. Cookies</h2>
<p>We use cookies to improve your experience and analyze usage. You can configure your browser to reject cookies, though this may affect some platform features.</p>

<h2>7. Your Rights</h2>
<ul>
  <li>Access, correct, or delete your personal data.</li>
  <li>Unsubscribe from marketing communications.</li>
  <li>Withdraw device permissions (location, camera, microphone, notifications) at any time in your device settings.</li>
</ul>

<h2>8. Account &amp; Data Deletion</h2>
<p>You can request deletion of your account and all personal data at any time via our <a href="/en/contact">Contact page</a> — contact our support team and include your registered phone number. Account deletion is permanent and cannot be undone.</p>
<p>We will delete your data within 30 days of the request, except where retention is required for legal or regulatory purposes.</p>

<h2>9. Contact</h2>
<p>For any questions regarding this policy, contact us via our <a href="/en/contact">Contact page</a>.</p>

<p style="color:#888;font-size:0.85em;">Last updated: July 2026</p>
HTML;

        DB::table('static_pages')->where('id', $page->id)->update([
            'content_ar' => $contentAr,
            'content_en' => $contentEn,
        ]);
    }

    public function down(): void
    {
        // Not reversible — the expanded app-data disclosures are intentional.
    }
};
