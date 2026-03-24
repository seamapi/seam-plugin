import express from "express";
import reservationRoutes from "./routes/reservations";
import webhookRoutes from "./routes/webhooks";

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.use("/api/reservations", reservationRoutes);
app.use("/webhooks", webhookRoutes);

app.listen(PORT, () => {
  console.log(`PMS server running on port ${PORT}`);
});

export default app;
