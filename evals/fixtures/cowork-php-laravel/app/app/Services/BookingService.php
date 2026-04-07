<?php

namespace App\Services;

use App\Models\Store;

class BookingService
{
    public static function createBooking(array $data): array
    {
        $room = Store::findRoom($data['room_id'] ?? '');
        if (!$room) {
            throw new \InvalidArgumentException("Room not found: " . ($data['room_id'] ?? ''));
        }

        // Find existing member by email or create a new one
        $member = null;
        foreach (Store::getMembers() as $m) {
            if ($m['email'] === ($data['member_email'] ?? '')) {
                $member = $m;
                break;
            }
        }

        if (!$member) {
            $member = [
                'id' => Store::generateId(),
                'name' => $data['member_name'] ?? '',
                'email' => $data['member_email'] ?? '',
                'company' => $data['member_company'] ?? '',
            ];
            Store::addMember($member);
        }

        $booking = [
            'id' => Store::generateId(),
            'member_id' => $member['id'],
            'room_id' => $data['room_id'],
            'start_time' => $data['start_time'],
            'end_time' => $data['end_time'],
            'status' => 'active',
        ];

        Store::addBooking($booking);

        return $booking;
    }

    public static function updateBooking(string $id, array $data): array
    {
        $result = Store::updateBookingById($id, function (array $booking) use ($data) {
            if (isset($data['start_time'])) {
                $booking['start_time'] = $data['start_time'];
            }
            if (isset($data['end_time'])) {
                $booking['end_time'] = $data['end_time'];
            }
            return $booking;
        });

        if (!$result) {
            throw new \InvalidArgumentException("Booking not found: {$id}");
        }

        return $result;
    }

    public static function cancelBooking(string $id): array
    {
        $result = Store::updateBookingById($id, function (array $booking) {
            $booking['status'] = 'cancelled';
            return $booking;
        });

        if (!$result) {
            throw new \InvalidArgumentException("Booking not found: {$id}");
        }

        return $result;
    }

    public static function getBooking(string $id): array
    {
        $booking = Store::findBooking($id);

        if (!$booking) {
            throw new \InvalidArgumentException("Booking not found: {$id}");
        }

        return $booking;
    }
}
