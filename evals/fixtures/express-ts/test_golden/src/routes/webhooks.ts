import { Router, Request, Response } from "express";

const router = Router();

router.post("/payments", (req: Request, res: Response) => {
  console.log("Payment webhook received:", req.body);
  res.status(200).json({ received: true });
});

router.post("/seam", (req: Request, res: Response) => {
  const event = req.body;
  switch (event.event_type) {
    case "access_code.set_on_device":
      console.log("Access code set:", event.access_code_id);
      break;
    case "access_code.failed_to_set_on_device":
      console.log("Access code failed:", event.access_code_id);
      break;
    case "device.disconnected":
      console.log("Device disconnected:", event.device_id);
      break;
  }
  res.json({ received: true });
});

export default router;
