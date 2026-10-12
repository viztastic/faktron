import { describe, expect, it } from 'vitest'

import { makeHandler } from './handler.mjs'

/**
 * The enquiry function behind faktron.com/contact (ADR-0001): a POST of the form's fields, checked,
 * becomes one email to the inbox, with the enquirer as the reply-to. Everything else is refused
 * with a status the page knows what to do with.
 */
const SETTINGS = { to: 'info@faktron.com', from: 'enquiry@faktron.com', origin: 'https://faktron.com' }

function post(body, overrides = {}) {
  return {
    requestContext: { http: { method: 'POST' }, ...overrides.requestContext },
    headers: { 'content-type': 'application/json', origin: 'https://faktron.com', ...overrides.headers },
    body: typeof body === 'string' ? body : JSON.stringify(body),
    isBase64Encoded: false,
    ...overrides.top,
  }
}

const complete = {
  name: 'Dana Reyes',
  email: 'dana@example.com',
  phone: '0400 000 000',
  company: 'Reyes Fabrication',
  service: 'full-service',
  message: 'A mezzanine floor for our warehouse, about 200 square metres, by March.',
  website: '',
}

function setUp() {
  const sent = []
  const handler = makeHandler({ ...SETTINGS, send: async (mail) => { sent.push(mail) } })
  return { handler, sent }
}

describe('the enquiry function', () => {
  it('refuses an empty request without sending anything', async () => {
    const { handler, sent } = setUp()
    const answer = await handler(post(''))
    expect(answer.statusCode).toBe(400)
    expect(sent).toEqual([])
  })

  it('refuses anything but a POST', async () => {
    const { handler, sent } = setUp()
    const answer = await handler(post(complete, { requestContext: { http: { method: 'GET' } } }))
    expect(answer.statusCode).toBe(405)
    expect(sent).toEqual([])
  })

  it('refuses a body that is not JSON', async () => {
    const { handler, sent } = setUp()
    const answer = await handler(post('name=Dana&email=dana@example.com'))
    expect(answer.statusCode).toBe(400)
    expect(sent).toEqual([])
  })

  it.each(['name', 'email', 'phone', 'service', 'message'])('refuses an enquiry with no %s', async (field) => {
    const { handler, sent } = setUp()
    const answer = await handler(post({ ...complete, [field]: '   ' }))
    expect(answer.statusCode).toBe(400)
    expect(JSON.parse(answer.body).missing).toEqual([field])
    expect(sent).toEqual([])
  })

  it('refuses an email address that is not one', async () => {
    const { handler, sent } = setUp()
    const answer = await handler(post({ ...complete, email: 'dana at example' }))
    expect(answer.statusCode).toBe(400)
    expect(sent).toEqual([])
  })

  it('refuses a service the form does not offer', async () => {
    const { handler, sent } = setUp()
    const answer = await handler(post({ ...complete, service: 'demolition' }))
    expect(answer.statusCode).toBe(400)
    expect(sent).toEqual([])
  })

  it('refuses a message longer than the form allows', async () => {
    const { handler, sent } = setUp()
    const answer = await handler(post({ ...complete, message: 'x'.repeat(4001) }))
    expect(answer.statusCode).toBe(400)
    expect(sent).toEqual([])
  })

  it('says yes to a bot that filled the hidden field, and sends nothing', async () => {
    const { handler, sent } = setUp()
    const answer = await handler(post({ ...complete, website: 'https://spam.example' }))
    expect(answer.statusCode).toBe(200)
    expect(sent).toEqual([])
  })

  it('sends a complete enquiry to the inbox as one email the inbox can reply to', async () => {
    const { handler, sent } = setUp()
    const answer = await handler(post(complete))
    expect(answer.statusCode).toBe(200)
    expect(JSON.parse(answer.body)).toEqual({ ok: true })
    expect(sent).toHaveLength(1)
    const mail = sent[0]
    expect(mail.to).toEqual(['info@faktron.com'])
    expect(mail.from).toBe('enquiry@faktron.com')
    expect(mail.replyTo).toEqual(['dana@example.com'])
    expect(mail.subject).toBe('Enquiry from Dana Reyes — Full service (design, manufacturing and installation)')
    expect(mail.text).toContain('Name: Dana Reyes')
    expect(mail.text).toContain('Email: dana@example.com')
    expect(mail.text).toContain('Phone: 0400 000 000')
    expect(mail.text).toContain('Company: Reyes Fabrication')
    expect(mail.text).toContain('Service: Full service (design, manufacturing and installation)')
    expect(mail.text).toContain('A mezzanine floor for our warehouse')
  })

  it('leaves the company line out when none was given', async () => {
    const { handler, sent } = setUp()
    await handler(post({ ...complete, company: '' }))
    expect(sent[0].text).not.toContain('Company:')
  })

  it('keeps a line break in the message and strips control characters that could forge headers', async () => {
    const { handler, sent } = setUp()
    await handler(post({ ...complete, name: 'Dana\r\nBcc: x@y', message: 'Line one\nLine two' }))
    expect(sent[0].subject).toBe('Enquiry from Dana Bcc: x@y — Full service (design, manufacturing and installation)')
    expect(sent[0].text).toContain('Line one\nLine two')
  })

  it('reads a body the function URL sent base64-encoded', async () => {
    const { handler, sent } = setUp()
    const encoded = Buffer.from(JSON.stringify(complete)).toString('base64')
    const answer = await handler(post(encoded, { top: { isBase64Encoded: true } }))
    expect(answer.statusCode).toBe(200)
    expect(sent).toHaveLength(1)
  })

  it('answers 502 and says so when the email cannot be sent', async () => {
    const handler = makeHandler({ ...SETTINGS, send: async () => { throw new Error('SES is down') } })
    const answer = await handler(post(complete))
    expect(answer.statusCode).toBe(502)
    expect(JSON.parse(answer.body)).toEqual({ ok: false })
  })

  it('answers with JSON every time', async () => {
    const { handler } = setUp()
    for (const answer of [await handler(post('')), await handler(post(complete))]) {
      expect(answer.headers['content-type']).toBe('application/json')
    }
  })
})
