<?php

namespace App\Traits;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Http\Resources\Json\ResourceCollection;

trait ApiResponses
{
    /**
     * Return a success JSON response.
     */
    protected function successResponse(
        mixed $data = null,
        string $message = '',
        int $code = 200,
    ): JsonResponse {
        $response = [
            'success' => true,
        ];

        if ($message) {
            $response['message'] = $message;
        }

        if ($data instanceof ResourceCollection) {
            return $data->additional($response)->response()->setStatusCode($code);
        }

        if ($data instanceof JsonResource) {
            return $data->additional($response)->response()->setStatusCode($code);
        }

        $response['data'] = $data;

        return response()->json($response, $code);
    }

    /**
     * Return an error JSON response.
     */
    protected function errorResponse(
        string $message,
        int $code = 400,
        mixed $errors = null,
    ): JsonResponse {
        $response = [
            'success' => false,
            'message' => $message,
        ];

        if ($errors !== null) {
            $response['errors'] = $errors;
        }

        return response()->json($response, $code);
    }

    /**
     * Return a paginated JSON response.
     */
    protected function paginatedResponse(
        ResourceCollection $collection,
        string $message = '',
    ): JsonResponse {
        $additional = [
            'success' => true,
        ];

        if ($message) {
            $additional['message'] = $message;
        }

        return $collection->additional($additional)->response();
    }
}
