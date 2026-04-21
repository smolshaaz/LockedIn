import app from "./index"

const port = Number(process.env.PORT ?? 3000)

if (import.meta.main) {
  console.log(`[lockedin-api] listening on 0.0.0.0:${port}`)
}

export default {
  port,
  fetch: app.fetch,
}
