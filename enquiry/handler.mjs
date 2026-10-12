// The enquiry function behind faktron.com/contact (ADR-0001). A Lambda with a function URL: the
// page POSTs the form's fields as JSON, this checks them and sends one email to the inbox through
// SES, with the enquirer as the reply-to, so a reply from the inbox goes straight back to them.
//
// It is the only server-side code the site has. It holds no secret: SES is reached through the
// function's own role (infra/enquiry.tf), and where the mail goes is in its environment.
//
// `makeHandler` takes the sender so the tests can hold it; `handler` is what Lambda runs. The SES
// client comes with the Node runtime on Lambda and is loaded only there, on the first request.

const SERVICES = {
  design: 'Design',
  manufacturing: 'Manufacturing',
  installation: 'Installation',
  'design-manufacturing': 'Design and manufacturing',
  'manufacturing-installation': 'Manufacturing and installation',
  'full-service': 'Full service (design, manufacturing and installation)',
  consultation: 'Consultation',
}

const LIMITS = { name: 120, email: 200, phone: 40, company: 120, message: 4000 }
const REQUIRED = ['name', 'email', 'phone', 'service', 'message']
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/

const json = (statusCode, body) => ({
  statusCode,
  headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
  body: JSON.stringify(body),
})

// One line of text, with anything that could end a header stripped out.
const oneLine = (value) => String(value ?? '').replace(/[\r\n\t\0]+/g, ' ').replace(/ {2,}/g, ' ').trim()
// Many lines, with line breaks kept and other control characters stripped.
const lines = (value) => String(value ?? '').replace(/\r\n?/g, '\n').replace(/[^\S\n]+/g, ' ').replace(/[\0-\x08\x0b-\x1f\x7f]/g, '').trim()

function parse(event) {
  const method = event?.requestContext?.http?.method
  if (method !== 'POST') return { refused: json(405, { ok: false, error: 'POST only' }) }
  const raw = event.isBase64Encoded ? Buffer.from(event.body ?? '', 'base64').toString('utf8') : (event.body ?? '')
  if (raw.trim() === '') return { refused: json(400, { ok: false, error: 'no body', missing: REQUIRED }) }
  let body
  try {
    body = JSON.parse(raw)
  } catch {
    return { refused: json(400, { ok: false, error: 'the body is not JSON', missing: REQUIRED }) }
  }
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    return { refused: json(400, { ok: false, error: 'the body is not an object', missing: REQUIRED }) }
  }
  return { body }
}

function check(body) {
  const fields = {
    name: oneLine(body.name),
    email: oneLine(body.email),
    phone: oneLine(body.phone),
    company: oneLine(body.company),
    service: oneLine(body.service),
    message: lines(body.message),
  }
  const missing = REQUIRED.filter((name) => fields[name] === '')
  if (missing.length > 0) return { refused: json(400, { ok: false, error: 'fields are missing', missing }) }
  if (!EMAIL.test(fields.email)) return { refused: json(400, { ok: false, error: 'the email address is not one', missing: ['email'] }) }
  if (!(fields.service in SERVICES)) return { refused: json(400, { ok: false, error: 'not a service we offer', missing: ['service'] }) }
  const tooLong = Object.entries(LIMITS).filter(([name, limit]) => fields[name].length > limit).map(([name]) => name)
  if (tooLong.length > 0) return { refused: json(400, { ok: false, error: 'too long', missing: tooLong }) }
  return { fields }
}

function compose(fields, settings) {
  const service = SERVICES[fields.service]
  const text = [
    `Name: ${fields.name}`,
    `Email: ${fields.email}`,
    `Phone: ${fields.phone}`,
    fields.company ? `Company: ${fields.company}` : null,
    `Service: ${service}`,
    '',
    'Project details:',
    fields.message,
    '',
    '—',
    'Sent from the enquiry form at faktron.com/contact. Reply to this email to answer them.',
  ].filter((line) => line !== null).join('\n')
  return {
    from: settings.from,
    to: [settings.to],
    replyTo: [fields.email],
    subject: `Enquiry from ${fields.name} — ${service}`,
    text,
  }
}

export function makeHandler(settings) {
  return async function handler(event) {
    const parsed = parse(event)
    if (parsed.refused) return parsed.refused
    // The hidden field a person never sees. A bot that filled it is told yes and ignored.
    if (oneLine(parsed.body.website) !== '') return json(200, { ok: true })
    const checked = check(parsed.body)
    if (checked.refused) return checked.refused
    try {
      await settings.send(compose(checked.fields, settings))
    } catch (error) {
      console.error('the enquiry could not be sent', error)
      return json(502, { ok: false })
    }
    return json(200, { ok: true })
  }
}

async function sesSender(region) {
  const { SESv2Client, SendEmailCommand } = await import('@aws-sdk/client-sesv2')
  const ses = new SESv2Client({ region })
  return async (mail) => {
    await ses.send(new SendEmailCommand({
      FromEmailAddress: mail.from,
      Destination: { ToAddresses: mail.to },
      ReplyToAddresses: mail.replyTo,
      Content: {
        Simple: {
          Subject: { Data: mail.subject, Charset: 'UTF-8' },
          Body: { Text: { Data: mail.text, Charset: 'UTF-8' } },
        },
      },
    }))
  }
}

function required(name) {
  const value = process.env[name]
  if (!value) throw new Error(`${name} is not set on the function`)
  return value
}

let live

export async function handler(event) {
  live ??= makeHandler({
    to: required('ENQUIRY_TO'),
    from: required('ENQUIRY_FROM'),
    send: await sesSender(process.env.AWS_REGION || 'ap-southeast-2'),
  })
  return live(event)
}
