<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\QuestionResource;
use App\Models\Ad;
use App\Models\AdQuestion;
use App\Traits\ApiResponses;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class QuestionController extends Controller
{
    use ApiResponses;

    // ── GET /ads/{ad}/questions ───────────────────────────────────────────────

    public function index(Ad $ad): AnonymousResourceCollection
    {
        $questions = AdQuestion::with(['user', 'replies'])
            ->where('ad_id', $ad->id)
            ->whereNull('parent_id')
            ->latest()
            ->paginate(20);

        return QuestionResource::collection($questions);
    }

    // ── POST /ads/{ad}/questions ──────────────────────────────────────────────

    public function store(Request $request, Ad $ad): JsonResponse
    {
        $data = $request->validate([
            'body' => 'required|string|max:1000',
        ]);

        $question = AdQuestion::create([
            'ad_id'   => $ad->id,
            'user_id' => $request->user()->id,
            'body'    => $data['body'],
        ]);

        $question->load(['user', 'replies']);

        return $this->successResponse(new QuestionResource($question), 'تم إرسال سؤالك بنجاح', 201);
    }

    // ── POST /questions/{question}/reply ──────────────────────────────────────

    public function reply(Request $request, AdQuestion $question): JsonResponse
    {
        // Only allow replies on root-level questions (no nested replies)
        if ($question->parent_id !== null) {
            return $this->errorResponse('لا يمكن الرد على رد', 422);
        }

        $data = $request->validate([
            'body' => 'required|string|max:1000',
        ]);

        $reply = AdQuestion::create([
            'ad_id'     => $question->ad_id,
            'user_id'   => $request->user()->id,
            'parent_id' => $question->id,
            'body'      => $data['body'],
        ]);

        $reply->load('user');

        return $this->successResponse(new QuestionResource($reply), 'تم إرسال ردك بنجاح', 201);
    }
}
