

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
#{ linebrk(sjcl.encrypt(key, text), 32) }\n
|END MESSAGE|"

decrypt = (text) ->
  raw = (line.trim() for line in text.split('|'))
  enc_key = raw.slice(raw.indexOf('MESSAGE') + 1, raw.indexOf('KEY FOR SENDER'))[0].replace(/\s|\n/g, '')
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

history_on_update = (group) ->
  is_user = group.target.children[1].children[0].innerText.split(' ')[0] == $('.top_profile_name').html()
  messages = group.target.children[1].children[1].children
  for message in messages
    if message.dataset['msgid'] not in processed
      processed.push(message.dataset['msgid'])
      message = message.textContent.trim()
      console.log(message)

safe_send = () ->
  if not safe_field.html()
    return
  text_field.html(safe_field.html())
  $('._im_send').click()
  setTimeout( () ->
    text_field.html('')
  , 100)


safe_field = $('._im_text')
text_field = safe_field.clone()
text_field.css({'display': 'none'})
$('._im_text_wrap').append(text_field)

setTimeout( () ->
  $('.placeholder').css({'display': 'none'})
, 1000)

safe_field.removeClass('_im_text')
safe_field.addClass('vkSafeField')

safe_field.keydown( (e) ->
  if e.keyCode == 13
    safe_send()
    return false
)

processed = []
history = $('._im_peer_history')
history.bind('DOMSubtreeModified', (data) ->
  # history_on_update(data)
)


window.text_field = text_field
window.safe_field = safe_field
window.safe_send = safe_send
window.encrypt = encrypt
window.decrypt = decrypt
window.get_invite_text = get_invite_text
window.accept_invite = accept_invite
window.parse_url = parse_url
window.generate_key = generate_key
