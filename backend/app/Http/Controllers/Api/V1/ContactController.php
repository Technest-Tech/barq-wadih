<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ContactSubmission;
use App\Traits\ApiResponses;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ContactController extends Controller
{
    use ApiResponses;

    // Keep this list aligned with the actual, currently available app flows.
    private const CATEGORIES = [
        [
            'slug' => 'fees',
            'label' => 'العمولات وطرق الدفع',
            'faqs' => [
                [
                    'q' => 'ما هي طرق الدفع المتاحة؟',
                    'a' => 'الدفع المتاح حالياً هو التحويل البنكي، ثم إرفاق صورة الإيصال من داخل التطبيق لمراجعته.',
                ],
                [
                    'q' => 'هل توجد رسوم لنشر الإعلان؟',
                    'a' => 'لا. نشر الإعلان مجاني ولا يُطلب أي دفع قبل ظهوره.',
                ],
                [
                    'q' => 'متى تُدفع العمولة؟',
                    'a' => 'تُدفع بعد إتمام البيع: 99 ريالاً للسيارات، و10 ريالات للفئات الأخرى الخاضعة للعمولة، بينما الوظائف مجانية.',
                ],
            ],
        ],
        [
            'slug' => 'safety',
            'label' => 'السلامة والبلاغات',
            'faqs' => [
                [
                    'q' => 'كيف أبلّغ عن إعلان مخالف؟',
                    'a' => 'افتح الإعلان واضغط «إبلاغ»، ثم اختر السبب وأرسل البلاغ. يراجع فريقنا البلاغات ويتخذ الإجراء المناسب.',
                ],
                [
                    'q' => 'كيف أحظر مستخدماً؟',
                    'a' => 'افتح ملف المستخدم أو خيارات المحادثة واضغط «حظر». لن يتمكن المستخدم المحظور من التواصل معك.',
                ],
            ],
        ],
        [
            'slug' => 'members',
            'label' => 'الأعضاء',
            'faqs' => [
                [
                    'q' => 'كيف أُفعّل حسابي؟',
                    'a' => 'يتم تفعيل الحساب تلقائياً عند التسجيل بالبريد الإلكتروني. رقم الجوال اختياري ويمكن استخدامه لتسجيل الدخول أو التحقق.',
                ],
                [
                    'q' => 'كيف أغيّر معلوماتي الشخصية؟',
                    'a' => 'من ملفك الشخصي اضغط على "تعديل الملف الشخصي" وقم بتحديث بياناتك ثم احفظ التغييرات.',
                ],
                [
                    'q' => 'كيف أحذف حسابي؟',
                    'a' => 'من ملفك الشخصي اختر «حذف الحساب والبيانات نهائياً»، واكتب كلمة «حذف» ثم أكّد العملية.',
                ],
            ],
        ],
        [
            'slug' => 'chat',
            'label' => 'المحادثات',
            'faqs' => [
                [
                    'q' => 'ماذا يمكنني إرساله في المحادثة؟',
                    'a' => 'يمكنك إرسال نصوص وصور ورسائل صوتية للتواصل بشأن الإعلان، مع الالتزام بقواعد الاستخدام.',
                ],
                [
                    'q' => 'كيف أوقف تواصل مستخدم؟',
                    'a' => 'يمكنك حظر المستخدم من خيارات المحادثة أو ملفه الشخصي.',
                ],
            ],
        ],
        [
            'slug' => 'ads',
            'label' => 'الإعلانات (نشر - تعديل - حذف)',
            'faqs' => [
                [
                    'q' => 'كيف أنشر إعلاناً؟',
                    'a' => 'اضغط على زر "نشر إعلان" وأدخل التفاصيل المطلوبة ثم وافق على التعهد واضغط "نشر". النشر مجاني.',
                ],
                [
                    'q' => 'كيف أعدّل إعلاني؟',
                    'a' => 'من صفحة "إعلاناتي" اختر الإعلان المراد تعديله واضغط على "تعديل" وأجرِ التغييرات واحفظها.',
                ],
                [
                    'q' => 'كيف أحذف إعلاني؟',
                    'a' => 'من صفحة "إعلاناتي" اختر الإعلان واضغط على "حذف". تنبيه: لا يمكن التراجع عن الحذف.',
                ],
            ],
        ],
    ];

    // ── GET /contact/categories ───────────────────────────────────────────────

    public function categories(): JsonResponse
    {
        return $this->successResponse(self::CATEGORIES);
    }

    // ── POST /contact ─────────────────────────────────────────────────────────

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => 'required|string|max:100',
            'email' => 'required|email|max:255',
            'phone' => 'nullable|string|max:20',
            'category' => 'nullable|string|max:100',
            'message' => 'required|string|min:10|max:2000',
        ]);

        $category = $data['category'] ?? null;
        $cat = $category
            ? collect(self::CATEGORIES)->firstWhere('slug', $category)
            : null;

        ContactSubmission::create([
            'user_id' => $request->user()?->id,
            'name' => $data['name'],
            'email' => $data['email'],
            'phone' => $data['phone'] ?? null,
            'category' => $category,
            'category_label' => $cat['label'] ?? $category,
            'message' => $data['message'],
        ]);

        return $this->successResponse(
            null,
            'تم إرسال رسالتك بنجاح. سيتواصل معك فريق الدعم قريباً.',
            201,
        );
    }
}
