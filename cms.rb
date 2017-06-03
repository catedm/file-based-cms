require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

root = File.expand_path("..", __FILE__)

before do
  @files = Dir.glob('data/*').map{ |file| File.basename(file) }
end

get "/" do
  erb :index
end

get "/:filename" do
  file_path = root + "/data/" + params[:filename]
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)

  if File.file?(file_path)
    content_type :text
    File.read(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end
