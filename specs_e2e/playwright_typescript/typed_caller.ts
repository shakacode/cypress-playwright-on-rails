// Type-level checks of the generated helpers, compiled by `tsc` and never run.
import { app, appCommands, appEval, appScenario } from './playwright/support/on-rails'

type Equal<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false
const assertType = <T extends true>(): void => {}

export async function typedCaller(): Promise<void> {
  const user = await app<{ id: number }>('create_user', { email: 'buyer@example.test' })
  assertType<Equal<typeof user, { id: number }>>()
  const id: number = user.id
  // @ts-expect-error The result keeps its declared type: this fails to compile only while it is not `any`.
  const wrongId: string = user.id
  // @ts-expect-error The declared type has no `email`.
  void user.email

  const untyped = await app('clean')
  assertType<Equal<typeof untyped, unknown>>()
  // @ts-expect-error Without a type argument the result is `unknown`, not `any`.
  void untyped.id

  const results = await appCommands<number>([{ name: 'eval', options: '1 + 1' }])
  assertType<Equal<typeof results, number[]>>()
  assertType<Equal<Awaited<ReturnType<typeof appEval<string>>>, string>>()
  assertType<Equal<Awaited<ReturnType<typeof appScenario>>, unknown>>()

  await app('wait_for_jobs', {}, { timeout: 120_000 })
  // @ts-expect-error The request options only take a numeric timeout.
  await app('wait_for_jobs', {}, { timeout: '2m' })

  void id
  void wrongId
}
