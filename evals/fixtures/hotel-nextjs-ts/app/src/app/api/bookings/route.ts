import { NextRequest, NextResponse } from "next/server";
import { createBooking } from "@/lib/services/bookingService";

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { guestName, guestEmail, guestPhone, roomId, checkIn, checkOut } =
      body;

    if (
      !guestName ||
      !guestEmail ||
      !guestPhone ||
      !roomId ||
      !checkIn ||
      !checkOut
    ) {
      return NextResponse.json(
        {
          error:
            "Missing required fields: guestName, guestEmail, guestPhone, roomId, checkIn, checkOut",
        },
        { status: 400 }
      );
    }

    const booking = createBooking({
      guestName,
      guestEmail,
      guestPhone,
      roomId,
      checkIn,
      checkOut,
    });

    return NextResponse.json({ booking }, { status: 201 });
  } catch (err: any) {
    if (err.message?.includes("not found")) {
      return NextResponse.json({ error: err.message }, { status: 404 });
    }
    return NextResponse.json({ error: err.message }, { status: 400 });
  }
}
