#                                                                                                                        
#                                             _|      _|  _|_|_|_|    _|_|                                               
#                                               _|  _|    _|        _|    _|                                             
#                                                 _|      _|_|_|    _|  _|_|                                             
#                                               _|  _|    _|        _|    _|                                             
#                                             _|      _|  _|          _|_|  _|                                           
#                                                                                                                        
#                                                  Powered on Jedi Spot                                                  
#                                                                                                                        
#########################################################################################################################
## REQUIRES
#########################################################################################################################
require 'rubygems'
require 'sinatra'
require 'haml'
require 'datamapper'

#########################################################################################################################
## CONFIG
#########################################################################################################################
use Rack::Session::Cookie, :secret => 'A1 sauce 1s so good you should use 1t on a11 yr st34ksssss'
set :cookies, true
set :environment, :production
use_in_file_templates!

#########################################################################################################################
## MODELS
#########################################################################################################################
DataMapper.setup(:default, "sqlite3:///#{Dir.pwd}/database.db")

#########################################################################################################################
## MODULES
module Rateable
  def rate(s)
    self.scores_sum += s
    self.scores_num += 1
    self.scores_mean = ((self.scores_sum.to_f / self.scores_num) * 50 + 50).to_i
  end
  
  def rate!(s)
    rate(s)
    save or log_errors
  end
end

module Logable
  def log_errors
    puts self.inspect.to_s + ' - e - ' + self.errors.map {|e| e.join(',')}.join(';')
  end
end
#########################################################################################################################
## USER
class User
  include DataMapper::Resource
  include Rateable
  include Logable
  property :id, Serial, :protected => true, :key => true
  property :name, String, :unique => true, :length => (1..40), :nullable => false, :messages => {
                               :presence => "Musisz podać login",
                               :is_unique => "Ten login jest już zajęty :F",
                               :length => "Login musi mieć od 1 do 40 znaków"
                             }
  property :hashed_password, String
  property :salt, String, :protected => true, :nullable => false
  property :views, Integer, :default => 0
  property :created_at, DateTime
  property :last_visit_at, DateTime
  property :scores_sum,   Integer,  :default => 0
  property :scores_num,   Integer,  :default => 0
  property :scores_mean,  Integer,  :default => 50
  has n, :mianowniki, :class_name => 'Word', :type => 'Mianownik'
  has n, :dopelniacze, :class_name => 'Word', :type => 'Dopelniacz'
  has n, :words, :order => [:created_at.desc]
  has n, :rates
  has n, :mocne, :class_name => 'Rate', :score.gt => 0, :order => [:created_at.desc]
  has n, :slabe, :class_name => 'Rate', :score.lt => 0, :order => [:created_at.desc]
  
  attr_accessor :password, :password_confirmation
  validates_present :password, :if => Proc.new {|u| u.new_record?}, :message => 'Musisz podać hasło'
  validates_present :password_confirmation, :if => Proc.new {|u| u.new_record?}, :message => 'Musisz powtórzyć hasło'
  validates_is_confirmed :password, :if => Proc.new {|u| u.new_record?}, :message => 'Hasło w obu polach musi być jednakowe'
  
  def self.authenticate(name, pass)
    u = first(:name => name)
    return nil if u.nil?
    return u if User.encrypt(pass, u.salt) == u.hashed_password
    nil
  end

  def password=(pass)
    @password = pass
    self.salt = User.random_string(10) if !self.salt
    self.hashed_password = User.encrypt(@password, self.salt)
  end

  protected
  def self.encrypt(pass, salt)
    Digest::SHA1.hexdigest(pass+salt)
  end

  def self.random_string(len)
    #generate a random password consisting of strings and digits
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    newpass = ""
    1.upto(len) { |i| newpass << chars[rand(chars.size-1)] }
    return newpass
  end
end

#########################################################################################################################
## PAIR
class Pair
  include DataMapper::Resource
  include Rateable
  include Logable
  property :id,           Serial,   :key => true
  property :views,        Integer,  :default => 1
  property :created_at,   DateTime
  property :scores_sum,   Integer,  :default => 0
  property :scores_num,   Integer,  :default => 0
  property :scores_mean,  Integer,  :default => 50
  property :mianownik_id, Integer
  property :dopelniacz_id,Integer
  has n, :rates
  has n, :mocne, :class_name => 'Rate', :score.gt => 0, :order => [:created_at.desc]
  has n, :slabe, :class_name => 'Rate', :score.lt => 0
  belongs_to :mianownik, :class_name => 'Word', :child_key => [:mianownik_id]
  belongs_to :dopelniacz, :class_name => 'Word', :child_key => [:dopelniacz_id]
  
  def to_s
    mianownik.name.to_s + ' ' + dopelniacz.name.to_s
  end
end

#########################################################################################################################
## Rates
class Rate
  include DataMapper::Resource
  include Logable
  property :id,           Serial,   :key => true
  property :score,        Integer,  :nullable => false
  belongs_to :user
  belongs_to :pair
  property :created_at,   DateTime
end

#########################################################################################################################
## WORDS
class Word
  include DataMapper::Resource
  include Rateable
  include Logable
  property :id,           Serial,   :key => true
  property :name,         String,   :unique => true, :nullable => false
  property :views,        Integer,  :default => 0
  property :created_at,   DateTime
  property :scores_sum,   Integer,  :default => 0
  property :scores_num,   Integer,  :default => 0
  property :scores_mean,  Integer,  :default => 50
  property :type,         Discriminator
  belongs_to :user
  def to_s; name; end
end
class Mianownik < Word
  has n, :pairs, :child_key => [:mianownik_id], :order => [:scores_mean.desc]
end
class Dopelniacz < Word
  has n, :pairs, :child_key => [:dopelniacz_id]
end

DataMapper.auto_upgrade!

#########################################################################################################################
## LOGIKA
#########################################################################################################################
helpers do
  def rand_word(model)
    if result = repository(:default).adapter.query('SELECT id FROM words WHERE type = ? AND (scores_mean - 50) * scores_num > -250 ORDER BY RANDOM() LIMIT 1', model.to_s)
      model.get(result[0])
    else
      nil
    end
  end
  def rand_mianownik; rand_word(Mianownik); end
  def rand_dopelniacz; rand_word(Dopelniacz); end
  
  def pair_for(m, d)
    m.views +=1; m.save or m.log_errors
    d.views +=1; d.save or d.log_errors
    if p = Pair.first(:mianownik_id => m.id, :dopelniacz_id => d.id)
      p.views += 1; p.save or p.log_errors
    else
      p = Pair.new(:mianownik_id => m.id, :dopelniacz_id => d.id); p.save
    end
    p
  end
  
  def rate_pair(pair, score)
    pair.rate!(score)
    pair.mianownik.rate!(score)
    pair.mianownik.user.rate!(score)
    pair.dopelniacz.rate!(score)
    pair.dopelniacz.user.rate!(score)
    if current_user
      if r = Rate.first(:user_id => current_user.id, :pair_id => pair.id)
        r.score += score
      else
        r = Rate.new(:user_id => current_user.id, :pair_id => pair.id, :score => score)
      end
        r.save or r.log_errors
    end
  end
  
  def rand_pair
    if m = rand_mianownik and d = rand_dopelniacz
      pair = pair_for(m, d)
      (pair.scores_mean - 50) * pair.scores_num < -100 ? rand_pair : pair
    else
      nil
    end
  end
end
#########################################################################################################################
## CONTROLLERS
#########################################################################################################################

get '/' do
  if @para = rand_pair
    session[:pair] = @para.id
    if current_user
      current_user.views += 1
      current_user.save
    end
  else
    flash[:notice] = 'W bazie jest jeszcze za mało wyrazów.'
    redirect '/dodaj'
  end
  haml :show
end

get '/info' do
  pair_required
  @para = Pair.get(session[:pair]) or redirect '/'
  haml :info
end
#########################################################################################################################
## RANKING

get '/ranking' do
  ranking(1)
end

get '/ranking/:id' do
  ranking(params[:id].to_i)
end

def ranking(strona)
  ilosc = Pair.count(:scores_mean.gt => 50, :scores_num.gt => 0)
  per_page = 10
  @strony = (ilosc.to_f/per_page).ceil
  @strony = 1 if @strony == 0
  redirect '/ranking' if strona < 1 or strona > @strony
  @strona = strona
  @pary = Pair.all(:order => [:scores_mean.desc, :scores_num.desc, :views.asc, :created_at.desc],
    :scores_mean.gt => 50, :scores_num.gt => 0, :limit => per_page, :offset => (strona - 1)*per_page)
  haml :ranking
end

get '/ranking/ilosc' do
  unless @pairs = Pair.all(:order => [:scores_num.desc, :scores_mean.desc, :views.asc, :created_at.desc],
    :scores_mean.gt => 50, :scores_num.gt => 0, :limit => 50) and @pairs.length > 0
    redirect '/'
  end
  haml :ranking
end

#########################################################################################################################
## PROFIL

get '/profil/:id/nowe' do
  user = User.get(params[:id]) or redirect '/'
  profil_nowe(user, 1)
end

get '/profil/:id/nowe/:page' do
  user = User.get(params[:id]) or redirect '/'
  profil_nowe(user, params[:page].to_i)
end

def profil_nowe(user, strona)
  ilosc = user.words.count
  per_page = 10
  @strony = (ilosc.to_f/per_page).ceil
  @strony = 1 if @strony == 0
  redirect '/profil/' + user.id.to_s if @strony < 1
  redirect '/profil/' + user.id.to_s + '/nowe' if strona < 1 or strona > @strony
  @user = user
  @strona = strona
  @wyrazy = @user.words(:limit => per_page, :offset => (strona - 1)*per_page)
  haml :profil_nowe
end

get '/profil/:id/najlepsze' do
  user = User.get(params[:id]) or redirect '/'
  profil_najlepsze(user, 1)
end

get '/profil/:id/najlepsze/:page' do
  user = User.get(params[:id]) or redirect '/'
  profil_najlepsze(user, params[:page].to_i)
end

def profil_najlepsze(user, strona)
  ilosc = user.words.count
  per_page = 10
  @strony = (ilosc.to_f/per_page).ceil
  @strony = 1 if @strony == 0
  redirect '/profil/' + user.id.to_s if @strony < 1
  redirect '/profil/' + user.id.to_s + '/nowe' if strona < 1 or strona > @strony
  @user = user
  @strona = strona
  @wyrazy = @user.words(:limit => per_page, :offset => (strona - 1)*per_page, :order => [:scores_mean.desc])
  haml :profil_najlepsze
end

#####################
## LUBI

get '/profil' do
  login_required
  pokaz_profil(current_user)
end

get '/profil/:name' do
  user = User.first(:name => params[:name]) and pokaz_profil(user) or pass
end

get '/profil/:id' do
  redirect '/' unless user = User.get(params[:id].to_i)
  pokaz_profil(user)
end

def pokaz_profil(user)
  @user = user
  haml :profil_info
end

get '/profil/:id/lubi' do
  redirect '/' unless user = User.get(params[:id].to_i)
  profil_lubi(user, 1)
end

get '/profil/:id/lubi/:strona' do
  redirect '/' unless user = User.get(params[:id].to_i)
  profil_lubi(user, params[:strona].to_i)
end

get '/profil/:id' do
  user = User.get(params[:id]) and pokaz_profil(user) or redirect '/'
end

def profil_lubi(user, strona)
  ilosc = user.mocne.count
  per_page = 10
  @strony = (ilosc.to_f/per_page).ceil
  @strony = 1 if @strony == 0
  redirect '/profil/' + user.id.to_s if strona < 1
  redirect '/profil/' + @strony.to_s if strona > @strony
  @strona = strona
  @user = user
  @mocne = user.mocne.all(:limit => per_page, :offset => (strona - 1)*per_page)
  haml :profil_lubi
end

#########################################################################################################################
## WYRAZY

get '/moje' do
  login_required
  unless @wyrazy = Word.all(:user_id => current_user.id, :order => [:created_at.desc]) and @wyrazy.length > 0
    redirect '/dodaj'
  end
  haml :wyrazy
end

get '/moje/oceny' do
  login_required
  unless @wyrazy = Word.all(:user_id => current_user.id,
    :order => [:scores_mean.desc, :scores_num.asc, :views.asc]) and @wyrazy.length > 0
    redirect '/dodaj'
  end
  haml :wyrazy
end

get '/wyraz/:id' do
  unless @wyraz = Word.get(params[:id])
    redirect '/'
  end
  haml :wyraz
end

get '/usun/:id' do
  unless wyraz = Word.get(params[:id]) and wyraz.user.id == current_user.id
    redirect '/'
  end
  wyraz.pairs.each do |p|
    p.rates.each do |r|
      r.destroy
    end 
    p.destroy
  end
  wyraz.destroy
  redirect '/dodaj'
end

get '/para/:id' do
  unless @para = Pair.get(params[:id])
    redirect '/'
  end
  haml :para
end

#########################################################################################################################
## OCENIANIE

get '/mocne' do
  pair_required
  p = Pair.get(session[:pair]) or redirect '/'
  rate_pair(p, 1)
  redirect '/'
end

get '/slabe' do
  pair_required
  p = Pair.get(session[:pair]) or redirect '/'
  rate_pair(p, -1)
  redirect '/'
end
#########################################################################################################################
## DODAWANIE

get '/dodaj' do
  login_required
  profil_nowe(current_user, 1)
end

get '/dodaj/:id' do
  dodaj(params[:id].to_i)
end

get '/dodaj' do
  dodaj(1)
end

def dodaj(strona)
  login_required
  ilosc = current_user.words.count
  per_page = 10
  @user = current_user
  @strony = (ilosc.to_f/per_page).ceil
  @strony = 1 if @strony == 0
  redirect '/dodaj' if strona < 1 or strona > @strony
  @strona = strona
  @wyrazy = Word.all(:user_id => current_user.id, :order => [:created_at.desc], :limit => per_page, :offset => (strona - 1)*per_page)
  haml :dodaj
end

post '/dodaj/mianownik' do
  login_required
  m = Mianownik.new(:name => params[:mianownik], :user => current_user)
  unless m.save
    flash[:error] = m.to_s + ' już istnieje'
  end
  redirect '/dodaj'
end

post '/dodaj/dopelniacz' do
  login_required
  m = Dopelniacz.new(:name => params[:dopelniacz], :user => current_user)
  unless m.save
    flash[:error] = m.to_s + ' już istnieje'
  end
  redirect '/dodaj'
end

#########################################################################################################################
## LOGOWANIE

get '/zaloguj' do
  if current_user
    logout
    flash[:notice] = 'Wylogowano'
  end
  haml :login
end

get '/rejestracja' do
  if current_user
    logout
    flash[:notice] = 'Wylogowano'
  end
  haml :signup
end

get '/wyloguj' do
  logout
  flash[:notice] = 'Wylogowano'
  redirect '/'
end

post '/rejestracja' do
  @user = User.new(:name => params[:name], :password => params[:password], :password_confirmation => params[:password_confirmation])
  if @user.save
    login(params[:name], params[:password])
    flash[:notice] = 'Zarejestrowano i zalogowano jako ' + current_user.name.to_s
    redirect '/'
  else
    @errors = @user.errors
    haml :signup
  end
end

post '/zaloguj' do
  if login(params[:name], params[:password])
    flash[:notice] = 'Zalogowano jako ' + current_user.name.to_s
    redirect '/dodaj'
  else
    @login_failed = true
    haml :login
  end
end

#########################################################################################################################
## HELPERS
#########################################################################################################################
helpers do
  def include_css(file)
    url = '/' + file.to_s + '?' + rand(1000000).to_s
    haml '%link{ :rel => "stylesheet", :href => "' + url + '", :type => "text/css"}', :layout => false
  end
  def include_js(file)
    url = '/' + file.to_s + '?' + rand(1000000).to_s
    haml '%script{ :type => "text/javascript", :src => "' + url + '"}', :layout => false
  end
  def partial(name, locals = {})
    haml name, :layout => false, :locals => locals
  end
  
  def login_required
    flash[:error] = 'Niezalogowano' and redirect '/zaloguj' unless logged_in?
  end
  def pair_required
    unless pair = session[:pair]
      flash[:error] = 'Nie pamiętam o jaką parę Ci chodziło...'
      redirect '/'
    end
  end
  
  ## LOGOWANIE
  def login(email, password)
    if @current_user = User.authenticate(email, password)
      session[:user] = @current_user.id
      response.set_cookie('email', email)
      response.set_cookie('password', password)
      @current_user
    else
      logout
    end
  end
  
  def logout
    session[:user] = nil
    response.set_cookie('email', nil)
    response.set_cookie('password', nil)
    nil
  end
  
  def current_user
    @current_user ||= login_from_session || login_from_cookies
  end
  
  def logged_in?
    current_user
  end
  
  def login_from_session
    session[:user] ? User.first(:id => session[:user]) : nil
  end
  
  def login_from_cookies
    (email = request.cookies["email"] and password = request.cookies["password"]) ?
      login(email, password) : nil
  end
  
  def pokaz_wyraz(wyraz, link = true)
    if link
      haml "%a{:href => '/wyraz/' + wyraz.id.to_s }= wyraz.to_s", :locals => {:wyraz => wyraz}, :layout => false
    else
      wyraz.to_s
    end
  end
  
  def koloruj_wyraz(wyraz, link = true)
    if link and current_user and wyraz.user.id == current_user.id
      haml "%a.alpha{:style => 'color: #{color_for(wyraz)};', :href => '/wyraz/' + wyraz.id.to_s }= wyraz.to_s", :locals => {:wyraz => wyraz}, :layout => false
    else
      haml "%span{:style => 'color: #{color_for(wyraz)};'} " + wyraz.to_s, :layout => false
    end
  end
  
  def doublize(num)
    if num < 10
      '0' + num.to_i.to_s
    else
      num.to_i.to_s
    end
  end
  
  def color_for(rateable)
    if rateable.scores_num == 0
      color = '#000'
    elsif rateable.scores_mean > 40 and rateable.scores_mean < 60
      color = '#0000' + doublize(rateable.scores_num.to_f/rateable.views * 59 + 40)
    elsif rateable.scores_mean <= 40
      color = '#' + doublize(((40 - rateable.scores_mean).to_f)/40 * 59 + 40)  + '0000'
    else # para.scores_mean >= 60
      color = '#00' + doublize(((rateable.scores_mean.to_f - 60)/40) * 59 + 40) + '00'
    end
  end
  
  def koloruj_pare(para, link = true)
    if link
      haml "%a.alpha{:style => 'color: #{color_for(para)};', :href => '/para/' + para.id.to_s }= para.to_s", :locals => {:para => para}, :layout => false
    else
      haml "%span{:style => 'color: #{color_for(para)};'} " + para.to_s
    end
  end
  
  def linkuj_pare(para)
    haml "%a{:href => '/para/' + para.id.to_s }= para.to_s", :locals => {:para => para}, :layout => false
  end
  
  def linkuj_wyraz(wyraz)
    if current_user and current_user.id == wyraz.user.id
      haml "%a{:href => '/wyraz/' + wyraz.id.to_s }= wyraz.to_s", :locals => {:wyraz => wyraz}, :layout => false
    else
      wyraz.to_s
    end
  end
  
  def linkuj_profil(profil)
    haml "%a{:href => '/profil/' + profil.id.to_s}= profil.name.to_s", :locals => {:profil => profil}, :layout => false
  end
  
  def koloruj_profil(profil, link = true)
    if profil.scores_num == 0
      color = '#000'
    elsif profil.scores_mean < 50
      color = '#' + doublize(((50 - profil.scores_mean).to_f)/50 * 59 + 40)  + '0000'
    else # para.scores_mean >= 60
      color = '#00' + doublize(((profil.scores_mean.to_f - 50)/50) * 59 + 40) + '00'
    end
    if link
      haml "%a.alpha{:style => 'color: #{color};', :href => '/profil/' + profil.id.to_s}= profil.name.to_s", :locals => {:profil => profil}, :layout => false
    else
      haml "%span{:style => 'color: #{color};'} " + profil.name, :layout => false
    end
  end
  
  def pair_size(pair)
    length_size(pair.mianownik.name.length + pair.dopelniacz.name.length + 1)
  end
  
  def length_size(length)
    if length < 17
      size = 100
    elsif length >= 17 and length < 28
      size = 100 + (17 - length) * 3.3
    else
      size = 66
    end
  end
  
end

#########################################################################################################################
## FLASH
#########################################################################################################################
helpers do
  def flash
    @_flash ||= {}
  end
  def redirect(uri, *args)
    session[:_flash] = flash unless flash.empty?
    status 302
    response['Location'] = uri
    halt(*args)
  end
end

before do
  if session[:_flash] and not session[:_flash].empty?
    @_flash, session[:_flash] = session[:_flash], nil
  end
end

#########################################################################################################################
## VIEWS
#########################################################################################################################
__END__
@@ layout
!!!
%html
  %head
    %title= 'xfq'
    %meta{ :"http-equiv" => 'Content-Type', :content => 'text/html; charset=utf-8'}
    = include_css 'main.css'
    = include_js('jquery.js')
  %body
    = yield

@@ login
= include_js('login.js')
.login
  %form{:id => 'form', :action => '/zaloguj', :method => 'post'}
    .field
      %input{:id => 'name', :name => 'name', :type => 'text', :size => 10, :value => 'login'}
    .field
      %input.gray.center{:id => 'password', :name => 'password', :type => 'text', :size => 10, :value => 'hasło'}
    - if @login_failed
      .red
        Błędne dane logowania
    .zaloguj
      %a.black{:id => 'submit', :href => '#'} zaloguj
    %a{:href => '/rejestracja'} rejestracja
    %a{:href => '/'} wróć

@@ signup
= include_js('login.js')
.signup
  %form{:id => 'form', :action => '/rejestracja', :method => 'post'}
    .field
      %input{:id => 'name', :name => 'name', :type => 'text', :size => 10, :value => 'login'}
    - if @errors and @errors[:name]
      .red
        = @errors[:name].join('<br />')
    .field
      %input.gray.center{:id => 'password', :name => 'password', :type => 'text', :size => 10, :value => 'hasło'}
    - if @errors and @errors[:password]
      .red
        = @errors[:password][0]
    .field
      %input.gray.center{:id => 'password2', :name => 'password_confirmation', :type => 'text', :size => 10, :value => 'znowu hasło'}
    - if @errors and @errors[:password_confirmation]
      .red
        = @errors[:password_confirmation][0]
    .zarejestruj
      %a.black{:id => 'submit', :href => '#'} zarejestruj
    %a{:href => '/zaloguj'} zaloguj
    %a{:href => '/'} wróć

@@ dodawarka
= include_js('dodaj.js')
%form#mianownik-form{:action => '/dodaj/mianownik', :method => 'post'}
  %input#mianownik.center.gray{:name => 'mianownik', :size => 10, :type => 'text', :value => 'mianownik'}
  - if @mianownik_istnieje
    .error
      = @mianownik_errors.inspect.to_s
%form#dopelniacz-form{:id => 'dopelniacz', :action => '/dodaj/dopelniacz', :method => 'post'}
  %input#dopelniacz.center.gray{:name => 'dopelniacz', :size => 10, :type => 'text', :value => 'dopełniacz'}

@@ wyraz
.xfq{:style => 'font-size: ' + length_size(@wyraz.name.length).to_s + 'pt;'}
  = koloruj_wyraz(@wyraz, false)
.para-info
  ocena
  %span.ocena
    = @wyraz.scores_mean.to_s
  ilość ocen
  %span.ilosc_ocen
    = @wyraz.scores_num.to_s
  losowań
  %span.losowan
    = @wyraz.views.to_s
.bottom
  .menu1
    %a{:href => '/'} xfq
    %a{:href => '/usun/' + @wyraz.id.to_s } usuń
  .menu2
    %a{:href => '/ranking'} ranking
    %a{:href => '/dodaj'} dodaj nowe wyrazy
    %a{:href => '/profil'} profil

@@ show
.xfq{:style => 'font-size: ' + pair_size(@para).to_s + 'pt;'}
  %a.alpha{:href => '/info', :style => 'color: ' + color_for(@para) + ';'}= @para.to_s
= partial :bottom

@@ para_info
.para-info
  = linkuj_wyraz(@para.mianownik)
  = koloruj_profil(@para.mianownik.user)
  = linkuj_wyraz(@para.dopelniacz)
  = koloruj_profil(@para.dopelniacz.user)
  %br
  ocena
  %span.ocena
    = @para.scores_mean.to_s
  ilość ocen
  %span.ilosc_ocen
    = @para.rates.count.to_s
  losowań
  %span.losowan
    = @para.views.to_s
    
@@ info
.xfq{:style => 'font-size: ' + pair_size(@para).to_s + 'pt;'}
  = koloruj_pare(@para, false)
= partial :bottom
= partial :para_info

@@ para
.xfq{:style => 'font-size: ' + pair_size(@para).to_s + 'pt;'}
  = koloruj_pare(@para, false)
= partial :lite_bottom
= partial :para_info

@@ strony
.strony
  - if @strona > 1
    %a{:href => link + (@strona - 1).to_s} poprzednie
  - if @strony.to_i > @strona
    %a{:href => link + (@strona + 1).to_s} następne
    
@@ strony_bottom
.bottom
  .menu1
    - if @strona > 1
      %a{:href => link + (@strona - 1).to_s} poprzednie
    - else
      %span{:style => 'color: #eee'} poprzednie
    %a{:href => '/'} xfq
    - if @strony.to_i > @strona
      %a{:href => link + (@strona + 1).to_s} następne
    - else
      %span{:style => 'color: #eee'} następne
  .menu2
    %a{:href => '/ranking'} ranking
    %a{:href => '/dodaj'} dodaj nowe wyrazy
    %a{:href => '/profil'} profil

@@ lite_bottom
.bottom
  .menu1
    %a{:href => '/'} xfq
  .menu2
    %a{:href => '/ranking'} ranking
    %a{:href => '/dodaj'} dodaj nowe wyrazy
    %a{:href => '/profil'} profil

@@ bottom
.bottom
  .menu1
    %a{:href => '/mocne'} mocne
    %a{:href => '/'} xfq
    %a{:href => '/slabe'} słabe
  .menu2
    %a{:href => '/ranking'} ranking
    %a{:href => '/dodaj'} dodaj nowe wyrazy
    %a{:href => '/profil'} profil

@@ ranking
- @pary.each do |p|
  .ranking
    = linkuj_pare(p)
= partial :strony_bottom, :link => '/ranking/'

@@ admin_options
- if current_user and current_user.id == @user.id
  .profil_bar
    %a{:href => '/wyloguj'} wyloguj

@@ profil_info
.side-bar
  .medium
    = koloruj_profil(@user, false)
  .profil_bar
    %a.active{:href => '/profil/' + @user.id.to_s} info
  .profil_bar
    %a{:href => '/profil/' + @user.id.to_s + '/lubi'} mocne
  .profil_bar
    %a{:href => '/profil/' + @user.id.to_s + '/nowe'} wyrazy
  = partial :admin_options
.user-info
  ocena
  %span.ocena
    = @user.scores_mean.to_s
  %br
  ilość ocen
  %span.ilosc_ocen
    = @user.rates.count.to_s
  %br
  losowań
  %span.losowan
    = @user.views.to_s
= partial :lite_bottom

@@ profil_lubi
.side-bar
  .medium
    = koloruj_profil(@user, true)
  .profil_bar
    %a{:href => '/profil/' + @user.id.to_s} info
  .profil_bar
    %a.active{:href => '/profil/' + @user.id.to_s + '/lubi'} mocne
  .profil_bar
    %a{:href => '/profil/' + @user.id.to_s + '/nowe'} wyrazy
  = partial :admin_options
- @mocne.each do |m|
  .ranking
    = linkuj_pare(m.pair)
= partial :strony_bottom, :link => '/profil/' + @user.id.to_s + '/lubi/'

@@ profil_nowe
.side-bar
  .medium
    = koloruj_profil(@user, true)
  .profil_bar
    %a{:href => '/profil/' + @user.id.to_s} info
  .profil_bar
    %a{:href => '/profil/' + @user.id.to_s + '/lubi'} mocne
  .profil_bar.active
    %a.active{:href => '/profil/' + @user.id.to_s + '/nowe'} wyrazy
  .profil_bar2
    %a{:href => '/profil/' + @user.id.to_s + '/najlepsze'} najlepsze
  = partial :admin_options
- if current_user and current_user.id == @user.id
  .top50
    = partial :dodawarka
  - if flash[:error]
    .red
      = flash[:error]
    = partial :lite_bottom
  - else
    .width900
      - @wyrazy.each do |wyraz|
        %a{:href => '/wyraz/' + wyraz.id.to_s }= wyraz.to_s
    = partial :strony_bottom, :link => '/profil/' + @user.id.to_s + '/nowe/'
- else
  - @wyrazy.each do |wyraz|
    .ranking
      %a{:href => '/wyraz/' + wyraz.id.to_s }= wyraz.to_s
  = partial :strony_bottom, :link => '/profil/' + @user.id.to_s + '/nowe/'


@@ profil_najlepsze
.side-bar
  .medium
    = koloruj_profil(@user)
  .profil_bar
    %a{:href => '/profil/' + @user.id.to_s} info
  .profil_bar
    %a{:href => '/profil/' + @user.id.to_s + '/lubi'} mocne
  .profil_bar.active
    %a.active{:href => '/profil/' + @user.id.to_s + '/nowe'} wyrazy
  .profil_bar2
    %a{:href => '/profil/' + @user.id.to_s + '/nowe'} nowe
  = partial :admin_options
- @wyrazy.each do |w|
  .ranking
    = linkuj_wyraz(w)
= partial :strony_bottom, :link => '/profil/' + @user.id.to_s + '/najlepsze/'