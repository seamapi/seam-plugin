import { NextRequest, NextResponse } from "next/server";
import {
  getBooking,
  updateBooking,
  cancelBooking,
} from "@/lib/services/bookingService";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const booking = getBooking((await params).id);
    return NextResponse.json({ booking });
  } catch (err: any) {
    if (err.message?.includes("not found")) {
      return NextResponse.json({ error: err.message }, { status: 404 });
    }
    return NextResponse.json({ error: err.message }, { status: 400 });
  }
}

export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const body = await request.json();
    const { checkIn, checkOut } = body;
    const booking = updateBooking((await params).id, { checkIn, checkOut });
    return NextResponse.json({ booking }, { status: 200 });
  } catch (err: any) {
    if (err.message?.includes("not found")) {
      return NextResponse.json({ error: err.message }, { status: 404 });
    }
    return NextResponse.json({ error: err.message }, { status: 400 });
  }
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const booking = cancelBooking((await params).id);
    return NextResponse.json({ booking }, { status: 200 });
  } catch (err: any) {
    if (err.message?.includes("not found")) {
      return NextResponse.json({ error: err.message }, { status: 404 });
    }
    return NextResponse.json({ error: err.message }, { status: 400 });
  }
}
