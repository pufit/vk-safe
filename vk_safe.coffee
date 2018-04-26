

rsa = new RSAKey()
publ = new RSAKey()

window.sjcl = sjcl

invite_msg = "Данный пользователь предложил Вам шифровать\n
вашу переписку с помощью расширения vkSafe
"

String.prototype.trim = () ->
  return String(this).replace(/^\s+|\s+$/g, '');


generate_key = (password) ->
  Math.seedrandom(password)
  rsa.generate(1024, '10001');
  Math.seedrandom((new Date()).toString())
  localStorage.setItem('vkSafeEXT-private', JSON.stringify([rsa.n.toString(16), rsa.d.toString(16),
    rsa.e.toString(16)]))

encrypt = (text) ->
  key = JSON.stringify(sjcl.random.randomWords(3))
  enc_key = publ.encrypt(key)
  if enc_key
    "|MESSAGE|\n
#{ linebrk(enc_key, 32) }\n
|KEY FOR SENDER|\n
#{ linebrk(rsa.encrypt(key), 32)}\n
|MESSAGE BODY|\n
#{ linebrk(sjcl.encrypt(key, text.trim()), 32) }\n
|END MESSAGE|"

decrypt = (text, self) ->
  raw = (line.trim() for line in text.split('|'))
  if not self
    enc_key = raw.slice(raw.indexOf('MESSAGE') + 1, raw.indexOf('KEY FOR SENDER'))[0].replace(/\s|\n/g, '')
  else
    enc_key = raw.slice(raw.indexOf('KEY FOR SENDER') + 1, raw.indexOf('MESSAGE BODY'))
  enc_key = enc_key[0].replace(/\ /g, '')
  enc_msg = raw.slice(raw.indexOf('MESSAGE BODY') + 1, raw.indexOf('END MESSAGE'))[0].replace(/\s|\n/g, '')
  key = rsa.decrypt(enc_key)
  return sjcl.decrypt(key, enc_msg)

get_invite_text = () ->
  "|INVITE|\n
#{ invite_msg }\n
|INVITE BODY|\n
#{ linebrk(rsa.n.toString(16), 32) }\n
|END INVITE|"

accept_invite = (invite) ->
  raw = (line.trim() for line in invite.split('|'))
  key = raw.slice(raw.indexOf('INVITE BODY') + 1, raw.indexOf('END INVITE'))[0].replace(/\s|\n/g, '')
  publ.setPublic(key, rsa.e.toString(16))
  localStorage.setItem('vkSafeEXT-public', JSON.stringify([key, rsa.e.toString(16)]))
  true

parse_url = (href) ->
  match = href.match(/^(https?\:)\/\/(([^:\/?#]*)(?:\:([0-9]+))?)(\/[^?#]*)(\?[^#]*|)(#.*|)$/);
  return match && {
    protocol: match[1],
    host: match[2],
    hostname: match[3],
    port: match[4],
    pathname: match[5],
    search: match[6],
    hash: match[7]
  }

get_id = () ->
  parse_url(location.href)['search'].match(/sel=[0-9]+/)[0].split('=')[1]

history_on_update = () ->
  messages = $('._im_mess')
  for message in messages
    if message.dataset['msgid'] not in processed
      self = message.parentElement.parentElement.children[0].innerText.trim().split(' ')[0] == $('.top_profile_name').html()
      processed.push(message.dataset['msgid'])
      if message.children[2].innerText
        handler(message.children[2], self)
      else
        handler(message.children[0], self)


handler = (message, self) ->
  if not is_safe
    return
  content = (line.trim() for line in message.innerText.split('|'))
  if content[1] == 'MESSAGE'
    message.innerText = '[Защищено] ' + decrypt(message.innerText, self)
  else if content[1] == 'INVITE'
    message.innerText = '[vkSafe] Заявка на шифрование принята'
    accept_invite(message.textContent)


safe_send = () ->
  if not safe_field.html()
    return
  text_field.html(encrypt(safe_field.html()))
  $('._im_send').click()
  setTimeout( () ->
    text_field.html('')
  , 100)


generate_safe_form = () ->
  safe_field = $('._im_text')
  text_field = safe_field.clone()
  text_field.css({'display': 'none'})
  $('._im_text_wrap').append(text_field)
  safe_field.removeClass('_im_text')
  safe_field.addClass('vkSafeField')
  safe_field.keydown( (e) ->
    $('.placeholder').css({'display': 'none'})
    if e.keyCode == 13
      safe_send()
      return false
  )
  window.text_field = text_field
  window.safe_field = safe_field


on_url_change = () ->
  id = get_id()
  if not id or secure_id not in id
    return



processed = []
is_safe = true

if localStorage.getItem('vkSafeSecureId')
  secure_id = JSON.parse(localStorage.getItem('vkSafeSecureId'))
else
  localStorage.setItem('vkSafeSecureId', '[]')
  secure_id = []

history = $('._im_peer_history')
history.bind('DOMSubtreeModified', () ->
  history_on_update()
)


generate_key('test')
accept_invite(get_invite_text())

generate_safe_form()


window.processed = processed
window.generate_safe_form = generate_safe_form
window.safe_send = safe_send
window.encrypt = encrypt
window.decrypt = decrypt
window.get_invite_text = get_invite_text
window.accept_invite = accept_invite
window.parse_url = parse_url
window.generate_key = generate_key
