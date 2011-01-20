# Application Generator Template
# Usage: rails new app_name -d mysql -m rails3.rb

#----------------------------------------------------------------------------
# Set up git
#----------------------------------------------------------------------------
puts "setting up source control with 'git'..."
# specific to Mac OS X
append_file '.gitignore' do
  '.DS_Store'
end
git :init
git :add => '.'
git :commit => "-m 'Initial commit of unmodified new Rails app'"

#----------------------------------------------------------------------------
# Remove the usual cruft
#----------------------------------------------------------------------------
puts "removing unneeded files..."
run 'rm public/index.html'
run 'rm public/favicon.ico'
run 'rm public/images/rails.png'
run 'rm README'
run 'touch README.md'

#----------------------------------------------------------------------------
# Gems
#----------------------------------------------------------------------------
puts "setting up Gemfile..."
append_file 'Gemfile', "\n"

# for markdown content
gem 'rdiscount', '1.6.5'

# haml alternative to erb for template markup
gem 'haml', '3.0.25'
gem 'jquery-rails', '0.2.6'

# accounts and authentication
gem 'devise', '1.1.5'

# image uploads
gem 'mini_magick', '3.2'
gem 'carrierwave', '0.5.1'

# thin controllers
gem 'inherited_resources', '1.1.2'
gem 'has_scope', '0.5.0'
gem 'responders', '0.6.2'

# pagination
gem 'will_paginate', '3.0.pre2'

# simple forms
gem 'simple_form', '1.3.0'

# friendly urls (slugs)
gem 'friendly_id', '3.1.7'

group :development do
  gem 'haml-rails', '0.3.4'
  gem 'hpricot', '0.8.3'
  gem 'ruby_parser', '2.0.5'
  gem 'nifty-generators', '0.4.4'
  gem RUBY_VERSION >= "1.9" ? 'ruby-debug19' : 'ruby-debug'
  gem 'capistrano', '2.5.19'
  gem 'mongrel', '1.2.0.pre2'
end

group :development, :test do
  # testing
  gem 'shoulda', '2.11.3'
  gem 'factory_girl_rails', '1.1.beta1'
end

puts "installing gems (takes a few minutes!)..."
run 'bundle install'

puts "prevent logging of passwords"
gsub_file 'config/application.rb', /:password/, ':password, :password_confirmation'

#----------------------------------------------------------------------------
# Generate the application config (nifty gen)
#----------------------------------------------------------------------------
run 'rails g nifty:config'

#----------------------------------------------------------------------------
# Set up jQuery
#----------------------------------------------------------------------------
run 'rm public/javascripts/rails.js'
puts "replacing Prototype with jQuery"
# "--ui" enables optional jQuery UI
run 'rails g jquery:install --ui'

#----------------------------------------------------------------------------
# Set up Friendly Id
#----------------------------------------------------------------------------
run 'rails g friendly_id'

#----------------------------------------------------------------------------
# Set up Devise
#----------------------------------------------------------------------------
puts "creating 'config/initializers/devise.rb' Devise configuration file..."
run 'rails generate devise:install'
run 'rails generate devise:views'

puts "modifying environment configuration files for Devise..."
gsub_file 'config/environments/development.rb', /# Don't care if the mailer can't send/, '### ActionMailer Config'
gsub_file 'config/environments/development.rb', /config.action_mailer.raise_delivery_errors = false/ do
<<-RUBY
config.action_mailer.default_url_options = { :host => 'localhost:3000' }
  # A dummy setup for development - no deliveries, but logged
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.perform_deliveries = false
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default :charset => "utf-8"
RUBY
end
gsub_file 'config/environments/production.rb', /config.i18n.fallbacks = true/ do
<<-RUBY
config.i18n.fallbacks = true

  config.action_mailer.default_url_options = { :host => 'yourhost.com' }
  ### ActionMailer Config
  # Setup for production - deliveries, no errors raised
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.default :charset => "utf-8"
RUBY
end

puts "creating a User model and modifying routes for Devise..."
run 'rails generate devise User'

puts "adding a 'name' attribute to the User model"
gsub_file 'app/models/user.rb', 'attr_accessible ', 'attr_accessible :name, '
gsub_file 'app/models/user.rb', /end/ do
<<-RUBY
  validates_presence_of :name
  validates_uniqueness_of :name, :email, :case_sensitive => false
end
RUBY
end

#----------------------------------------------------------------------------
# Modify Devise migration
#----------------------------------------------------------------------------
puts "modifying the default Devise user migration to add 'name'..."
inject_into_file Dir.glob("db/migrate/*.rb")[0], :after => "t.trackable\n" do
<<-RUBY
      t.string :name, :limit => 64
RUBY
end

puts "Create and migrate the database."
run 'rake db:create'
run 'rake db:migrate'

#----------------------------------------------------------------------------
# Modify Devise views
#----------------------------------------------------------------------------
puts "implement simple_form in devise views"
gsub_file 'app/views/devise/confirmations/new.html.haml', 'form_for', 'simple_form_for'
gsub_file 'app/views/devise/passwords/new.html.haml', 'form_for', 'simple_form_for'
gsub_file 'app/views/devise/passwords/edit.html.haml', 'form_for', 'simple_form_for'
gsub_file 'app/views/devise/registrations/new.html.haml', 'form_for', 'simple_form_for'
gsub_file 'app/views/devise/registrations/edit.html.haml', 'form_for', 'simple_form_for'
gsub_file 'app/views/devise/sessions/new.html.haml', 'form_for', 'simple_form_for'
gsub_file 'app/views/devise/unlocks/new.html.haml', 'form_for', 'simple_form_for'

puts "modifying the default Devise user registration to add 'name'..."
inject_into_file "app/views/devise/registrations/edit.html.haml", :after => "= devise_error_messages!\n" do
<<-RUBY
  %p
    = f.label :name
    %br/
    = f.text_field :name
RUBY
end

inject_into_file "app/views/devise/registrations/new.html.haml", :after => "= devise_error_messages!\n" do
<<-RUBY
  %p
    = f.label :name
    %br/
    = f.text_field :name
RUBY
end


#----------------------------------------------------------------------------
# Create a home page
#----------------------------------------------------------------------------
puts "create a home controller and view"
generate(:controller, "home index")
gsub_file 'config/routes.rb', /get \"home\/index\"/, 'root :to => "home#index"'

puts "set up a simple demonstration of Devise"
gsub_file 'app/controllers/home_controller.rb', /def index/ do
<<-RUBY
def index
    @users = User.all
RUBY
end

run 'rm app/views/home/index.html.haml'
# we have to use single-quote-style-heredoc to avoid interpolation
create_file 'app/views/home/index.html.haml' do 
<<-'FILE'
- @users.each do |user|
  %p User: #{link_to user.name, user}
FILE
end


#----------------------------------------------------------------------------
# Create a users page
#----------------------------------------------------------------------------
generate(:controller, "users show")
gsub_file 'config/routes.rb', /get \"users\/show\"/, '#get \"users\/show\"'
gsub_file 'config/routes.rb', /devise_for :users/ do
<<-RUBY
devise_for :users
  resources :users, :only => :show
RUBY
end

gsub_file 'app/controllers/users_controller.rb', /def show/ do
<<-RUBY
before_filter :authenticate_user!

  def show
    @user = User.find(params[:id])
RUBY
end

run 'rm app/views/users/show.html.haml'
# we have to use single-quote-style-heredoc to avoid interpolation
create_file 'app/views/users/show.html.haml' do <<-'FILE'
%p
  User: #{@user.name}
  FILE
end


create_file "app/views/devise/menu/_login_items.html.haml" do <<-'FILE'
- if user_signed_in?
  %li
    = link_to('Logout', destroy_user_session_path)
- else
  %li
    = link_to('Login', new_user_session_path)
  FILE
end


create_file "app/views/devise/menu/_registration_items.html.haml" do <<-'FILE'
- if user_signed_in?
  %li
    = link_to('Edit account', edit_user_registration_path)
- else
  %li
    = link_to('Sign up', new_user_registration_path)
  FILE
end


#----------------------------------------------------------------------------
# Create the admin namespace and user management
#----------------------------------------------------------------------------
puts "Setting up admin namespace and user management."

create_file 'app/controllers/admin/users_controller.rb' do <<-FILE
class Admin::UsersController < InheritedResources::Base
  layout 'admin'
  respond_to :html
  before_filter :authenticate_admin!

  protected #----
    def collection
      @users ||= end_of_association_chain.paginate(:page => params[:page], :per_page => 20, :sort => 'name')
    end
end
FILE
end

inject_into_file "app/controllers/application_controller.rb", :after => "protect_from_forgery\n" do
<<-RUBY

  protected #--------

  # just using basic auth for the admin section
  def authenticate_admin!
    authenticate_or_request_with_http_basic do |user_name, password|
      user_name == 'replace_me' && password == 'replace_me'
    end if RAILS_ENV == 'production' || params[:admin_http]
  end
  
RUBY
end

# namespace
inject_into_file "config/routes.rb", :after => "resources :users, :only => :show\n" do
<<-RUBY

  match 'admin' => 'admin/users#index'
  namespace :admin do
    resources :users
  end
  
RUBY
end

#----------------------------------------------------------------------------
# Generate Application Layout
#----------------------------------------------------------------------------

run 'rm app/views/layouts/application.html.erb'
create_file 'app/views/layouts/application.html.haml' do <<-FILE
!!!
%html
  %head
    %title Testapp
    = stylesheet_link_tag :all
    = javascript_include_tag :defaults
    = csrf_meta_tag
  %body
    %ul.hmenu
      = render 'devise/menu/registration_items'
      = render 'devise/menu/login_items'
    %p{:style => "color: green"}= notice
    %p{:style => "color: red"}= alert
    = yield
FILE
end

create_file 'app/views/layouts/admin.html.haml' do <<-FILE
!!!
%html
  %head
    %title Testapp Admin
    = stylesheet_link_tag :all
    = javascript_include_tag :defaults
    = csrf_meta_tag
  %body
    %p{:style => "color: green"}= notice
    %p{:style => "color: red"}= alert
    = yield
FILE
end


#----------------------------------------------------------------------------
# Add Stylesheets
#----------------------------------------------------------------------------
create_file 'public/stylesheets/sass/application.sass' do <<-FILE
ul.hmenu
  list-style: none
  margin: 0 0 2em
  padding: 0

ul.hmenu li
  display: inline
FILE
end

create_file 'public/stylesheets/sass/admin.sass' do <<-FILE
// admin styles
FILE
end


#----------------------------------------------------------------------------
# Simple Form
#----------------------------------------------------------------------------
run "rails generate simple_form:install"


#----------------------------------------------------------------------------
# Creatives
#----------------------------------------------------------------------------
create_file 'creatives/src/README.mb' do <<-FILE
# Photoshop files etc.
FILE
end


#----------------------------------------------------------------------------
# Create a default user
#----------------------------------------------------------------------------
append_file 'db/seeds.rb' do <<-FILE
puts 'Creating default user...'
user = User.create! :name => 'First User', :email => 'user@test.com', :password => 'password', :password_confirmation => 'password'
puts 'New user created: ' << user.name
FILE
end
puts "Seed the database"
run 'rake db:seed'

#----------------------------------------------------------------------------
# Finish up
#----------------------------------------------------------------------------
puts "checking everything into git..."
git :add => '.'
git :commit => "-am 'Initial commit'"

puts "Done setting up your Rails app."