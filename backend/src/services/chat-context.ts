import type { ChatRequest } from "../schemas/contracts"
import type { MaxxDomain } from "../types/domain"

export type UrgencyLevel = "low" | "normal" | "high"
export type DomainUrgencyMap = Partial<Record<MaxxDomain, UrgencyLevel>>

const DOMAIN_ALIASES: Record<MaxxDomain, string[]> = {
  gym: ["gym", "gymmaxx", "fitness", "workout", "training"],
  face: ["face", "facemaxx", "looks", "skin", "grooming"],
  money: ["money", "moneymaxx", "finance", "income", "career"],
  mind: ["mind", "mindmaxx", "focus", "mental", "mindset"],
  social: ["social", "socialmaxx", "network", "friends", "relationship"],
}

const urgencyLevels = new Set<UrgencyLevel>(["low", "normal", "high"])

const domainAliasToDomain = new Map<string, MaxxDomain>()
for (const [domain, aliases] of Object.entries(DOMAIN_ALIASES) as Array<
  [MaxxDomain, string[]]
>) {
  domainAliasToDomain.set(domain, domain)
  for (const alias of aliases) {
    domainAliasToDomain.set(normalizeDomainToken(alias), domain)
  }
}

function normalizeDomainToken(value: string): string {
  return value.trim().toLowerCase().replace(/[^a-z0-9]/g, "")
}

function domainFromToken(value: string): MaxxDomain | undefined {
  return domainAliasToDomain.get(normalizeDomainToken(value))
}

function toUniqueDomains(domains: MaxxDomain[]): MaxxDomain[] {
  const seen = new Set<MaxxDomain>()
  const ordered: MaxxDomain[] = []
  for (const domain of domains) {
    if (seen.has(domain)) continue
    seen.add(domain)
    ordered.push(domain)
  }
  return ordered
}

function copyUrgencyMap(
  value: ChatRequest["context"]["urgencyByDomain"] | undefined,
): DomainUrgencyMap {
  if (!value) return {}
  const out: DomainUrgencyMap = {}
  for (const domain of Object.keys(DOMAIN_ALIASES) as MaxxDomain[]) {
    const candidate = value[domain]
    if (candidate && urgencyLevels.has(candidate)) {
      out[domain] = candidate
    }
  }
  return out
}

export function extractMentionedDomains(message: string): MaxxDomain[] {
  const domains: MaxxDomain[] = []
  const mentionRegex = /@([a-zA-Z][a-zA-Z0-9_-]*)/g

  let match: RegExpExecArray | null
  while ((match = mentionRegex.exec(message)) !== null) {
    const raw = match[1] ?? ""
    const domain = domainFromToken(raw)
    if (domain) {
      domains.push(domain)
    }
  }

  return toUniqueDomains(domains)
}

export function extractUrgencyByDomain(message: string): DomainUrgencyMap {
  const urgencyByDomain: DomainUrgencyMap = {}

  const inlineRegex = /@([a-zA-Z][a-zA-Z0-9_-]*)\s*(?::|\/|-|\()\s*(low|normal|high)\)?/gi
  let match: RegExpExecArray | null
  while ((match = inlineRegex.exec(message)) !== null) {
    const domain = domainFromToken(match[1] ?? "")
    const urgency = (match[2] ?? "").toLowerCase() as UrgencyLevel
    if (domain && urgencyLevels.has(urgency)) {
      urgencyByDomain[domain] = urgency
    }
  }

  const trailingRegex = /@([a-zA-Z][a-zA-Z0-9_-]*)\s+(low|normal|high)\b/gi
  while ((match = trailingRegex.exec(message)) !== null) {
    const domain = domainFromToken(match[1] ?? "")
    const urgency = (match[2] ?? "").toLowerCase() as UrgencyLevel
    if (domain && urgencyLevels.has(urgency)) {
      urgencyByDomain[domain] = urgency
    }
  }

  return urgencyByDomain
}

export function domainsForRequest(request: ChatRequest): MaxxDomain[] {
  const contextDomains = request.context.domains ?? []
  const merged = [...contextDomains]

  if (request.context.domain) {
    merged.unshift(request.context.domain)
  }

  return toUniqueDomains(merged)
}

export function primaryDomainForRequest(request: ChatRequest): MaxxDomain | undefined {
  const domains = domainsForRequest(request)
  return domains[0]
}

export function urgencyForDomain(
  request: ChatRequest,
  domain: MaxxDomain,
): UrgencyLevel {
  return request.context.urgencyByDomain?.[domain] ?? request.context.urgency
}

export function normalizeChatRequest(request: ChatRequest): ChatRequest {
  const mentionedDomains = extractMentionedDomains(request.message)
  const contextDomains = request.context.domains ?? []
  const mergedDomains = toUniqueDomains([
    ...(request.context.domain ? [request.context.domain] : []),
    ...contextDomains,
    ...mentionedDomains,
  ])

  const inferredUrgency = extractUrgencyByDomain(request.message)
  const explicitUrgency = copyUrgencyMap(request.context.urgencyByDomain)
  const urgencyByDomain: DomainUrgencyMap = {
    ...inferredUrgency,
    ...explicitUrgency,
  }

  return {
    ...request,
    context: {
      ...request.context,
      domain: request.context.domain ?? mergedDomains[0],
      domains: mergedDomains.length > 0 ? mergedDomains : undefined,
      urgencyByDomain:
        Object.keys(urgencyByDomain).length > 0 ? urgencyByDomain : undefined,
    },
  }
}
