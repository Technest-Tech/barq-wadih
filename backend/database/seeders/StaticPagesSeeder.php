<?php

namespace Database\Seeders;

use App\Models\StaticPage;
use Illuminate\Database\Seeder;

class StaticPagesSeeder extends Seeder
{
    public function run(): void
    {
        $pages = [
            // ── Terms & Conditions ──────────────────────────────────────────
            [
                'slug'                => 'terms',
                'title_ar'            => 'الشروط والأحكام',
                'title_en'            => 'Terms & Conditions',
                'meta_description_ar' => 'اقرأ شروط وأحكام استخدام منصة برق واضح للإعلانات المبوبة.',
                'meta_description_en' => 'Read the terms and conditions for using the Barq Wadih classifieds platform.',
                'content_ar'          => <<<'HTML'
<h2>أولاً: قبول الشروط</h2>
<p>باستخدامك منصة <strong>برق واضح</strong> أو أيٍّ من خدماتها، فأنت توافق على الالتزام بهذه الشروط والأحكام. إن لم توافق عليها، يُرجى التوقف عن استخدام المنصة.</p>

<h2>ثانياً: وصف الخدمة</h2>
<p>برق واضح منصة إعلانات مبوبة تُتيح للمستخدمين نشر إعلانات البيع والشراء والتأجير داخل المملكة العربية السعودية. المنصة وسيط بين البائعين والمشترين وليست طرفاً في أي صفقة بينهم.</p>

<h2>ثالثاً: التسجيل والحساب</h2>
<ul>
  <li>يجب أن يكون عمرك 18 عاماً أو أكثر لإنشاء حساب.</li>
  <li>تتحمل مسؤولية الحفاظ على سرية بيانات دخولك.</li>
  <li>يُحظر إنشاء حسابات وهمية أو متعددة لنفس الشخص.</li>
  <li>يحق للمنصة تعليق أو حذف أي حساب يُخالف هذه الشروط.</li>
</ul>

<h2>رابعاً: قواعد نشر الإعلانات</h2>
<ul>
  <li>يجب أن تكون المعلومات الواردة في الإعلان صحيحة ودقيقة.</li>
  <li>يُحظر نشر محتوى مخالف للنظام أو الآداب العامة.</li>
  <li>يُحظر نشر سلع مزوّرة أو مسروقة أو ممنوع تداولها نظاماً.</li>
  <li>يُحظر نشر إعلانات مكررة أو احتيالية.</li>
  <li>تحتفظ المنصة بحق إزالة أي إعلان مخالف دون إشعار مسبق.</li>
</ul>

<h2>خامساً: الرسوم والمدفوعات</h2>
<p>قد يستلزم نشر بعض الإعلانات دفع رسوم محددة. تُعرض الرسوم بوضوح قبل إتمام عملية النشر. جميع المدفوعات نهائية وغير قابلة للاسترداد ما لم تنص سياسة الاسترداد على خلاف ذلك.</p>

<h2>سادساً: المسؤولية</h2>
<p>برق واضح غير مسؤولة عن أي خسائر أو أضرار تنشأ عن تعاملات المستخدمين أو صحة المعلومات المنشورة. يتحمل المستخدم المسؤولية الكاملة عن محتوى إعلاناته وتعاملاته.</p>

<h2>سابعاً: التعديلات</h2>
<p>تحتفظ المنصة بحق تعديل هذه الشروط في أي وقت. يُعدّ استمرارك في استخدام المنصة بعد نشر التعديلات قبولاً ضمنياً لها.</p>

<h2>ثامناً: القانون المنظّم</h2>
<p>تخضع هذه الشروط لأنظمة المملكة العربية السعودية، وتختص المحاكم السعودية بالنظر في أي نزاع ينشأ عنها.</p>

<p style="color:#888;font-size:0.85em;">آخر تحديث: يناير 2025</p>
HTML,
                'content_en'          => <<<'HTML'
<h2>1. Acceptance of Terms</h2>
<p>By accessing or using <strong>Barq Wadih</strong>, you agree to be bound by these Terms and Conditions. If you do not agree, please discontinue use of the platform.</p>

<h2>2. Service Description</h2>
<p>Barq Wadih is a classifieds platform allowing users to post buy, sell, and rental listings within Saudi Arabia. The platform acts solely as an intermediary and is not a party to any transaction between users.</p>

<h2>3. Registration & Account</h2>
<ul>
  <li>You must be at least 18 years old to create an account.</li>
  <li>You are responsible for maintaining the confidentiality of your login credentials.</li>
  <li>Creating fake or duplicate accounts is strictly prohibited.</li>
  <li>The platform reserves the right to suspend or delete accounts that violate these Terms.</li>
</ul>

<h2>4. Listing Rules</h2>
<ul>
  <li>All information in a listing must be accurate and truthful.</li>
  <li>Posting content that violates Saudi law or public morals is prohibited.</li>
  <li>Listing counterfeit, stolen, or legally restricted items is prohibited.</li>
  <li>Duplicate or fraudulent listings are not allowed.</li>
  <li>The platform reserves the right to remove any non-compliant listing without prior notice.</li>
</ul>

<h2>5. Fees & Payments</h2>
<p>Some listings may require a fee, which is clearly displayed before publishing. All payments are final and non-refundable unless otherwise stated in the refund policy.</p>

<h2>6. Liability</h2>
<p>Barq Wadih is not liable for any losses or damages arising from user transactions or the accuracy of posted information. Users bear full responsibility for their listing content and dealings.</p>

<h2>7. Modifications</h2>
<p>The platform reserves the right to modify these Terms at any time. Continued use of the platform after changes are published constitutes acceptance of the updated Terms.</p>

<h2>8. Governing Law</h2>
<p>These Terms are governed by the laws of Saudi Arabia. Saudi courts shall have exclusive jurisdiction over any disputes arising from these Terms.</p>

<p style="color:#888;font-size:0.85em;">Last updated: January 2025</p>
HTML,
                'is_published' => true,
            ],

            // ── Privacy Policy ──────────────────────────────────────────────
            [
                'slug'                => 'privacy',
                'title_ar'            => 'سياسة الخصوصية',
                'title_en'            => 'Privacy Policy',
                'meta_description_ar' => 'تعرّف على كيفية جمع بياناتك واستخدامها وحمايتها على منصة برق واضح.',
                'meta_description_en' => 'Learn how Barq Wadih collects, uses, and protects your personal data.',
                'content_ar'          => <<<'HTML'
<h2>١. مقدمة</h2>
<p>تلتزم <strong>برق واضح</strong> بحماية خصوصيتك. تُوضّح هذه السياسة كيفية جمع بياناتك الشخصية واستخدامها ومشاركتها وحمايتها.</p>

<h2>٢. البيانات التي نجمعها</h2>
<ul>
  <li><strong>بيانات الحساب:</strong> الاسم، رقم الجوال، البريد الإلكتروني (اختياري)، الصورة الشخصية.</li>
  <li><strong>بيانات الإعلانات:</strong> المنتج أو الخدمة، الصور، الموقع، معلومات الاتصال.</li>
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
  <li>طلب نسخة من بياناتك عبر صفحة التواصل.</li>
</ul>

<h2>٨. التواصل</h2>
<p>لأي استفسار بشأن هذه السياسة، تواصل معنا عبر <a href="/ar/contact">صفحة التواصل</a>.</p>

<p style="color:#888;font-size:0.85em;">آخر تحديث: يناير 2025</p>
HTML,
                'content_en'          => <<<'HTML'
<h2>1. Introduction</h2>
<p><strong>Barq Wadih</strong> is committed to protecting your privacy. This policy explains how we collect, use, share, and protect your personal data.</p>

<h2>2. Data We Collect</h2>
<ul>
  <li><strong>Account data:</strong> Name, phone number, email (optional), profile photo.</li>
  <li><strong>Listing data:</strong> Product/service details, photos, location, contact information.</li>
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
  <li>Request a copy of your data via the Contact page.</li>
</ul>

<h2>8. Contact</h2>
<p>For any questions regarding this policy, contact us via our <a href="/en/contact">Contact page</a>.</p>

<p style="color:#888;font-size:0.85em;">Last updated: January 2025</p>
HTML,
                'is_published' => true,
            ],

            // ── Fees ─────────────────────────────────────────────────────────
            [
                'slug'                => 'fees',
                'title_ar'            => 'الرسوم والأسعار',
                'title_en'            => 'Fees & Pricing',
                'meta_description_ar' => 'تعرّف على رسوم النشر والعمولات وطرق الدفع على منصة برق واضح.',
                'meta_description_en' => 'Learn about publishing fees, commissions, and payment methods on Barq Wadih.',
                'content_ar'          => <<<'HTML'
<h2>١. رسوم نشر الإعلانات</h2>
<p>تختلف رسوم النشر بحسب فئة الإعلان ونوع البائع (فرد أو تاجر). تُعرض الرسوم بشكل واضح قبل تأكيد النشر.</p>

<table style="width:100%;border-collapse:collapse;margin:16px 0;">
  <thead>
    <tr style="background:#f3f4f6;">
      <th style="padding:10px 14px;text-align:right;border:1px solid #e5e7eb;">الفئة</th>
      <th style="padding:10px 14px;text-align:right;border:1px solid #e5e7eb;">فرد</th>
      <th style="padding:10px 14px;text-align:right;border:1px solid #e5e7eb;">تاجر</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td style="padding:10px 14px;border:1px solid #e5e7eb;">السيارات والمركبات</td>
      <td style="padding:10px 14px;border:1px solid #e5e7eb;">مجاني</td>
      <td style="padding:10px 14px;border:1px solid #e5e7eb;">99 ر.س / شهر</td>
    </tr>
    <tr>
      <td style="padding:10px 14px;border:1px solid #e5e7eb;">العقارات</td>
      <td style="padding:10px 14px;border:1px solid #e5e7eb;">49 ر.س</td>
      <td style="padding:10px 14px;border:1px solid #e5e7eb;">149 ر.س / شهر</td>
    </tr>
    <tr>
      <td style="padding:10px 14px;border:1px solid #e5e7eb;">الإلكترونيات</td>
      <td style="padding:10px 14px;border:1px solid #e5e7eb;">مجاني</td>
      <td style="padding:10px 14px;border:1px solid #e5e7eb;">49 ر.س / شهر</td>
    </tr>
    <tr>
      <td style="padding:10px 14px;border:1px solid #e5e7eb;">باقي الفئات</td>
      <td style="padding:10px 14px;border:1px solid #e5e7eb;">مجاني</td>
      <td style="padding:10px 14px;border:1px solid #e5e7eb;">يختلف حسب الفئة</td>
    </tr>
  </tbody>
</table>

<h2>٢. العمولات</h2>
<p>تُطبَّق عمولة بيع على بعض الفئات تُستحق عند إتمام صفقة البيع:</p>
<ul>
  <li><strong>الأفراد:</strong> 0.5% من قيمة البيع أو 90 ر.س (أيهما أقل).</li>
  <li><strong>التجار:</strong> وفق الاتفاقية المبرمة عند التسجيل كتاجر.</li>
</ul>

<h2>٣. خيارات التمييز والتعزيز</h2>
<ul>
  <li><strong>تمييز الإعلان (Boost):</strong> يرفع إعلانك إلى أعلى نتائج البحث لمدة 7 أو 30 يوماً.</li>
  <li><strong>بانر الواجهة:</strong> عرض إعلانك في البانر الرئيسي للصفحة الأولى.</li>
</ul>

<h2>٤. طرق الدفع</h2>
<p>ندعم طرق الدفع التالية:</p>
<ul>
  <li>بطاقة فيزا / ماستركارد</li>
  <li>مدى</li>
  <li>Apple Pay</li>
  <li>جميع المدفوعات تتم عبر بوابة موي الآمنة</li>
</ul>

<h2>٥. سياسة الاسترداد</h2>
<p>يمكن طلب استرداد رسوم النشر خلال 24 ساعة من الدفع إذا لم يُنشر الإعلان بعد. للطلب، تواصل معنا عبر <a href="/ar/contact">صفحة التواصل</a>.</p>

<p style="color:#888;font-size:0.85em;">آخر تحديث: يناير 2025</p>
HTML,
                'content_en'          => <<<'HTML'
<h2>1. Listing Fees</h2>
<p>Listing fees vary by category and seller type (individual or dealer). Fees are clearly displayed before confirming a listing.</p>

<table style="width:100%;border-collapse:collapse;margin:16px 0;">
  <thead>
    <tr style="background:#f3f4f6;">
      <th style="padding:10px 14px;text-align:left;border:1px solid #e5e7eb;">Category</th>
      <th style="padding:10px 14px;text-align:left;border:1px solid #e5e7eb;">Individual</th>
      <th style="padding:10px 14px;text-align:left;border:1px solid #e5e7eb;">Dealer</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td style="padding:10px 14px;border:1px solid #e5e7eb;">Cars & Vehicles</td>
      <td style="padding:10px 14px;border:1px solid #e5e7eb;">Free</td>
      <td style="padding:10px 14px;border:1px solid #e5e7eb;">SAR 99 / month</td>
    </tr>
    <tr>
      <td style="padding:10px 14px;border:1px solid #e5e7eb;">Real Estate</td>
      <td style="padding:10px 14px;border:1px solid #e5e7eb;">SAR 49</td>
      <td style="padding:10px 14px;border:1px solid #e5e7eb;">SAR 149 / month</td>
    </tr>
    <tr>
      <td style="padding:10px 14px;border:1px solid #e5e7eb;">Electronics</td>
      <td style="padding:10px 14px;border:1px solid #e5e7eb;">Free</td>
      <td style="padding:10px 14px;border:1px solid #e5e7eb;">SAR 49 / month</td>
    </tr>
    <tr>
      <td style="padding:10px 14px;border:1px solid #e5e7eb;">Other Categories</td>
      <td style="padding:10px 14px;border:1px solid #e5e7eb;">Free</td>
      <td style="padding:10px 14px;border:1px solid #e5e7eb;">Varies by category</td>
    </tr>
  </tbody>
</table>

<h2>2. Commissions</h2>
<p>A sales commission applies to some categories upon completing a sale:</p>
<ul>
  <li><strong>Individuals:</strong> 0.5% of sale value or SAR 90 (whichever is lower).</li>
  <li><strong>Dealers:</strong> Per the agreement made during dealer registration.</li>
</ul>

<h2>3. Boost & Promotion Options</h2>
<ul>
  <li><strong>Listing Boost:</strong> Push your listing to the top of search results for 7 or 30 days.</li>
  <li><strong>Homepage Banner:</strong> Display your listing on the main banner of the homepage.</li>
</ul>

<h2>4. Payment Methods</h2>
<p>We support the following payment methods:</p>
<ul>
  <li>Visa / Mastercard</li>
  <li>Mada</li>
  <li>Apple Pay</li>
  <li>All payments are processed through the secure Moyasar gateway</li>
</ul>

<h2>5. Refund Policy</h2>
<p>Listing fee refunds can be requested within 24 hours of payment if the listing has not yet been published. To request a refund, contact us via the <a href="/en/contact">Contact page</a>.</p>

<p style="color:#888;font-size:0.85em;">Last updated: January 2025</p>
HTML,
                'is_published' => true,
            ],

            // ── How We Buy ───────────────────────────────────────────────────
            [
                'slug'                => 'how-we-buy',
                'title_ar'            => 'كيف نشتري',
                'title_en'            => 'How to Buy',
                'meta_description_ar' => 'تعلّم كيف تشتري بأمان من خلال منصة برق واضح.',
                'meta_description_en' => 'Learn how to buy safely through the Barq Wadih platform.',
                'content_ar'          => <<<'HTML'
<h2>اشترِ بثقة في 5 خطوات</h2>

<div style="counter-reset:step;">

<div style="display:flex;gap:16px;align-items:flex-start;margin-bottom:24px;">
  <div style="min-width:40px;height:40px;background:linear-gradient(135deg,#6366f1,#8b5cf6);border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:1.1rem;">١</div>
  <div>
    <h3 style="margin:0 0 6px;">ابحث عن ما تريد</h3>
    <p style="margin:0;color:#555;">استخدم شريط البحث أو تصفّح الأقسام للعثور على ما تبحث عنه. استخدم الفلاتر (المنطقة، السعر، الحالة) لتضييق نطاق النتائج.</p>
  </div>
</div>

<div style="display:flex;gap:16px;align-items:flex-start;margin-bottom:24px;">
  <div style="min-width:40px;height:40px;background:linear-gradient(135deg,#6366f1,#8b5cf6);border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:1.1rem;">٢</div>
  <div>
    <h3 style="margin:0 0 6px;">تحقق من الإعلان</h3>
    <p style="margin:0;color:#555;">اقرأ وصف الإعلان بعناية وشاهد جميع الصور. تحقق من تقييمات البائع وتاريخ نشاطه على المنصة.</p>
  </div>
</div>

<div style="display:flex;gap:16px;align-items:flex-start;margin-bottom:24px;">
  <div style="min-width:40px;height:40px;background:linear-gradient(135deg,#6366f1,#8b5cf6);border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:1.1rem;">٣</div>
  <div>
    <h3 style="margin:0 0 6px;">تواصل مع البائع</h3>
    <p style="margin:0;color:#555;">استخدم نظام المحادثة الداخلي للتواصل مع البائع. اسأل عن أي تفاصيل إضافية أو تفاوض على السعر.</p>
  </div>
</div>

<div style="display:flex;gap:16px;align-items:flex-start;margin-bottom:24px;">
  <div style="min-width:40px;height:40px;background:linear-gradient(135deg,#6366f1,#8b5cf6);border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:1.1rem;">٤</div>
  <div>
    <h3 style="margin:0 0 6px;">اتفق على الصفقة</h3>
    <p style="margin:0;color:#555;">حدد موعداً لمعاينة المنتج في مكان عام وآمن. لا تحوّل أموالاً قبل استلام المنتج والتأكد من حالته.</p>
  </div>
</div>

<div style="display:flex;gap:16px;align-items:flex-start;margin-bottom:24px;">
  <div style="min-width:40px;height:40px;background:linear-gradient(135deg,#6366f1,#8b5cf6);border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:1.1rem;">٥</div>
  <div>
    <h3 style="margin:0 0 6px;">قيّم تجربتك</h3>
    <p style="margin:0;color:#555;">بعد إتمام الصفقة، قيّم البائع لمساعدة المشترين الآخرين. تقييماتك تُسهم في بناء مجتمع موثوق.</p>
  </div>
</div>

</div>

<h2>نصائح للشراء الآمن</h2>
<ul>
  <li>التقِ بالبائع في مكان عام (مركز تجاري، محطة وقود، إلخ).</li>
  <li>لا تُرسل أموالاً مسبقاً لأشخاص غير موثوقين.</li>
  <li>احذر من الأسعار المنخفضة بشكل غير طبيعي — قد تكون عمليات احتيال.</li>
  <li>استخدم نظام المحادثة الداخلي ولا تنقل التواصل لتطبيقات أخرى.</li>
  <li>في حال اشتباهك بإعلان مزيّف، بلّغ عنه فوراً من خلال زر "الإبلاغ".</li>
</ul>
HTML,
                'content_en'          => <<<'HTML'
<h2>Buy with Confidence in 5 Steps</h2>

<div style="display:flex;gap:16px;align-items:flex-start;margin-bottom:24px;">
  <div style="min-width:40px;height:40px;background:linear-gradient(135deg,#6366f1,#8b5cf6);border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:1.1rem;">1</div>
  <div>
    <h3 style="margin:0 0 6px;">Search for What You Need</h3>
    <p style="margin:0;color:#555;">Use the search bar or browse categories to find what you're looking for. Use filters (region, price, condition) to narrow results.</p>
  </div>
</div>

<div style="display:flex;gap:16px;align-items:flex-start;margin-bottom:24px;">
  <div style="min-width:40px;height:40px;background:linear-gradient(135deg,#6366f1,#8b5cf6);border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:1.1rem;">2</div>
  <div>
    <h3 style="margin:0 0 6px;">Review the Listing</h3>
    <p style="margin:0;color:#555;">Read the listing description carefully and view all photos. Check the seller's ratings and activity history on the platform.</p>
  </div>
</div>

<div style="display:flex;gap:16px;align-items:flex-start;margin-bottom:24px;">
  <div style="min-width:40px;height:40px;background:linear-gradient(135deg,#6366f1,#8b5cf6);border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:1.1rem;">3</div>
  <div>
    <h3 style="margin:0 0 6px;">Contact the Seller</h3>
    <p style="margin:0;color:#555;">Use the built-in messaging system to communicate with the seller. Ask for additional details or negotiate the price.</p>
  </div>
</div>

<div style="display:flex;gap:16px;align-items:flex-start;margin-bottom:24px;">
  <div style="min-width:40px;height:40px;background:linear-gradient(135deg,#6366f1,#8b5cf6);border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:1.1rem;">4</div>
  <div>
    <h3 style="margin:0 0 6px;">Agree on the Deal</h3>
    <p style="margin:0;color:#555;">Arrange to view the item in a safe, public place. Do not transfer money before receiving the item and verifying its condition.</p>
  </div>
</div>

<div style="display:flex;gap:16px;align-items:flex-start;margin-bottom:24px;">
  <div style="min-width:40px;height:40px;background:linear-gradient(135deg,#6366f1,#8b5cf6);border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:1.1rem;">5</div>
  <div>
    <h3 style="margin:0 0 6px;">Rate Your Experience</h3>
    <p style="margin:0;color:#555;">After completing the deal, rate the seller to help other buyers. Your ratings help build a trustworthy community.</p>
  </div>
</div>

<h2>Safe Buying Tips</h2>
<ul>
  <li>Meet the seller in a public place (mall, gas station, etc.).</li>
  <li>Never send money in advance to unverified individuals.</li>
  <li>Be cautious of abnormally low prices — they may be scams.</li>
  <li>Use the built-in chat system and avoid moving communication to other apps.</li>
  <li>If you suspect a fraudulent listing, report it immediately using the "Report" button.</li>
</ul>
HTML,
                'is_published' => true,
            ],

            // ── How We Sell ──────────────────────────────────────────────────
            [
                'slug'                => 'how-we-sell',
                'title_ar'            => 'كيف نبيع',
                'title_en'            => 'How to Sell',
                'meta_description_ar' => 'تعلّم كيف تنشر إعلانك وتبيع منتجاتك بسهولة على منصة برق واضح.',
                'meta_description_en' => 'Learn how to post your listing and sell your items on Barq Wadih.',
                'content_ar'          => <<<'HTML'
<h2>ابدأ البيع في دقائق</h2>

<div style="display:flex;gap:16px;align-items:flex-start;margin-bottom:24px;">
  <div style="min-width:40px;height:40px;background:linear-gradient(135deg,#22c55e,#16a34a);border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:1.1rem;">١</div>
  <div>
    <h3 style="margin:0 0 6px;">أنشئ حسابك</h3>
    <p style="margin:0;color:#555;">سجّل بحسابك باستخدام رقم جوالك أو بريدك الإلكتروني. التسجيل مجاني ويستغرق أقل من دقيقة.</p>
  </div>
</div>

<div style="display:flex;gap:16px;align-items:flex-start;margin-bottom:24px;">
  <div style="min-width:40px;height:40px;background:linear-gradient(135deg,#22c55e,#16a34a);border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:1.1rem;">٢</div>
  <div>
    <h3 style="margin:0 0 6px;">اختر الفئة المناسبة</h3>
    <p style="margin:0;color:#555;">اضغط على "نشر إعلان" واختر الفئة الأنسب لمنتجك. الفئة الصحيحة تزيد من وصول إعلانك.</p>
  </div>
</div>

<div style="display:flex;gap:16px;align-items:flex-start;margin-bottom:24px;">
  <div style="min-width:40px;height:40px;background:linear-gradient(135deg,#22c55e,#16a34a);border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:1.1rem;">٣</div>
  <div>
    <h3 style="margin:0 0 6px;">أضف التفاصيل والصور</h3>
    <p style="margin:0;color:#555;">اكتب عنواناً واضحاً ووصفاً دقيقاً. أضف صوراً عالية الجودة من زوايا متعددة — الإعلانات ذات الصور تحصل على 5 أضعاف المشاهدات.</p>
  </div>
</div>

<div style="display:flex;gap:16px;align-items:flex-start;margin-bottom:24px;">
  <div style="min-width:40px;height:40px;background:linear-gradient(135deg,#22c55e,#16a34a);border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:1.1rem;">٤</div>
  <div>
    <h3 style="margin:0 0 6px;">حدد السعر والموقع</h3>
    <p style="margin:0;color:#555;">اضبط سعراً تنافسياً وحدد موقعك بدقة لجذب المشترين في منطقتك. يمكنك تفعيل خيار "قابل للتفاوض".</p>
  </div>
</div>

<div style="display:flex;gap:16px;align-items:flex-start;margin-bottom:24px;">
  <div style="min-width:40px;height:40px;background:linear-gradient(135deg,#22c55e,#16a34a);border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:1.1rem;">٥</div>
  <div>
    <h3 style="margin:0 0 6px;">انشر وراقب</h3>
    <p style="margin:0;color:#555;">بعد مراجعة الإعلان من فريقنا (خلال ساعات)، سيظهر للمشترين. تابع الرسائل الواردة وردّ عليها بسرعة لإتمام الصفقة.</p>
  </div>
</div>

<h2>نصائح لإعلان ناجح</h2>
<ul>
  <li>اكتب عنواناً يحتوي على اسم المنتج والموديل والسنة إن وجدت.</li>
  <li>التقط صوراً في ضوء طبيعي وجيد.</li>
  <li>ابدأ بأعلى سعر مقبول وأتح خيار التفاوض.</li>
  <li>ردّ على الرسائل بسرعة — الاستجابة السريعة تزيد فرص البيع.</li>
  <li>جدّد إعلانك أو عزّزه إذا أردت ظهوراً أكثر في نتائج البحث.</li>
</ul>

<h2>هل أنت تاجر؟</h2>
<p>إذا كنت تبيع بكميات تجارية، سجّل كتاجر واستفد من مزايا حساب التاجر: إعلانات غير محدودة، أولوية في البحث، لوحة تحكم متخصصة، ودعم مميز.</p>
HTML,
                'content_en'          => <<<'HTML'
<h2>Start Selling in Minutes</h2>

<div style="display:flex;gap:16px;align-items:flex-start;margin-bottom:24px;">
  <div style="min-width:40px;height:40px;background:linear-gradient(135deg,#22c55e,#16a34a);border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:1.1rem;">1</div>
  <div>
    <h3 style="margin:0 0 6px;">Create Your Account</h3>
    <p style="margin:0;color:#555;">Register using your phone number or email. Registration is free and takes less than a minute.</p>
  </div>
</div>

<div style="display:flex;gap:16px;align-items:flex-start;margin-bottom:24px;">
  <div style="min-width:40px;height:40px;background:linear-gradient(135deg,#22c55e,#16a34a);border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:1.1rem;">2</div>
  <div>
    <h3 style="margin:0 0 6px;">Choose the Right Category</h3>
    <p style="margin:0;color:#555;">Click "Post Listing" and select the most appropriate category. The right category increases your listing's reach.</p>
  </div>
</div>

<div style="display:flex;gap:16px;align-items:flex-start;margin-bottom:24px;">
  <div style="min-width:40px;height:40px;background:linear-gradient(135deg,#22c55e,#16a34a);border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:1.1rem;">3</div>
  <div>
    <h3 style="margin:0 0 6px;">Add Details & Photos</h3>
    <p style="margin:0;color:#555;">Write a clear title and accurate description. Add high-quality photos from multiple angles — listings with photos get 5x more views.</p>
  </div>
</div>

<div style="display:flex;gap:16px;align-items:flex-start;margin-bottom:24px;">
  <div style="min-width:40px;height:40px;background:linear-gradient(135deg,#22c55e,#16a34a);border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:1.1rem;">4</div>
  <div>
    <h3 style="margin:0 0 6px;">Set Price & Location</h3>
    <p style="margin:0;color:#555;">Set a competitive price and pinpoint your location to attract buyers in your area. Enable the "Negotiable" option if applicable.</p>
  </div>
</div>

<div style="display:flex;gap:16px;align-items:flex-start;margin-bottom:24px;">
  <div style="min-width:40px;height:40px;background:linear-gradient(135deg,#22c55e,#16a34a);border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:1.1rem;">5</div>
  <div>
    <h3 style="margin:0 0 6px;">Publish & Monitor</h3>
    <p style="margin:0;color:#555;">After our team reviews your listing (within hours), it goes live. Monitor incoming messages and reply quickly to close deals.</p>
  </div>
</div>

<h2>Tips for a Successful Listing</h2>
<ul>
  <li>Write a title that includes the product name, model, and year if applicable.</li>
  <li>Take photos in good natural light.</li>
  <li>Start with your highest acceptable price and allow negotiation.</li>
  <li>Reply to messages quickly — fast responses increase your chances of selling.</li>
  <li>Refresh or boost your listing for greater visibility in search results.</li>
</ul>

<h2>Are You a Dealer?</h2>
<p>If you sell in commercial quantities, register as a dealer and enjoy dealer account benefits: unlimited listings, priority in search, a dedicated dashboard, and premium support.</p>
HTML,
                'is_published' => true,
            ],

            // ── Contact Us (informational page — has dedicated form page) ───
            [
                'slug'                => 'contact-info',
                'title_ar'            => 'معلومات التواصل',
                'title_en'            => 'Contact Information',
                'meta_description_ar' => 'تواصل مع فريق دعم برق واضح.',
                'meta_description_en' => 'Contact Barq Wadih support team.',
                'content_ar'          => <<<'HTML'
<h2>فريق الدعم</h2>
<p>نحن هنا لمساعدتك. يمكنك التواصل معنا عبر النموذج أو البريد الإلكتروني أدناه.</p>
<ul>
  <li><strong>البريد الإلكتروني:</strong> support@barqwadih.com</li>
  <li><strong>ساعات العمل:</strong> السبت – الخميس، 9 صباحاً – 9 مساءً</li>
  <li><strong>مدة الاستجابة:</strong> خلال يوم عمل واحد</li>
</ul>
HTML,
                'content_en'          => <<<'HTML'
<h2>Support Team</h2>
<p>We're here to help. You can reach us via the form or email below.</p>
<ul>
  <li><strong>Email:</strong> support@barqwadih.com</li>
  <li><strong>Working hours:</strong> Saturday – Thursday, 9 AM – 9 PM</li>
  <li><strong>Response time:</strong> Within one business day</li>
</ul>
HTML,
                'is_published' => true,
            ],
        ];

        foreach ($pages as $data) {
            StaticPage::updateOrCreate(['slug' => $data['slug']], $data);
        }

        $this->command->info('Static pages seeded: ' . implode(', ', array_column($pages, 'slug')));
    }
}
