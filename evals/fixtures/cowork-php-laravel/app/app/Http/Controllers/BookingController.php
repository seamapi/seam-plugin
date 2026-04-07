<?php

namespace App\Http\Controllers;

use App\Services\BookingService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class BookingController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $booking = BookingService::createBooking($request->all());

        return response()->json(['booking' => $booking], 201);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        $booking = BookingService::updateBooking($id, $request->all());

        return response()->json(['booking' => $booking]);
    }

    public function destroy(string $id): JsonResponse
    {
        $booking = BookingService::cancelBooking($id);

        return response()->json(['booking' => $booking]);
    }

    public function show(string $id): JsonResponse
    {
        $booking = BookingService::getBooking($id);

        return response()->json(['booking' => $booking]);
    }
}
