require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'
require 'fileutils'
require 'yaml'
require 'bcrypt'
require 'pry'

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

root = File.expand_path("..", __FILE__)

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_content(file_path)
  content = File.read(file_path)

  case File.extname(file_path)
  when ".txt"
    headers["Content-Type"] = "text/plain;charset=utf-8"
    content
  when ".md"
    erb render_markdown(content)
  end
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def signed_in?
  if session[:username]
    true
  else
    session[:message] = "You must be signed in to do that."
    status 422
    redirect "/"
  end
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yaml", __FILE__)
  else
    File.expand_path("../users.yaml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

def valid_file_type?(file)
  !(File.extname(file) == ".md" || File.extname(file) == ".txt")
end

def add_user_to_database(username, password)
  users = load_user_credentials
  users[username] = password.to_s
  File.open("./users.yaml", "w") { |f| f.write users.to_yaml } #Store
end

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob('data/*').map{ |file| File.basename(file) }

  erb :index
end

get "/new" do
  signed_in?
  erb :new
end

post "/create" do
  signed_in?

  filename = params[:title].to_s

  if filename.size == 0
    session[:message] = "A name is required."
    status 422
    erb :new
  elsif valid_file_type?(filename)
    session[:message] = "This application only accepts .md and .txt files."
    status 422
    erb :new
  else
    file_path = File.join(data_path, filename)

    File.write(file_path, "")
    session[:message] = "#{params[:title]} was created."

    redirect "/"
  end
end

get "/imageupload" do
  signed_in?
  erb :imageupload
end

post '/save_image' do
  @filename = params[:file][:filename]
  file = params[:file][:tempfile]

  File.open("./media/#{@filename}", 'wb') do |f|
    f.write(file.read)
  end

  redirect "/mediabank"
end

get "/mediabank" do
  @files = Dir.glob('media/*').map{ |file| File.basename(file) }

  erb :mediabank
end

get '/media/:image' do
  file = params[:image]

  File.open("./media/#{params[:image]}", 'wb') do |f|
    f.write(file.read)
  end
end

get "/:filename" do

  file_path = File.join(data_path, params[:filename])

  if File.file?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  signed_in?

  file_path = File.join(data_path, params[:filename])

  @filename = params[:filename]
  @content = File.read(file_path)

  erb :edit
end

post "/:filename" do
  signed_in?

  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:content])

  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end

post "/:filename/delete" do
  signed_in?

  file_path = File.join(data_path, params[:filename])

  File.delete(file_path)

  session[:message] = "#{params[:filename]} has been deleted."
  redirect "/"
end

get "/users/signin" do
  erb :signin
end

post "/users/signin" do
  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:username] = params[:username]
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid Credentials."
    status 422
    erb :signin
  end
end

post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end

post '/:filename/duplicate' do
  signed_in?

  old_filename = params[:filename].to_s
  old_file_path = File.join(data_path, old_filename)
  content_to_copy = File.read(old_file_path)

  ext = File.extname(old_filename)
  base_filename = File.basename(old_filename, ext)
  copied_filename = base_filename + "_copy" + ext
  new_file_path = File.join(data_path, content_to_copy)

  File.write(new_file_path, content)

  session[:message] = "#{params[:filename]} was duplicated."
  redirect "/"
end

get '/users/signup' do
  erb :signup
end

post '/users/signup' do
  username = params[:username]
  password = params[:password]
  credentials = load_user_credentials

  if credentials.key?(username)
    session[:message] = "This username has already been taken."
    status 422
    erb :signup
  elsif username.empty? || password.empty?
    session[:message] = "Must enter both a username and a password."
    status 422
    erb :signup
  else
    bcrypt_password = BCrypt::Password.create(password)
    add_user_to_database(username, bcrypt_password)
    session[:message] = "You have successfully registered."
    redirect "/users/signin"
  end
end
