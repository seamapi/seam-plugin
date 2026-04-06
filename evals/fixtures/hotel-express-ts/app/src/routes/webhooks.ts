import { Router, Request, Response } from "express";

const router = Router();

router.post("/payments", (req: Request, res: Response) => {
  console.log("Payment webhook received:", req.body);
  res.json({ received: true });
});

export default router;
