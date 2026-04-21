import { AuthService } from "./auth-service"
import { CoachService } from "./coach-service"
import { MaxxService } from "./maxx-service"
import { MemoryService } from "./memory-service"
import { PersistenceMirrorService } from "./persistence-mirror-service"
import { ThreadStateService } from "./thread-state-service"

const memory = new MemoryService()

export const services = {
  auth: new AuthService(),
  persistence: new PersistenceMirrorService(),
  threadState: new ThreadStateService(),
  memory,
  maxx: new MaxxService(memory),
  coach: new CoachService(memory),
}
