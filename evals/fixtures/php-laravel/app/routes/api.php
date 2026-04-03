<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\ReservationController;
use App\Http\Controllers\WebhookController;

Route::post('/reservations', [ReservationController::class, 'store']);
Route::put('/reservations/{id}', [ReservationController::class, 'update']);
Route::delete('/reservations/{id}', [ReservationController::class, 'destroy']);
Route::get('/reservations/{id}', [ReservationController::class, 'show']);

Route::post('/webhooks/payments', [WebhookController::class, 'payments']);
