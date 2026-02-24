const express = require("express");
const cors    = require("cors");
const helmet  = require("helmet");
const compression = require("compression");

const app = express();

// ── Security ──────────────────────────────────────────────────────────────────
app.use(helmet());

// ── Compression ───────────────────────────────────────────────────────────────
app.use(compression());

// ── CORS ──────────────────────────────────────────────────────────────────────
const allowedOrigins = (process.env.CORS_ORIGIN || "http://localhost:4200").split(",");
app.use(cors({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.includes(origin)) return callback(null, true);
    callback(new Error("Not allowed by CORS"));
  },
  optionsSuccessStatus: 200
}));

// ── Body parsing ──────────────────────────────────────────────────────────────
app.use(express.json({ limit: "10kb" }));
app.use(express.urlencoded({ extended: true, limit: "10kb" }));

// ── Database ──────────────────────────────────────────────────────────────────
const db = require("./app/models");
db.mongoose
  .connect(db.url, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
    maxPoolSize: 10
  })
  .then(() => console.log("Connected to the database!"))
  .catch(err => {
    console.error("Cannot connect to the database!", err);
    process.exit(1);
  });

// ── Health check (used by Docker HEALTHCHECK + load balancer) ─────────────────
app.get("/health", (req, res) => {
  const state = db.mongoose.connection.readyState;
  if (state === 1) {
    return res.status(200).json({ status: "ok", db: "connected" });
  }
  res.status(503).json({ status: "error", db: "disconnected" });
});

// ── Root ──────────────────────────────────────────────────────────────────────
app.get("/", (req, res) => {
  res.json({ message: "Welcome to the Tutorials API." });
});

// ── Routes ────────────────────────────────────────────────────────────────────
require("./app/routes/turorial.routes")(app);

// ── 404 handler ───────────────────────────────────────────────────────────────
app.use((req, res) => res.status(404).json({ message: "Route not found" }));

// ── Global error handler ──────────────────────────────────────────────────────
app.use((err, req, res, _next) => {
  console.error(err.stack);
  res.status(500).json({ message: "Internal server error" });
});

// ── Start ─────────────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 8080;
const server = app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}.`);
});

// Graceful shutdown for Docker SIGTERM
process.on("SIGTERM", () => {
  console.log("SIGTERM received, shutting down gracefully...");
  server.close(() => {
    db.mongoose.connection.close(false, () => {
      console.log("Server and DB connection closed.");
      process.exit(0);
    });
  });
});
