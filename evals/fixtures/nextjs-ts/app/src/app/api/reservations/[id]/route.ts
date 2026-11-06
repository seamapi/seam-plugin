import { NextRequest, NextResponse } from "next/server";
import {
  getReservation,
  updateReservation,
  cancelReservation,
} from "@/lib/services/reservationService";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const reservation = getReservation((await params).id);
    return NextResponse.json({ reservation });
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
    const reservation = updateReservation((await params).id, { checkIn, checkOut });
    return NextResponse.json({ reservation }, { status: 200 });
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
    const reservation = cancelReservation((await params).id);
    return NextResponse.json({ reservation }, { status: 200 });
  } catch (err: any) {
    if (err.message?.includes("not found")) {
      return NextResponse.json({ error: err.message }, { status: 404 });
    }
    return NextResponse.json({ error: err.message }, { status: 400 });
  }
}
