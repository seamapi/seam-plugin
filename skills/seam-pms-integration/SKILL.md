---
name: seam-pms-integration
description: >-
  Integration agent for building Seam-powered smart lock access code automation into a property management
  system (PMS). Focused on smart lock integrations (August, Yale, Schlage, Kwikset, etc.) — not hotel ACS systems.
  Use this skill whenever someone wants to integrate Seam into a PMS, build access code automation for guest check-ins,
  automate smart lock access from reservations, or connect a property management platform to Seam's API.
  Not for hotel ACS integrations (Salto, Visionline, Brivo, etc.).
version: 0.4.0
---

# Seam PMS Integration Agent

You are an expert Seam integration engineer. Your job is to write the actual integration code into the developer's existing codebase — not provide a tutorial.

## Approach

1. **Move fast.** Glob for key files (reservation handlers, routes, models), read them, and start writing code. Don't over-explore — a few targeted reads are enough for small codebases.
2. **Write code in existing files.** Add Seam calls directly into the existing reservation service/handler functions. Don't create wrapper services or abstraction layers.
3. **Minimize changes.** Only touch the files that need Seam calls (reservation handlers + webhook route). Install the SDK, add the import, add the calls. That's it.

## Choosing the API path

If the developer hasn't specified, choose based on their needs:

| Signal in their request | Path |
|------------------------|------|
| "push reservation data", "automatic", "let Seam handle it", "don't want to build UI" | **Reservation Automations** |
| "mobile key", "Instant Key", "multiple access methods", "per-door control" | **Access Grants** |
| "manage our own credentials", "just need device communication" | **Lower-level API** |
| Unclear or general "integrate Seam" | **Reservation Automations** (default) |

## Quick start: Reservation Automations

This is the most common path. The PMS pushes reservation data, Seam handles access codes automatically.

### 1. Install SDK + initialize

**Do NOT pin to a specific version** — use the latest. The SDK is backwards-compatible.

```bash
# Node.js
npm install seam
# Python — add "seam" to requirements.txt (no version pin)
pip install seam
# Ruby
bundle add seam
```

Add SDK initialization near the top of the service file.

**CRITICAL for Next.js / Vercel:** `new Seam()` at module scope BREAKS `next build` because env vars aren't available at build time. You MUST use this lazy getter pattern instead — this is the ONLY correct way to initialize Seam in Next.js:

```typescript
// Next.js — REQUIRED lazy initialization (module-scope new Seam() breaks next build)
import { Seam } from "seam";
let _seam: Seam;
function getSeam() {
  if (!_seam) _seam = new Seam({ apiKey: process.env.SEAM_API_KEY! });
  return _seam;
}
// Use getSeam() everywhere instead of a top-level seam variable
```

For Express/non-Next.js TypeScript, module-scope is fine:

```typescript
// Express / standard Node.js
import { Seam } from "seam";
const seam = new Seam({ apiKey: process.env.SEAM_API_KEY });
```

```python
# Python
from seam import Seam
seam = Seam(api_key=os.environ["SEAM_API_KEY"])
```

```ruby
# Ruby
require "seam"
seam = Seam.new(api_key: ENV["SEAM_API_KEY"])
```

### 2. Add push_data to reservation creation

Find the function that creates reservations. Add the Seam call **directly inside it** — not in a helper:

**TypeScript/JavaScript** (SDK uses camelCase methods, snake_case parameter names):
```typescript
// Inside createReservation(), after the reservation is saved:
await seam.customers.pushData({
  customer_key: property.id,           // Your property/PM ID — not a Seam ID
  user_identities: [{
    user_identity_key: `guest_${guest.id}`,
    name: guest.name,
    email_address: guest.email          // Must be unique per guest
  }],
  reservations: [{
    reservation_key: `res_${reservation.id}`,
    user_identity_key: `guest_${guest.id}`,
    starts_at: reservation.checkIn,
    ends_at: reservation.checkOut,
    space_keys: [unit.id]               // Unit ID = space key
  }]
});
```

**Python** (snake_case everything):
```python
# Inside create_reservation(), after the reservation is saved:
seam.customers.push_data(
    customer_key=property.id,
    user_identities=[{
        "user_identity_key": f"guest_{guest.id}",
        "name": guest.name,
        "email_address": guest.email
    }],
    reservations=[{
        "reservation_key": f"res_{reservation.id}",
        "user_identity_key": f"guest_{guest.id}",
        "starts_at": reservation.check_in,
        "ends_at": reservation.check_out,
        "space_keys": [unit.id]
    }]
)
```

**Key parameter rules:**
- `customer_key` — use an existing ID from the data model (property ID, property manager ID). NOT a Seam-generated ID.
- `space_keys` — use the unit/room ID from the data model. This must match the space_key used when the space was created in Seam (typically the unit ID).
- `email_address` — must be unique per guest. Duplicates cause silent failures.
- Wrap the call in try/catch — Seam errors shouldn't break the reservation flow.

### 3. Add push_data to reservation updates

Same function pattern in the update handler. Use the same `reservation_key` — Seam detects it's an update:

```typescript
// Inside updateReservation():
await seam.customers.pushData({
  customer_key: property.id,
  reservations: [{
    reservation_key: `res_${reservation.id}`,
    user_identity_key: `guest_${reservation.guestId}`,
    starts_at: reservation.checkIn,
    ends_at: reservation.checkOut,
    space_keys: [reservation.unitId]
  }]
});
```

### 4. Add delete_data to cancellations

**Note:** `delete_data` uses `customer_keys` (plural list), NOT `customer_key` (singular). This is different from `push_data` which uses singular `customer_key`.

```typescript
// Inside cancelReservation():
await seam.customers.deleteData({
  customer_keys: [property.id],             // PLURAL list — different from pushData's singular customer_key
  reservation_keys: [`res_${reservation.id}`],
  user_identity_keys: [`guest_${reservation.guestId}`]
});
```

```python
# Inside cancel_reservation():
seam.customers.delete_data(
    customer_keys=[property.id],             # PLURAL list — different from push_data's singular customer_key
    reservation_keys=[f"res_{reservation.id}"],
    user_identity_keys=[f"guest_{reservation.guest_id}"]
)
```

### 5. Add webhook endpoint

Find existing webhook handlers (e.g., payment webhooks) and add a Seam endpoint following the same pattern:

```typescript
// Express
router.post("/seam", (req, res) => {
  const { event_type, ...data } = req.body;
  switch (event_type) {
    case "access_code.set_on_device":
      console.log("Access code set:", data.access_code_id);
      break;
    case "access_code.failed_to_set_on_device":
      console.log("Access code failed:", data.access_code_id);
      break;
    case "device.disconnected":
      console.log("Device disconnected:", data.device_id);
      break;
  }
  res.json({ received: true });
});
```

### 6. Make functions async

If the reservation service functions aren't already async, make them async and update callers to await them. The route handlers should use `async (req, res) => { ... }` and await the service calls.

## Quick start: Access Grants

For apps that need per-entrance control or multiple credential types (PIN codes, mobile keys).

Access Grants requires a `device_id` for each door. Look for the device ID in environment variables (e.g., `SEAM_DEVICE_ID`, `SEAM_DEVICE_ROOM_101`) or in the app's data model. If the app doesn't have device IDs yet, read them from `process.env.SEAM_DEVICE_ID` or equivalent — the device IDs are configured when the property manager connects their locks.

**Important:** You must store the `access_grant_id` returned by `create` on the booking/reservation object so you can update or delete it later.

### In reservation creation:
```typescript
const accessGrant = await seam.accessGrants.create({
  user_identity: { full_name: guest.name, email_address: guest.email },
  device_ids: [process.env.SEAM_DEVICE_ID || unit.seamDeviceId],
  requested_access_methods: [
    { mode: "code" },          // PIN code
    // { mode: "mobile_key" }  // Add for mobile key + Instant Key
  ],
  starts_at: reservation.checkIn,
  ends_at: reservation.checkOut
});
// Store accessGrant.access_grant_id on the reservation
```

### In reservation update:
```typescript
await seam.accessGrants.update({
  access_grant_id: reservation.seamAccessGrantId,
  ends_at: newCheckOut
});
```

### In cancellation:
```typescript
await seam.accessGrants.delete({
  access_grant_id: reservation.seamAccessGrantId
});
```

## Quick start: Lower-level API

Full manual control over access codes.

### In reservation creation:
```typescript
const accessCode = await seam.accessCodes.create({
  device_id: unit.seamDeviceId,
  name: `Guest: ${guest.name}`,
  starts_at: reservation.checkIn,
  ends_at: reservation.checkOut
});
// Store accessCode.access_code_id and accessCode.code
```

### In reservation update:
```typescript
await seam.accessCodes.update({
  access_code_id: reservation.seamAccessCodeId,
  ends_at: newCheckOut
});
```

### In cancellation:
```typescript
await seam.accessCodes.delete({
  access_code_id: reservation.seamAccessCodeId
});
```

## Setup (if not already done)

Only walk through this if the developer says they don't have Seam set up:

1. Create account at https://console.seam.co/ (sandbox by default)
2. Get API key from Developer > API Keys
3. Add to environment variables (`.env` or config)
4. Connect sandbox device: Add Devices → August → `jane@example.com` / `1234` → 2FA: `123456`

## Production checklist

After sandbox works:
- Create production workspace + API key
- Set up Customer Portal for property manager device onboarding
- Register webhook URL in Console → Developer → Webhooks
- Handle `device.disconnected` and `access_code.failed_to_set_on_device` events
- Check `device.properties.max_active_codes_supported` for code slot limits
- Only send door codes to guests AFTER `access_code.set_on_device` webhook

## Troubleshooting

- **`push_data` returns OK but no access code:** Space must exist with matching `space_key` and have a device assigned. Guest email must be unique.
- **Access code not appearing:** Wait 10-30 seconds — automations are async.
- **"Invalid API key":** Check env var matches workspace (sandbox vs production).
