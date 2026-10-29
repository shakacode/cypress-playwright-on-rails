import { test, expect, request } from '@playwright/test'
import { app, appCommands, appEval, appResetState } from '../support/on-rails'

// Runs against a server started with CYPRESS_ON_RAILS_TOKEN, and BASE_URL set the way
// `rake playwright:run` sets it, see specs_e2e/rails_8/test_playwright_typescript.sh.
test.describe('generated TypeScript helpers', () => {
  test('unwrap the command results', async () => {
    expect(await appEval<number>('20 + 22')).toBe(42)
    expect(await appCommands<number>([{ name: 'eval', options: '1 + 1' }, { name: 'eval', options: '2 * 3' }])).toEqual([2, 6])

    await app('clean')
    const post = await app<{ id: number; title: string }>('eval', 'Post.create!(title: "typed").as_json')
    expect(typeof post.id).toBe('number')
    expect(post.title).toBe('typed')
  })

  test('send the token the server requires', async ({ baseURL }) => {
    const token = process.env.CYPRESS_ON_RAILS_TOKEN
    expect(token, 'run this spec with CYPRESS_ON_RAILS_TOKEN set').toBeTruthy()

    const anonymous = await request.newContext({ baseURL })
    const rejected = await anonymous.post('/__e2e__/command', { data: { name: 'eval', options: '1' } })
    expect(rejected.status()).toBe(403)
    await anonymous.dispose()

    expect(await appEval<number>('1')).toBe(1)
    expect(await appResetState()).toBeDefined()
  })

  test('forward the per-call request timeout', async () => {
    await expect(app('sleep', { seconds: 3 }, { timeout: 1_000 })).rejects.toThrow(/Timeout 1000ms exceeded/)
  })

  test('let a command outlast the default 30 s request timeout under a raised test timeout', async () => {
    test.setTimeout(90_000)
    expect(await app<string>('sleep', { seconds: 35 }, { timeout: 60_000 })).toBe('slept 35.0')
  })

  test('report the status and body of a failing command', async () => {
    await expect(app('no_such_command')).rejects.toThrow(/app command answered 404: .*could not find command file/)
  })
})
