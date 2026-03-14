import { AuthService } from "./auth-service"
import { CoachService } from "./coach-service"
import { MemoryService } from "./memory-service"

export const services = {
  auth: new AuthService(),
  memory: new MemoryService(),
  coach: new CoachService(),
}
