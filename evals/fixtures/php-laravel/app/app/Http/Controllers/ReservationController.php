<?php

namespace App\Http\Controllers;

use App\Services\ReservationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class ReservationController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $reservation = ReservationService::createReservation($request->all());

        return response()->json(['reservation' => $reservation], 201);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        $reservation = ReservationService::updateReservation($id, $request->all());

        return response()->json(['reservation' => $reservation]);
    }

    public function destroy(string $id): JsonResponse
    {
        $reservation = ReservationService::cancelReservation($id);

        return response()->json(['reservation' => $reservation]);
    }

    public function show(string $id): JsonResponse
    {
        $reservation = ReservationService::getReservation($id);

        return response()->json(['reservation' => $reservation]);
    }
}
