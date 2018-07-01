# localStorage
{
  'vkSafeEXT': {
    '<id>': {
      'public_key': '<public_key>'
      'secret_key': '<secret_key>'
    }
  }
}

"""
vkSafe();

var loc = location.href;
setInterval(function(){
    if (location.href !== loc){
        loc = location.href;
        var b = $('.vkSafeButton');
        if (b){
            b.remove()
        }
        vkSafe();
        console.log(loc)
    }
}, 100);
"""


window.sjcl = sjcl

invite_msg = "Данный пользователь предложил Вам шифровать\n
вашу переписку с помощью расширения vkSafe
https://github.com/pufit/vk-safe
"

button_click_text = "Введите пароль для шифрования переписки.
НИКОМУ ЕГО НЕ ГОВОРИТЕ!
"


String.prototype.trim = () ->
  return String(this).replace(/^\s+|\s+$/g, '');


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
  res = parse_url(location.href)['search'].match(/sel=[0-9]+/)
  res[0].split('=')[1] if res


generate_key = () ->
  password = ''
  while not password
    password = prompt(button_click_text, '')
  password += id
  Math.seedrandom(password)
  rsa.generate(1024, '10001');
  Math.seedrandom((new Date()).toString())
  dump_to_storage()


load_from_storage = () =>
  body = JSON.parse(localStorage.getItem('vkSafeEXT'))
  if not body
    return false
  if not body[id]
    return false
  p = body[id]['public']
  s = body[id]['private']
  publ.setPublic(p[0], p[1]) if p
  rsa.setPrivate(s[0], s[1], s[2]) if s
  @is_safe = body[id]['isSafe']
  @waiting_for_secure = body[id]['waitingForSecure']
  return true if s or p


dump_to_storage = () ->
  body = if localStorage.getItem('vkSafeEXT') then JSON.parse(localStorage.getItem('vkSafeEXT')) else {}
  body[id] = {
    isSafe: false
    waitingForSecure: false
  } if not body[id]
  body[id]['public'] = [publ.n.toString(16), publ.e.toString(16)] if publ.n
  body[id]['private'] = [rsa.n.toString(16), rsa.e.toString(16), rsa.d.toString(16)] if rsa.n
  body[id]['isSafe'] = is_safe
  body[id]['waitingForSecure'] = waiting_for_secure
  localStorage.setItem('vkSafeEXT', JSON.stringify(body))

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


accept_invite = (invite) =>
  raw = (line.trim() for line in invite.split('|'))
  key = raw.slice(raw.indexOf('INVITE BODY') + 1, raw.indexOf('END INVITE'))[0].replace(/\s|\n/g, '')
  publ.setPublic(key, rsa.e.toString(16))
  @is_safe = true
  b = $('.vkSafeButton')
  if b
    b.remove()
  dump_to_storage()
  true


history_on_update = () ->
  if loc != location.href
    return
  messages = $('._im_mess')
  for message in messages
    if message.dataset['msgid'] not in processed
      self = message.parentElement.parentElement.children[0].innerText.trim().split(' ')[0] == $('.top_profile_name').html()
      processed.push(message.dataset['msgid'])
      if message.children[2].innerText
        handler(message.children[2], self)
      else
        handler(message.children[0], self)


handler = (message, self) =>
  content = (line.trim() for line in message.innerText.split('|'))

  if content[1] == 'INVITE'
    if not @is_safe and not self
      if not @waiting_for_secure and confirm('Пользователь отправил заявку на шифрование переписки. Принять её?')
        generate_key()
        generate_safe_form()
        send_invite()
      accept_invite(message.textContent)

    if self
        message.innerText = '[vkSafe] Заявка на шифрование отправлена.'
        return
    message.innerText = '[vkSafe] Заявка на шифрование'
    return

  if content[1] == 'MESSAGE'
    try
      message.innerText = decrypt(message.innerText, self)
      message.style.backgroundColor = 'rgba(0, 255, 0, 0.2)'
    catch
      message.style.backgroundColor = 'rgba(255, 0, 0, 0.2)'
      message.innerText = '[vkSafe] Не удалось дешифровать сообщение'



safe_send = () ->
  if not safe_field.html()
    return
  text_field.html(encrypt(safe_field.html()))
  $('._im_send').click()
  setTimeout( () ->
    text_field.html('')
  , 100)


send = () ->
  if not safe_field.html()
    return
  text_field.html(safe_field.html())
  $('._im_send').click()
  setTimeout( () ->
    text_field.html('')
  , 100)


send_invite = () =>
  @waiting_for_secure = true
  dump_to_storage()
  text_field.html(get_invite_text())
  $('._im_send').click()
  setTimeout( () ->
    text_field.html('')
  , 100)


generate_safe_form = () =>
  if $('.vkSafeField').length
    return

  @safe_field = $('._im_text')
  @text_field = @safe_field.clone()
  @text_field.css({'display': 'none'})
  $('._im_text_wrap').append(@text_field)

  setTimeout( () ->
    $('.placeholder').css({'display': 'none'})
  , 3000)

  @safe_field.removeClass('_im_text')
  @safe_field.addClass('vkSafeField')
  @safe_field.keydown( (e) ->
    if e.keyCode == 13
      if is_safe
        safe_send()
      else
        send()
      return false
  )



add_button = () ->
  button = document.createElement('button')
  button.innerHTML = 'Шифровать переписку'
  button.style.position = 'absolute'
  button.style.left = 0
  button.style.bottom = '40px'
  button.className = 'vkSafeButton'
  button.onclick = () ->
    generate_key()
    generate_safe_form()
    send_invite()
  $('.side_bar').append(button)


init = () =>
  @rsa = new RSAKey()
  @publ = new RSAKey()
  
  @processed = []
  @is_safe = false
  @ext_started = true
  @waiting_for_secure = false

  @id = get_id()

  if not id
    return

  load_from_storage()

  if is_safe
    generate_safe_form()

  @vk_history = $('._im_peer_history')
  @vk_history.bind('DOMSubtreeModified',  history_on_update)


  if not is_safe and not waiting_for_secure
    add_button()


  window.processed = processed
  window.generate_safe_form = generate_safe_form
  window.safe_send = safe_send
  window.encrypt = encrypt
  window.decrypt = decrypt
  window.get_invite_text = get_invite_text
  window.accept_invite = accept_invite
  window.parse_url = parse_url
  window.generate_key = generate_key
  window.load_from_storage = load_from_storage
  window.rsa = rsa
  window.publ = publ


window.init = init
window.history_on_update = history_on_update

init()


loc = location.href

setInterval( () ->
  if location.href != loc
    loc = location.href
    b = $('.vkSafeButton')
    if window.vk_history
      vk_history.unbind('DOMSubtreeModified', history_on_update)
    if b
      b.remove()
    init()
    if is_safe
      history_on_update()
    console.log(loc)
, 100)