[
	'rubygems',
	'open-uri',
	'mechanize',
	'json'
].each{|g| 
	require g
}


def salt_generator(url)
	agent = Mechanize.new
	authors = Array['Kaz', '(^o^)', 'Phantom.of.the.server', 'Seravy', 'Googoo64', 'Spacemouse', 'The_none', 'Rakurai', 'Iqs']
	karins = Array['Blue eyes white karin', 'Dark karin', 'Dark karin EX2', 'Karin CVS', 'Karin kanzuki', 'Sakura&karin', 'PMSTwin']
	sakuras = Array['Bc-sakura', 'Cvs sakura', 'Dark sakura', 'Master sakura', 'Pocket Sakura']
	mamis = Array['Mami', 'Mami EX', 'Megamami', 'Megamami EX2']
	# SEC 1: SIGN IN
	def signin(main_url, mech_agent, email, pass)
		signin = '/authenticate?signin=1'
		form_url = main_url+signin

		begin
			signin_form = mech_agent.get(form_url).forms[0]
		rescue Exception => e
			p "ERROR OPENING #{form_url}: #{e}"
			return false
		end

		signin_form['authenticate'] = 'signin'
		signin_form['email'] = email
		signin_form['pword'] = pass
		return signin_form
	end

	begin
		main_page = signin(url,agent,ARGV[0],ARGV[1]).submit # REPLACE ARGV VARIABLES WITH YOUR USERNAME AND PASSWORD IF YOU WANT TO RUN THE CODE FROM RUBY
	rescue Exception => e
		p "ERROR LOGGING IN: #{e}. RETRYING IN 5 SECONDS"
		sleep 5
		retry
	end


	# GET BET STATUS
	begin
		stateJSON = agent.get(url+'/state.json').body #=> {p1nam:'...', p2name:'...', ... status:'...', ...}
	rescue Exception => e
		p "ERROR GETTING 'state.json' AT #{Time.now}: #{e}. RETRYING IN 5 SECONDS..."
		sleep 5
		retry
	end # DONE: begin...


	status_hsh = JSON.parse(stateJSON)
	bet_status = status_hsh['status'] # Are bets 'open' or 'locked'?

	if(bet_status == 'open')
		# GET FIGHTER NAMES
		p1 = status_hsh['p1name'] # Name of red team
		p2 = status_hsh['p2name'] # Name of blue team

		statsJSON = agent.get(url+'/ajax_get_stats.php').body # Get winrates for both fighters (or teams if it's an exhibition match)
		stats_hsh = JSON.parse(statsJSON)

		def winrate_getter(winrate_str)
			if(winrate_str.include?('/'))
				winrate_arr = winrate_str.split('/')
				w1 = winrate_arr[0].to_f
				w2 = winrate_arr[1].to_f
				return (w1+w2)/2
			else
				return winrate_str.to_f
			end			
		end
		p1_winrate = winrate_getter(stats_hsh['p1winrate'])
		p1_author = stats_hsh['p1author']
		p1_palette = stats_hsh['p1palette']
		p2_winrate = winrate_getter(stats_hsh['p2winrate'])
		p2_author = stats_hsh['p2author']
		p2_palette = stats_hsh['p1palette']
		reason = ''
		p stats_hsh
		# DECIDING WHO TO BET ON 
		# IWS - Messy, still learning ruby Kappa
		if (karins.include? p1) && (karins.include? p2)
			selectedplayer = (p1_winrate > p2_winrate) ? 'player1' : 'player2'
			hasKarin = true
			reason = 'Karin Stat Bet'
		elsif (karins.include? p1) || (p1.include? 'PMSTwin')
			selectedplayer = "player1"
			hasKarin = true
			reason = 'Karin Bet'
		elsif (karins.include? p2) || (p2.include? 'PMSTwin')
			hasKarin = true
			selectedplayer = 'player2'
			reason = 'Karin Bet'
		elsif (sakuras.include? p1) && (sakuras.include? p2)
			selectedplayer = (p1_winrate > p2_winrate) ? 'player1' : 'player2'
			reason = 'Sakura Stat Bet'
		elsif (sakuras.include? p1)
			selectedplayer = "player1"
			reason = 'Sakura Bet'
		elsif (sakuras.include? p2)
			selectedplayer = "player2"
			reason = 'Sakura Bet'
		elsif (mamis.include? p1) && (mamis.include? p2)
			selectedplayer = (p1_winrate > p2_winrate) ? 'player1' : 'player2'
			reason = 'Mami Stat Bet'
		elsif (mamis.include? p1)
			selectedplayer = "player1"
			reason = 'Mami Bet'
		elsif (mamis.include? p2)
			selectedplayer = "player2"
			reason = 'Mami Bet'
		elsif (p1_palette == '12')
			selectedplayer = 'player1'
			reason = '12 Palette Bet'
		elsif (p2_palette == '12')
			selectedplayer = 'player2'
			reason = '12 Palette Bet'
		elsif authors.include? p1_author
			selectedplayer = 'player1'
			reason = 'Author Bet'
		elsif authors.include? p2_author
			selectedplayer = 'player2'
			reason = 'Author Bet'
		else
			selectedplayer = (p1_winrate < p2_winrate) ? 'player1' : 'player2'
			reason = 'Upset Bet'
		end	

		# CURRENT SALT BALANCE AND HOW MUCH TO BET
		curr_salt = main_page.search('#balance')[0].text.gsub(',','').to_i # How much Salt I currently have
		all_in_threshold = 2500
		wager = (curr_salt<all_in_threshold) ? curr_salt : 
			(curr_salt<50000) ? 2500  : 
			(curr_salt<100000) ? 3500 : 
			(curr_salt<1000000) ? 5000 :
			(curr_salt<5000000) ? 7500 :
			(curr_salt<10000000) ? 10000 :
			(curr_salt<20000000) ? 15000 :
			20000
		if hasKarin
			wager = curr_salt
		else
			wager = wager.round
		end

		# PREAMBLE TO THE BET
		p "Signed in as #{ARGV[0]}",
		"Bets are '#{bet_status}'",
		"Current balance: $#{curr_salt}",
		"Player 1: '#{p1}' by #{p1_author} with win ratio of #{p1_winrate}",
		"Player 2: '#{p2}' by #{p2_author} with win ratio of #{p2_winrate}",
		"BOT WILL BET $#{wager} ON #{selectedplayer}... Reason: #{reason}...",
		'==='

		# PLACE THE BET AND PRINT CONFIRMATION
		begin
			agent.post(
				url+'/ajax_place_bet.php',
				{
					'radio'=>'on',
					'selectedplayer'=>selectedplayer,
					'wager'=>wager.to_s
				}
			)		
		rescue Exception => e
			p "ERROR PLACING BET: #{e}",
			"RETRYING IN 3 SECONDS..."
			sleep 3
			retry
		end # DONE: begin...

		p "BET COMPLETED AT #{Time.now}!"
		sleep 60



		# GET BET STATUS
		begin
			stateJSON = agent.get(url+'/state.json').body #=> {p1nam:'...', p2name:'...', ... status:'...', ...}
		rescue Exception => e
			p "ERROR GETTING 'state.json', RETRYING IN 5 SECONDS..."
			sleep 5
			retry
		end # DONE: begin...

		
		main_page = agent.get(url)
		p "=================================================="
		salt_generator(url) # Recursive method...the script checks the bets again and again...
	else
		p "BETS ARE LOCKED! THE TIME IS #{Time.now}. RE-CHECKING BET STATUS IN 30 SECONDS..."
		sleep 30


		# GET BET STATUS
		begin
			stateJSON = agent.get(url+'/state.json').body #=> {p1nam:'...', p2name:'...', ... status:'...', ...}
		rescue Exception => e
			p "ERROR GETTING 'state.json' AT #{Time.now}, RETRYING IN 5 SECONDS..."
			sleep 5
			retry
		end # DONE: begin...

		
		main_page = agent.get(url)
		p "=========================="
		begin
			salt_generator(url) # Recursive method...the script checks the bets again and again...
		rescue Exception => e
			p "ERROR AT #{Time.now}: #{e}"
			return false
		end
		
	end	# DONE: if(bet_status == 'open')	
end # DONE: def salt_generator(stateJSON)

begin
	url = 'http://www.saltybet.com'

	# After a while of the method running, there is usually an error, so we have the method return false.
	# When it does that, hopefully we can re-run the method...
	# if(salt_generator(url)===false)
	# 	salt_generator(url)
	# end	

	(1..9999).each{|x|
		salt_generator(url)
	}
rescue Exception => e
	p "ERROR: #{e}"
	puts e.backtrace

	errorLog = 'ERRORS.txt'

	if(File.exist?(errorLog)===false)
		File.open(errorLog,'w')
	end

	File.open(errorLog,'a'){|f|
		[
			'====================',
			Time.now,
			e,
			e.backtrace
		].each{|err| 
			f.puts(err)
		}
	}
	exit
end
