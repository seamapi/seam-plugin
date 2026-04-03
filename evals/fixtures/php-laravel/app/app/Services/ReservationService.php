<?php

namespace App\Services;

use App\Models\Store;

class ReservationService
{
    public static function createReservation(array $data): array
    {
        $unit = Store::findUnit($data['unit_id'] ?? '');
        if (!$unit) {
            throw new \InvalidArgumentException("Unit not found: " . ($data['unit_id'] ?? ''));
        }

        // Find existing guest by email or create a new one
        $guest = null;
        foreach (Store::$guests as $g) {
            if ($g['email'] === ($data['guest_email'] ?? '')) {
                $guest = $g;
                break;
            }
        }

        if (!$guest) {
            $guest = [
                'id' => Store::generateId(),
                'name' => $data['guest_name'] ?? '',
                'email' => $data['guest_email'] ?? '',
            ];
            Store::$guests[] = $guest;
        }

        $reservation = [
            'id' => Store::generateId(),
            'guest_id' => $guest['id'],
            'unit_id' => $data['unit_id'],
            'property_id' => $data['property_id'] ?? 'prop-1',
            'check_in' => $data['check_in'],
            'check_out' => $data['check_out'],
            'status' => 'confirmed',
        ];

        Store::$reservations[] = $reservation;

        return $reservation;
    }

    public static function updateReservation(string $id, array $data): array
    {
        foreach (Store::$reservations as &$reservation) {
            if ($reservation['id'] === $id) {
                if (isset($data['check_in'])) {
                    $reservation['check_in'] = $data['check_in'];
                }
                if (isset($data['check_out'])) {
                    $reservation['check_out'] = $data['check_out'];
                }
                return $reservation;
            }
        }

        throw new \InvalidArgumentException("Reservation not found: {$id}");
    }

    public static function cancelReservation(string $id): array
    {
        foreach (Store::$reservations as &$reservation) {
            if ($reservation['id'] === $id) {
                $reservation['status'] = 'cancelled';
                return $reservation;
            }
        }

        throw new \InvalidArgumentException("Reservation not found: {$id}");
    }

    public static function getReservation(string $id): array
    {
        foreach (Store::$reservations as $reservation) {
            if ($reservation['id'] === $id) {
                return $reservation;
            }
        }

        throw new \InvalidArgumentException("Reservation not found: {$id}");
    }
}
