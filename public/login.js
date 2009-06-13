$(function() {
  n = $('#name')
  n.focus()
  p = $('#password')
  p2 = $('#password2')
  f = $('#form')
  b = $('#submit')
  b.click(function() {
    if (n.attr('value') == 'login') {
      n.val('')
    }
    if (p.attr('value') == 'hasło') {
      p.val('')
    }
    if (p2.attr('value') == 'znowu hasło') {
      p2.val('')
    }
    f.submit()
  })
  
  var pierwszy_raz = true
  n.focus(function() {
    if (n.attr('value') == 'login') {
      n.val('')
      n.toggleClass('center')
    }
    n.toggleClass('gray')
  })
  n.blur(function() {
    if (pierwszy_raz) {
      pierwszy_raz = false;
      if (n.attr('value') == 'login') {
        n.toggleClass('center')
      }
    } else if (n.attr('value') == '') {
      n.val('login')
      n.toggleClass('center')
    }
    n.toggleClass('gray')
  })
  
  p.focus(function() {
    p.toggleClass('gray')
    if (p.attr('value') == 'hasło') {
      p.val('')
      p.toggleClass('center')
      p.removeAttr('type')
      p.attr('type', 'password')
    }
  })
  p.blur(function() {
    p.toggleClass('gray')
    if (p.attr('value') == '') {
      p.val('hasło')
      p.toggleClass('center')
      p.removeAttr('type')
      p.attr('type', 'text')
    }
  })
  
  p2.focus(function() {
    p2.toggleClass('gray')
    if (p2.attr('value') == 'znowu hasło') {
      p2.val('')
      p2.toggleClass('center')
      p2.removeAttr('type')
      p2.attr('type', 'password')
    }
  })
  p2.blur(function() {
    p2.toggleClass('gray')
    if (p2.attr('value') == '') {
      p2.val('znowu hasło')
      p2.toggleClass('center')
      p2.removeAttr('type')
      p2.attr('type', 'text')
    }
  })
})