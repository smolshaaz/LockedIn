export class AuthService {
  async verifyToken(authorizationHeader?: string): Promise<string | null> {
    if (!authorizationHeader?.startsWith("Bearer ")) {
      return null
    }

    const token = authorizationHeader.replace("Bearer ", "").trim()
    if (token.length < 8) {
      return null
    }

    return `supabase:${token.slice(-8)}`
  }
}
