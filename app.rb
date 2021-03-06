require "sinatra"
require "rack-flash"
require "gschool_database_connection"

class App < Sinatra::Application
  enable :sessions
  use Rack::Flash

  def initialize
    super
    @database_connection = GschoolDatabaseConnection::DatabaseConnection.establish(ENV["RACK_ENV"])
  end

  get "/" do
    if session[:user_id]
      p "*"*80
      @username = @database_connection.sql("SELECT username FROM users WHERE id=#{session[:user_id]};").first["username"]
      @user_arr = @database_connection.sql("SELECT username FROM users;").map {|hash| hash["username"] if hash["username"] != @username}
      @user_arr.delete(nil)

      @fav_fish_arr = @database_connection.sql(
        "SELECT favorites.id, fish.name as fish_name FROM favorites " +
          "INNER JOIN users on users.id = favorites.users_id " +
          "INNER JOIN fish on fish.id = favorites.fish_id " +
          "WHERE users.id = '#{session[:user_id]}'"
      ).uniq

      @fish_arr = @database_connection.sql("SELECT name, wiki FROM fish WHERE users_id = '#{session[:user_id]}';")

      if params[:sort] == "asc"
        @user_arr.sort!
      elsif params[:sort] == "desc"
        @user_arr.sort! { |x,y| y <=> x }
      end
      if session[:clicked_user_id]
        @click_user_fish = @database_connection.sql("SELECT id, name, wiki FROM fish WHERE users_id = '#{session[:clicked_user_id]}';")
      else
        @click_user_fish = []
      end

      erb :logged_in, :locals => {:username => @username,
                                 :user_arr => @user_arr,
                                 :fish_arr => @fish_arr,
                                 :click_user_fish => @click_user_fish,
                                 :fav_fish_arr => @fav_fish_arr}, :layout => :main_layout
    else
      erb :logged_out, :layout => :main_layout
    end
  end

  # get "/" do
  #   if session[:user_id]
  #     @username = @database_connection.sql("SELECT username FROM users WHERE id=#{session[:user_id]};").first["username"]
  #     @user_arr = @database_connection.sql("SELECT username FROM users;").map {|hash| hash["username"] if hash["username"] != @username}
  #     @user_arr.delete(nil)
  #
  #     @fav_fish_arr = @database_connection.sql(
  #       "SELECT favorites.id, fish.name as fish_name FROM favorites " +
  #       "INNER JOIN users on users.id = favorites.users_id " +
  #       "INNER JOIN fish on fish.id = favorites.fish_id " +
  #       "WHERE users.id = '#{session[:user_id]}'"
  #       ).uniq
  #
  #     @fish_arr = @database_connection.sql("SELECT name, wiki FROM fish WHERE users_id = '#{session[:user_id]}';")
  #   end
  #
  #   if params[:sort] == "asc"
  #     @user_arr.sort!
  #   elsif params[:sort] == "desc"
  #     @user_arr.sort! { |x,y| y <=> x }
  #   end
  #   if session[:clicked_user_id]
  #     @click_user_fish = @database_connection.sql("SELECT id, name, wiki FROM fish WHERE users_id = '#{session[:clicked_user_id]}';")
  #   else
  #     @click_user_fish = []
  #   end
  #
  #   erb :root, :locals => {:username => @username,
  #                          :user_arr => @user_arr,
  #                          :fish_arr => @fish_arr,
  #                          :click_user_fish => @click_user_fish,
  #                          :fav_fish_arr => @fav_fish_arr}, :layout => :main_layout
  # end

  get "/fish/" do
    erb :create_fish, :layout => :main_layout
  end

  get "/register/" do
    erb :register, :layout => :main_layout
  end

  delete "/delete/:username" do
    @database_connection.sql("DELETE FROM users WHERE username = '#{params[:username]}'")
    redirect "/"
  end

  post "/fish/" do
    unless session[:user_id]
      redirect "/"
    end

    if params[:name] == "" && params[:wiki] == ""
      flash[:notice] = "Please enter a name and wikipedia page."
      redirect "/fish/"
    elsif params[:name] == ""
      flash[:notice] = "Please enter a name."
      redirect "/fish/"
    elsif params[:wiki] == ""
      flash[:notice] = "Please enter a wikipedia page."
      redirect "/fish/"
    end

    @database_connection.sql("INSERT INTO fish (users_id, name, wiki) VALUES (#{session[:user_id]},'#{params[:name]}','#{params[:wiki]}')")
    redirect "/"

  end

  post "/register/" do
    if params[:password] == "" && params[:username] == ""
      flash[:login_fail] = "Please enter a username and password."
      redirect "/register/"
    elsif params[:password] == ""
      flash[:login_fail] = "Please enter a password."
      redirect "/register/"
    elsif params[:username] == ""
      flash[:login_fail] = "Please enter a username."
      redirect "/register/"
    end

    begin
      @database_connection.sql("INSERT INTO users (username, password) VALUES ('#{params[:username]}', '#{params[:password]}')")
      flash[:register_notice] = "Thank you for registering"
      redirect "/"
    rescue
      flash[:login_fail] = "That name is taken."
      redirect "/register/"
    end
  end

  post "/login/" do
    user_hashes_arr = @database_connection.sql("select * from users")
    user_hash = user_hashes_arr.detect do |hash|
      params[:username] == hash["username"] && params[:password] == hash["password"]
    end

    if user_hash
      session[:user_id] = user_hash["id"]
      session[:clicked_user_id] = nil
    end

    redirect "/"
  end

  get "/favorites/:id" do
    @database_connection.sql("INSERT INTO favorites (users_id, fish_id) VALUES ('#{session[:user_id]}','#{params[:id]}')")
    redirect "/"
  end

  get "/unfavorite/:id" do
    @database_connection.sql("DELETE FROM favorites WHERE id = '#{params[:id]}'")
    redirect "/"
  end

  get "/logout/" do
    session[:user_id] = nil
    redirect "/"
  end

end
