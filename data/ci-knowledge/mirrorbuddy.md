# MirrorBuddy CI Knowledge Base

Patterns from PR review analysis (PRs #3-#8). Next.js 16 + Prisma + Azure OpenAI. Mission-critical accessibility platform.

## Type Safety & Data Contracts (12+ comments — most frequent)

- Use exact field names from Prisma schema: `profile.name` NOT `profileName`
- Query sessionMetrics by `conversationId` NOT `sessionId` — check FK names
- Pass `options.model` through to downstream functions, don't drop params
- Empty arrays are NOT valid defaults when API expects populated data
- Case-sensitive stage labels from backend: `PROSPECT` not `prospect`

## Security & Privacy (8+ comments)

- Crisis detection regex: restrict to self-harm (`mi faccio`), exclude threats (`ti faccio`)
- NEVER log cookie values — log `"enabled"/"disabled"` status only
- Gate store sync on 401 — only skip hydration for guest users, not all errors
- ReDoS: validate regex patterns before deploying to production
- Rate limiting required on all public endpoints
- Update Hono to >=4.11.7 (known vulnerabilities below)

## Accessibility WCAG 2.1 AA (6+ comments — mission-critical)

- Every interactive element needs keyboard focus states
- Use semantic HTML: `<button>` not `<div onClick>`, `<nav>` not `<div role="navigation">`
- All images need alt text; decorative images need `alt=""`
- 4.5:1 contrast ratio minimum for text
- 7 DSA neurodiversity profiles must work: dyslexia, ADHD, dyscalculia, etc.
- Test with 200% text resize — no layout breakage allowed

## i18n & Localization (10+ comments)

- ALL user-facing text through message keys — NO hardcoded strings
- 5 languages required: en, it, es, fr, de
- Formal/informal consistency per language (Italian: always formal)
- Error messages must be localized, not English-only
- Pre-commit hook validates: no hardcoded Italian/English in components
- Country-specific legal text in privacy policy (GDPR per country)

## Database & Migrations (4+ comments)

- Schema changes MUST have Prisma migration: `npx prisma migrate dev`
- Add VarChar limits to all string columns (prevent overflow)
- Add indexes on frequently-queried columns (email, userId)
- Run `npx prisma generate` + `npx prisma db push` before commit

## API Contract Mismatches (5+ comments)

- Fetch real data from API endpoints — never return empty arrays as placeholder
- Skip zero-percent buckets in A/B range calculation
- Synthetic profiles: use new API endpoint, not hardcoded empty array
- Verify request/response shapes match Prisma types exactly

## CI Pipeline Notes

- ESLint with 14 custom security/a11y/i18n rules (0 warnings gate)
- TypeScript strict: no `any`, no `@ts-ignore` without justification
- Vitest 80% coverage on business logic, 100% critical paths
- Playwright 229 E2E tests: standard, security, compliance, a11y, voice, admin
- LLM safety tests: jailbreak detector, content filter validation
- Smoke tests are BLOCKING — must pass for production readiness
- axe-core WCAG AA enforcement in CI
