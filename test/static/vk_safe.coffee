rsa = new RSAKey()
publ = new RSAKey()

Math.seedrandom('password')
rsa.generate(2048, '10001');
Math.seedrandom((new Date()).toString())

window.sjcl = sjcl
window.cipher_accepted = false

invite_msg = "Данный пользователь предложил Вам шифровать\n
вашу переписку с помощью расширения vkSafe
"

encrypt = (text) ->
  key = JSON.stringify(sjcl.random.randomWords(3))
  enc_key = publ.encrypt(key)
  if enc_key
    "------ MESSAGE ------\n#{ linebrk(enc_key, 32) }\n------ MESSAGE BODY ------\n#{ linebrk(sjcl.encrypt(key, text), 32) }\n------ END MESSAGE ------"

decrypt = (text) ->
  raw = text.split('\n')
  for line, i in raw
    if line == '------ MESSAGE BODY ------'
      enc_key = ''
      for key_line in raw.slice(1, i)
        enc_key += key_line
      enc_msg = ''
      for msg_line in raw.slice(i + 1, -1)
        enc_msg += msg_line
  key = rsa.decrypt(enc_key)
  return sjcl.decrypt(key, enc_msg)

get_invite_text = () ->
  "------ INVITE ------\n#{ invite_msg }\n------ INVITE BODY ------\n#{ linebrk(rsa.n.toString(16), 32) }\n------ END INVITE ------"

accept_invite = (invite) ->
  raw = invite.split('\n')
  for line, i in raw
    if line == '------ INVITE BODY ------'
      key = ''
      for key_line in raw.slice(i + 1, -1)
        key += key_line
  publ.setPublic(key, rsa.e.toString(16))
  window.cipher_accepted = true

window.encrypt = encrypt
window.decrypt = decrypt
window.get_invite_text = get_invite_text
window.accept_invite = accept_invite