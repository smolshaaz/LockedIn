import { Hono } from "hono"
import { cors } from "hono/cors"
import { chatRoutes } from "./routes/chat-routes"
import { checkinRoutes } from "./routes/checkin-routes"
import { lifeScoreRoutes } from "./routes/lifescore-routes"
import { profileRoutes } from "./routes/profile-routes"

const app = new Hono()

app.use(
  "*",
  cors({
    origin: "*",
    allowHeaders: ["Content-Type", "Authorization", "X-User-Id"],
    allowMethods: ["GET", "POST", "PATCH", "OPTIONS"],
  }),
)

app.get("/", (c) => c.text("LockedIn backend running"))
app.get("/health", (c) => c.json({ status: "ok", service: "lockedin-api" }))

app.route("/v1/chat", chatRoutes)
app.route("/v1/checkins", checkinRoutes)
app.route("/v1/lifescore", lifeScoreRoutes)
app.route("/v1/profile", profileRoutes)

export default app
