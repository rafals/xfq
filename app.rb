require 'rubygems'
require 'sinatra'
require 'datamapper'
require 'haml'

DataMapper.setup(:default, "sqlite3:///#{Dir.pwd}/database.db")

set :sessions,  true
set :environment, :production

class Word
  include DataMapper::Resource
  property :name,       String, :unique => true, :key => true
  property :mianownik, Boolean, :default => true
  property :created_at, DateTime
end

DataMapper.auto_upgrade!

get '/' do
  if mians = Word.all(:mianownik => true) and mians.count > 0 and dops = Word.all(:mianownik => false) and dops.count > 0
    @mianownik = mians[rand(mians.count)]
    @dopelniacz = dops[rand(dops.count)]
    haml :show
  else
    redirect '/add'
  end
end

get '/add' do
  session[:created] ||= []
  @words = session[:created].map do |word|
    Word.first(:name => word)
  end
  haml :add
end

def add(word, mianownik)
  unless created = Word.first(:name => word)
    created = Word.new
    created.name = word
    created.mianownik = mianownik
    created.save
    session[:created] ||= []
    session[:created] << word
    created
  end
end

post '/add/m' do
  add(params[:word], true)
  redirect '/add'
end

post '/add/d' do
  add(params[:word], false)
  redirect '/add'
end

get '/delete/:word' do
  session[:created] ||= []
  if session[:created].delete(params[:word]) and word = Word.first(:name => params[:word])
    word.destroy
  end
  redirect '/add'
end

use_in_file_templates!
__END__
@@ layout
!!!
%html
  %head
    <meta http-equiv="content-type" content="text/html;charset=UTF-8" />
    %title xfq
    %link{:type => "text/css", :rel => "stylesheet", :href => "/main.css?" + rand(1000000).to_s}
  %body
    .center
      = yield

@@ show
.big
  = @mianownik.name
  = @dopelniacz.name
%a{:href => '/add'} dodaj nowe wyrazy

@@ add
%a{:href => '/'} wróć
%br
mianownik:
%form{:method => 'POST', :action => '/add/m'}
  %input{:type => 'text', :size => 10, :name => 'word'}
dopełniacz:
%form{:method => 'POST', :action => '/add/d'}
  %input{:type => 'text', :size => 10, :name => 'word'}
- @words.each do |word|
  = word.name
  %a{:href => '/delete/' + word.name.to_s} usuń
  %br