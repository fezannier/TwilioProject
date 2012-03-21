require 'sinatra'
require "dm-core"
require "twilio-ruby"
require 'time'

DataMapper::setup(:default, {:adapter => 'yaml', :path => 'db'})

class User
        include DataMapper::Resource

        property :id,           Serial
        property :name,         String
        property :number,       String
        property :message,      String
	property :category,		String
        property :called,       Boolean, :default  => false
end

DataMapper.finalize

# find your credentials at twilio.com/user/account
account_sid = 'ACa0606842de5944e09074a5dbaeb2612d'
auth_token = 'd54d8f5c5f105f67613ccc93cdadc90e'

@client = Twilio::REST::Client.new account_sid, auth_token

get '/' do
  erb :welcome
end

get '/testSMS' do
        @client = Twilio::REST::Client.new account_sid, auth_token
        @client.account.sms.messages.create(:from => '+16464806647',:to => params[:number],:body => 'test')
        "message sent"
end
          
post '/save' do
        user = User.first(:number => params[:number])
        if(user != nil)
                user.number = params[:number]
		user.name = params[:name]
		user.category = params[:category]
                user.called = false
		user.save
        else 
                user = User.new
                user.name = params[:name]
                user.number = params[:number]
		user.category = params[:category]
                user.save 
        end
        redirect "~web/sinatra/sms/story"
end 
    
post '/start' do
        stringUrl = '~web/sinatra/sms/wall?category='
	stringUrl += params[:category]
	redirect stringUrl
end

get '/select' do
	erb :thestory
end

get '/wall' do
        @total = User.all.size
        @account_sid = 'ACa0606842de5944e09074a5dbaeb2612d'
        @auth_token = 'd54d8f5c5f105f67613ccc93cdadc90e'
        @client = Twilio::REST::Client.new(@account_sid, @auth_token)
        @string = ""
        @account = @client.account
        count  = 0
        @previous = 'This time you start the game - write the beginning of the '
	@previous += params[:category]
	@previous += ' story'
        while (count < @total)
                newline = ""
		user = User.first(:called => false, :category => params[:category])
                if(user == nil)
			break
		end
		user.called = true
                msg_sent_twilio = Time.now.utc
                @client.account.sms.messages.create(:from => '+16464806647',:to => user.number,:body => @previous)
                responded = false
                while (responded == false)
                        @account.sms.messages.list({}).each do |@message|
				if(@message.status == 'received' && @message.from == user.number)
                                        msg_sent_user = Time.parse @message.date_sent
                                        if(msg_sent_user >= msg_sent_twilio)
                                                newline = @message.body
						responded = true
                                        end
                                end
                        end
                end
                user.message = newline
		user.category = params[:category]
                user.save
                @previous = newline
                count += 1
        end
        @account.sms.messages.list({}).each do |@message|
                if(@message.status == 'received')
                        user = User.first(:number => @message.from,:category => params[:category])
                        if(user != nil)
                               	user.message = @message.body
                               	user.save
                               	@string += "<tr class=\"paragraph\"> <td class=\"name\">"
                               	@string += user.name
                               	@string += "</td><td class=\"message\"> "
                               	@string += @message.body
                               	@string += "</td></tr>"
                        end
                end
        end
        erb :thewall
end

get '/story' do
        erb :thestory
end
