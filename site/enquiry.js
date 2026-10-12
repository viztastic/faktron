// The enquiry form (site/contact). It checks the fields, posts them as JSON to the enquiry
// function (window.faktronEnquiry.url, written by deploy/site.sh into enquiry.generated.js), and
// says what happened in the status box. With no script the page still reads whole: the phone
// number and email address work, and the form says it needs a moment.
;(function () {
  'use strict'
  var form = document.querySelector('.enquiry form')
  var status = document.querySelector('.enquiry .status')
  var says = status.querySelector('[data-status]')
  var send = form.querySelector('button[type=submit]')
  var SHAPE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/
  var REQUIRED = ['name', 'email', 'phone', 'service', 'message']
  var WORDS = {
    missing: 'Please fill in the highlighted fields.',
    notAnEmail: 'That email address does not look right.',
    sending: 'Sending…',
    sent: 'Thank you — we’ll respond within 24 hours.',
    unreachable: 'We couldn’t send that just now. Call 1300 84 84 54 or email info@faktron.com.',
  }

  function say(message, ok) {
    says.textContent = message
    status.hidden = !message
    status.querySelector('svg').style.visibility = ok ? 'visible' : 'hidden'
  }

  function field(name) {
    return form.elements[name]
  }

  function mark(name, invalid) {
    field(name).setAttribute('aria-invalid', invalid ? 'true' : 'false')
  }

  function check() {
    var first = null
    REQUIRED.forEach(function (name) {
      var empty = field(name).value.trim() === ''
      var wrong = empty || (name === 'email' && !SHAPE.test(field(name).value.trim()))
      mark(name, wrong)
      if (wrong && !first) first = name
    })
    if (!first) return true
    say(first === 'email' && field('email').value.trim() !== '' ? WORDS.notAnEmail : WORDS.missing, false)
    field(first).focus()
    return false
  }

  REQUIRED.forEach(function (name) {
    field(name).addEventListener('input', function () {
      mark(name, false)
      if (!status.hidden && says.textContent !== WORDS.sent) say('', false)
    })
  })

  form.addEventListener('submit', function (event) {
    event.preventDefault()
    if (!check()) return
    var url = (window.faktronEnquiry || {}).url
    if (!url) return say(WORDS.unreachable, false)
    var body = {}
    ;['name', 'email', 'phone', 'company', 'service', 'message', 'website'].forEach(function (name) {
      body[name] = field(name).value.trim()
    })
    send.disabled = true
    say(WORDS.sending, false)
    fetch(url, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) })
      .then(function (answer) {
        if (answer.status === 200) {
          form.hidden = true
          form.reset()
          say(WORDS.sent, true)
          status.setAttribute('tabindex', '-1')
          status.focus()
        } else if (answer.status === 400) {
          say(WORDS.missing, false)
        } else {
          say(WORDS.unreachable, false)
        }
      })
      .catch(function () {
        say(WORDS.unreachable, false)
      })
      .then(function () {
        send.disabled = false
      })
  })
})()
