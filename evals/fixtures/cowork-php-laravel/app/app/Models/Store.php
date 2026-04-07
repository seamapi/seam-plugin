<?php

namespace App\Models;

class Store
{
    private static string $filePath = '/tmp/cowork_store.json';

    private static function load(): array
    {
        if (!file_exists(self::$filePath)) {
            return [
                'idCounter' => 0,
                'members' => [],
                'rooms' => [
                    ['id' => 'room-a1', 'name' => 'Focus Room A1', 'capacity' => 1, 'floor' => 1],
                    ['id' => 'room-b2', 'name' => 'Meeting Room B2', 'capacity' => 6, 'floor' => 2],
                    ['id' => 'room-c3', 'name' => 'Board Room C3', 'capacity' => 12, 'floor' => 3],
                ],
                'bookings' => [],
            ];
        }

        return json_decode(file_get_contents(self::$filePath), true);
    }

    private static function save(array $data): void
    {
        file_put_contents(self::$filePath, json_encode($data));
    }

    public static function generateId(): string
    {
        $data = self::load();
        $data['idCounter']++;
        self::save($data);
        return 'id-' . time() . '-' . $data['idCounter'];
    }

    public static function getMembers(): array
    {
        return self::load()['members'];
    }

    public static function addMember(array $member): void
    {
        $data = self::load();
        $data['members'][] = $member;
        self::save($data);
    }

    public static function getBookings(): array
    {
        return self::load()['bookings'];
    }

    public static function addBooking(array $booking): void
    {
        $data = self::load();
        $data['bookings'][] = $booking;
        self::save($data);
    }

    public static function updateBookingById(string $id, callable $updater): ?array
    {
        $data = self::load();
        foreach ($data['bookings'] as &$booking) {
            if ($booking['id'] === $id) {
                $booking = $updater($booking);
                self::save($data);
                return $booking;
            }
        }
        return null;
    }

    public static function findRoom(string $id): ?array
    {
        $data = self::load();
        foreach ($data['rooms'] as $room) {
            if ($room['id'] === $id) {
                return $room;
            }
        }
        return null;
    }

    public static function findMember(string $id): ?array
    {
        $data = self::load();
        foreach ($data['members'] as $member) {
            if ($member['id'] === $id) {
                return $member;
            }
        }
        return null;
    }

    public static function findBooking(string $id): ?array
    {
        $data = self::load();
        foreach ($data['bookings'] as $booking) {
            if ($booking['id'] === $id) {
                return $booking;
            }
        }
        return null;
    }
}
