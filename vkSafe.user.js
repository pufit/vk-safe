// ==UserScript==
// @name vkSafe
// @description Защита сообщений в ВК
// @author Artem B.
// @license MIT
// @version 1.0
// @include https://vk.com/im*
// @include https://*.vk.com/im*
// @require https://ajax.googleapis.com/ajax/libs/jquery/1.12.4/jquery.min.js
// @require https://raw.githubusercontent.com/bitwiseshiftleft/sjcl/master/sjcl.js
// @require https://cdnjs.cloudflare.com/ajax/libs/seedrandom/2.3.10/seedrandom.min.js
// @require https://raw.githubusercontent.com/pufit/vk-safe/master/my-random.js
// @require http://www-cs-students.stanford.edu/~tjw/jsbn/jsbn.js
// @require http://www-cs-students.stanford.edu/~tjw/jsbn/jsbn2.js
// @require http://www-cs-students.stanford.edu/~tjw/jsbn/rsa.js
// @require http://www-cs-students.stanford.edu/~tjw/jsbn/rsa2.js
// ==/UserScript==

// Generated by CoffeeScript 1.12.7
(function() {
  var accept_invite, decrypt, encrypt, generate_key, get_id, get_invite_text, history, history_on_update, invite_msg, parse_url, processed, publ, rsa, safe_field, safe_send, text_field,
    indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  rsa = new RSAKey();

  publ = new RSAKey();

  window.sjcl = sjcl;

  invite_msg = "Данный пользователь предложил Вам шифровать\n вашу переписку с помощью расширения vkSafe";

  String.prototype.trim = function() {
    return String(this).replace(/^\s+|\s+$/g, '');
  };

  generate_key = function(password) {
    Math.seedrandom(password);
    rsa.generate(1024, '10001');
    Math.seedrandom((new Date()).toString());
    return localStorage.setItem('vkSafeEXT-private', JSON.stringify([rsa.n.toString(16), rsa.d.toString(16), rsa.e.toString(16)]));
  };

  encrypt = function(text) {
    var enc_key, key;
    key = JSON.stringify(sjcl.random.randomWords(3));
    enc_key = publ.encrypt(key);
    if (enc_key) {
      return "|MESSAGE|\n " + (linebrk(enc_key, 32)) + "\n |KEY FOR SENDER|\n " + (linebrk(rsa.encrypt(key), 32)) + "\n |MESSAGE BODY|\n " + (linebrk(sjcl.encrypt(key, text), 32)) + "\n |END MESSAGE|";
    }
  };

  decrypt = function(text) {
    var enc_key, enc_msg, key, line, raw;
    raw = (function() {
      var i, len, ref, results;
      ref = text.split('|');
      results = [];
      for (i = 0, len = ref.length; i < len; i++) {
        line = ref[i];
        results.push(line.trim());
      }
      return results;
    })();
    enc_key = raw.slice(raw.indexOf('MESSAGE') + 1, raw.indexOf('KEY FOR SENDER'))[0].replace(/\n/g, '');
    enc_msg = raw.slice(raw.indexOf('MESSAGE BODY') + 1, raw.indexOf('END MESSAGE'))[0].replace(/\n/g, '');
    key = rsa.decrypt(enc_key);
    return sjcl.decrypt(key, enc_msg);
  };

  get_invite_text = function() {
    return "|INVITE|\n " + invite_msg + "\n |INVITE BODY|\n " + (linebrk(rsa.n.toString(16), 32)) + "\n |END INVITE|";
  };

  accept_invite = function(invite) {
    var key, line, raw;
    raw = (function() {
      var i, len, ref, results;
      ref = invite.split('|');
      results = [];
      for (i = 0, len = ref.length; i < len; i++) {
        line = ref[i];
        results.push(line.trim());
      }
      return results;
    })();
    key = raw.slice(raw.indexOf('INVITE BODY') + 1, raw.indexOf('END INVITE'))[0].replace(/\n/g, '');
    publ.setPublic(key, rsa.e.toString(16));
    localStorage.setItem('vkSafeEXT-public', JSON.stringify([key, rsa.e.toString(16)]));
    return true;
  };

  parse_url = function(href) {
    var match;
    match = href.match(/^(https?\:)\/\/(([^:\/?#]*)(?:\:([0-9]+))?)(\/[^?#]*)(\?[^#]*|)(#.*|)$/);
    return match && {
      protocol: match[1],
      host: match[2],
      hostname: match[3],
      port: match[4],
      pathname: match[5],
      search: match[6],
      hash: match[7]
    };
  };

  get_id = function() {
    return parse_url(location.href)['search'].match(/sel=[0-9]+/)[0].split('=')[1];
  };

  history_on_update = function(group) {
    var i, is_user, len, message, messages, ref, results;
    is_user = group.target.children[1].children[0].innerText.split(' ')[0] === $('.top_profile_name').html();
    messages = group.target.children[1].children[1].children;
    results = [];
    for (i = 0, len = messages.length; i < len; i++) {
      message = messages[i];
      if (ref = message.dataset['msgid'], indexOf.call(processed, ref) < 0) {
        processed.push(message.dataset['msgid']);
        message = message.textContent.trim();
        results.push(console.log(message));
      } else {
        results.push(void 0);
      }
    }
    return results;
  };

  safe_send = function() {
    if (!safe_field.html()) {
      return;
    }
    text_field.html(safe_field.html());
    $('._im_send').click();
    return setTimeout(function() {
      return text_field.html('');
    }, 100);
  };

  safe_field = $('._im_text');

  text_field = safe_field.clone();

  text_field.css({
    'display': 'none'
  });

  $('._im_text_wrap').append(text_field);

  setTimeout(function() {
    return $('.placeholder').css({
      'display': 'none'
    });
  }, 1000);

  safe_field.removeClass('_im_text');

  safe_field.addClass('vkSafeField');

  safe_field.keydown(function(e) {
    if (e.keyCode === 13) {
      safe_send();
      return false;
    }
  });

  processed = [];

  history = $('._im_peer_history');

  history.bind('DOMSubtreeModified', function(data) {});

  window.text_field = text_field;

  window.safe_field = safe_field;

  window.safe_send = safe_send;

  window.encrypt = encrypt;

  window.decrypt = decrypt;

  window.get_invite_text = get_invite_text;

  window.accept_invite = accept_invite;

  window.parse_url = parse_url;

  window.generate_key = generate_key;

}).call(this);

//# sourceMappingURL=vk_safe.js.map

