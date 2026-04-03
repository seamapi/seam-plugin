<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\Log;

class WebhookController extends Controller
{
    public function payments(Request $request): JsonResponse
    {
        Log::info('Payment webhook received', $request->all());

        return response()->json(['received' => true]);
    }
}
