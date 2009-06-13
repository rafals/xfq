$(function() {
  m = $('#mianownik')
  d = $('#dopelniacz')
  mf = $('#mianownik-form')
  df = $('#dopelniacz-form')
  
  m.focus(function() {
    m.toggleClass('gray')
    if (m.attr('value') == 'mianownik') {
      m.val('')
      m.toggleClass('center')
    }
  })
  m.blur(function() {
    m.toggleClass('gray')
    if (m.attr('value') == '') {
      m.val('mianownik')
      m.toggleClass('center')
    }
  })
  
  d.focus(function() {
    d.toggleClass('gray')
    if (d.attr('value') == 'dopełniacz') {
      d.val('')
      d.toggleClass('center')
    }
  })
  d.blur(function() {
    d.toggleClass('gray')
    if (d.attr('value') == '') {
      d.val('dopełniacz')
      d.toggleClass('center')
    }
  })
})