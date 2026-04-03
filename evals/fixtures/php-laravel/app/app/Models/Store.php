<?php

namespace App\Models;

class Store
{
    private static int $idCounter = 0;

    public static array $guests = [];

    public static array $properties = [
        [
            'id' => 'prop-1',
            'name' => 'Sunset Rentals',
            'address' => '123 Sunset Blvd, Los Angeles, CA 90028',
        ],
    ];

    public static array $units = [
        ['id' => 'unit-101', 'property_id' => 'prop-1', 'name' => 'Unit 101'],
        ['id' => 'unit-202', 'property_id' => 'prop-1', 'name' => 'Unit 202'],
    ];

    public static array $reservations = [];

    public static function generateId(): string
    {
        self::$idCounter++;
        return 'id-' . time() . '-' . self::$idCounter;
    }

    public static function findUnit(string $id): ?array
    {
        foreach (self::$units as $unit) {
            if ($unit['id'] === $id) {
                return $unit;
            }
        }
        return null;
    }

    public static function findGuest(string $id): ?array
    {
        foreach (self::$guests as $guest) {
            if ($guest['id'] === $id) {
                return $guest;
            }
        }
        return null;
    }
}
