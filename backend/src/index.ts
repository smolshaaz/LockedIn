import { Hono } from "hono"
import { cors } from "hono/cors"
import { automationRoutes } from "./routes/automation-routes"
import { chatRoutes } from "./routes/chat-routes"
import { checkinRoutes } from "./routes/checkin-routes"
import { lifeScoreRoutes } from "./routes/lifescore-routes"
import { maxxRoutes } from "./routes/maxx-routes"
import { omnichannelRoutes } from "./routes/omnichannel-routes"
import { profileRoutes } from "./routes/profile-routes"
import { taskRoutes } from "./routes/tasks-routes"
import { testingRoutes } from "./routes/testing-routes"

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
app.route("/v1/maxx", maxxRoutes)
app.route("/v1/profile", profileRoutes)
app.route("/v1/tasks", taskRoutes)
app.route("/v1/omnichannel", omnichannelRoutes)
app.route("/v1/automation", automationRoutes)
app.route("/v1/testing", testingRoutes)

export default app
