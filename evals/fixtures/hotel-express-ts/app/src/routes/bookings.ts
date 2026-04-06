import { Router, Request, Response } from "express";
import {
  createBooking,
  updateBooking,
  cancelBooking,
  getBooking,
} from "../services/bookingService";

const router = Router();

router.post("/", (req: Request, res: Response) => {
  try {
    const booking = createBooking(req.body);
    res.status(201).json({ booking });
  } catch (err: any) {
    if (err.message?.includes("not found")) {
      res.status(404).json({ error: err.message });
    } else {
      res.status(400).json({ error: err.message });
    }
  }
});

router.put("/:id", (req: Request, res: Response) => {
  try {
    const booking = updateBooking(req.params.id, req.body);
    res.status(200).json({ booking });
  } catch (err: any) {
    if (err.message?.includes("not found")) {
      res.status(404).json({ error: err.message });
    } else {
      res.status(400).json({ error: err.message });
    }
  }
});

router.delete("/:id", (req: Request, res: Response) => {
  try {
    const booking = cancelBooking(req.params.id);
    res.status(200).json({ booking });
  } catch (err: any) {
    if (err.message?.includes("not found")) {
      res.status(404).json({ error: err.message });
    } else {
      res.status(400).json({ error: err.message });
    }
  }
});

router.get("/:id", (req: Request, res: Response) => {
  try {
    const booking = getBooking(req.params.id);
    res.status(200).json({ booking });
  } catch (err: any) {
    if (err.message?.includes("not found")) {
      res.status(404).json({ error: err.message });
    } else {
      res.status(400).json({ error: err.message });
    }
  }
});

export default router;
