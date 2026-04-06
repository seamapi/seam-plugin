import { NextRequest, NextResponse } from "next/server";

export async function POST(request: NextRequest) {
  const body = await request.json();
  console.log("Payment webhook received:", JSON.stringify(body));
  return NextResponse.json({ received: true });
}
