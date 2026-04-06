import express from "express";
import bookingRoutes from "./routes/bookings";
import webhookRoutes from "./routes/webhooks";

const app = express();
app.use(express.json());

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.use("/api/bookings", bookingRoutes);
app.use("/webhooks", webhookRoutes);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Hotel booking server running on port ${PORT}`);
});

export default app;
