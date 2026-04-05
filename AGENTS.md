# Project Rules

## Stack
- iOS frontend: Swift + SwiftUI
- Backend: Hono + Bun
- AI: Vercel AI SDK

## General Rules
- Prefer small, clean, readable code.
- Do not break existing functionality.
- Reuse existing files/components before creating new ones.

## Swift / SwiftUI Rules
- Use modern SwiftUI APIs.
- Keep views small and composable.
- Move business logic out of views.
- Use correct state wrappers (@State, @StateObject, @ObservedObject).
- Avoid force unwraps.
- Prefer async/await.
- Add previews when possible.
- Ensure accessibility (labels, dynamic type).

## Backend (Hono + Bun)
- Keep route handlers thin.
- Move logic to services.
- Validate all inputs.
- Return consistent JSON responses.
- Handle errors properly.

## API Contract
- Keep Swift models and backend responses in sync.
- Do not change response shape without updating frontend.

## Done Criteria
- Code compiles
- No obvious bugs
- Matches existing patterns