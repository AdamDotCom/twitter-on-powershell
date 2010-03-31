#----------------------------------------------------------------------------------------
#
# A Twitter client for PowerShell
#
# Sample usage:
#    
#  Post a tweet
#    PS> tweet "Hello World I'm tweeting from powershell"
#    
#  Search for a keyword or phrase
#    PS> search-twitter swine+flu
#    
#  See what your friends are saying
#    PS> friends
#    
#  View your replies
#    PS> replies
#    
#  Export your tweets to file
#    PS> export-tweets adamdotcom > my-tweets.xml
#
# Adam Kahtava - http://adam.kahtava.com/ - MIT Licensed    
#
#-------------------------------------------------------------------

# Post a message to twitter then list friends' conversations
function global:Tweet([string] $message){
    Twitter-Sign-on
    
    Post-Tweet $global:twitter_username $global:twitter_password $message
    
    Get-Tweets $global:twitter_username $global:twitter_password $message
}

# Get friends' conversations
function global:Friends(){
    Twitter-Sign-on
    
    Get-Tweets $global:twitter_username $global:twitter_password
}

# Get replies
function global:Replies(){
    Twitter-Sign-on
    
    $search_query = 'to:{0}' -f $global:twitter_username
    
    Search-Twitter $search_query
}

# Search twitter (free text)
function global:Search-Twitter([string] $search_query){
	$url = 'http://search.twitter.com/search.atom?q={0}&rpp={1}' -f $search_query, 80
    
	[xml] $results = Web-Get $url
	
    $results.feed.entry | % { 
        write-host $_.author.name '- ' -nonewline -f DarkGreen
        write-host $_.title -f DarkGray
    }
}

function global:Post-Tweet([string] $username, [string] $password, [string] $message){
    trap [Exception]{
        Fail-Whale
        Print-Exception $_.Exception
        break
    }

    [void][Reflection.Assembly]::LoadWithPartialName("System.Web") | out-null
    
    $url = 'http://twitter.com/statuses/update.xml?status=' + [System.Web.HttpUtility]::UrlEncode($message)
     
    [net.httpWebRequest] $req = [net.webRequest]::create($url)
    $req.method = "POST"
    $req.Credentials = New-Object System.Net.NetworkCredential($username, $password)
    
    $reqst = $req.getRequestStream()
    $reqst.flush()
    $reqst.close()
    
    [net.httpWebResponse] $res = $req.getResponse()
    $resst = $res.getResponseStream()
    $sr = new-object IO.StreamReader($resst)
    $result = [xml] $sr.ReadToEnd()
    
    write-host "Success! " $result.status.created_at -f green 
}

function global:Twitter-Sign-on(){
    if(!$global:twitter_username){
        $global:twitter_username = Read-Host "Please enter your username"
    }
    if(!$global:twitter_password){
        $global:twitter_password = Read-Host "Please enter your password"
    }
}

function global:Twitter-Sign-out(){
    $global:twitter_username = $global:twitter_password = ''
}

function global:Get-Tweets([string] $username, [string] $password){
    $url = 'http://twitter.com/statuses/friends_timeline.xml?count={0}' -f 80
    
    [xml] $results = Web-Get $url
    
    $results.statuses.status | % { 
        write-host $_.user.screen_name '- ' -nonewline -f DarkGreen
        
        $text = $_.text.Replace("`n", " ").Replace("`t", " ").Replace("`r", " ")
            
        write-host $text
    }
}

function global:Web-Get([string] $url){
    trap [Exception]{
        Fail-Whale
        Print-Exception $_.Exception
        break
    }

    write-host "Connecting to URL " $url -f blue 

    $webclient = New-Object "System.Net.WebClient"
    $webclient.Credentials = New-Object System.Net.NetworkCredential($username, $password)

    return [xml] $webclient.DownloadString($url)
}

function global:Export-Tweets([string] $user){
    begin
    {
        function GetUserTweets ([string] $user){
            $pageIndex = 1
            $numTweets = 1
            while ($numTweets -ge 1)
            { 
                $tweetsPage = Get-Tweet-Page $user $pageIndex
                
                $numTweets = $tweetsPage.statuses.status.count
                
                if ($numTweets -ge 1)
                {
                    $tweetsPage.statuses.status | % { $_.text | write-output }
                }
                
                $pageIndex += 1
            }
        }
    }
    process{
        if ($_){
            GetUserTweets $_
        }
    }
    end{
        if ($user){
            GetUserTweets $user
        }
    }
}

function global:Get-Tweet-Page([string] $user, [string] $page){
    $url = "http://twitter.com/statuses/user_timeline/{0}.xml?page={1}" -f $user, $page
    
    return Web-Get $url
}

function global:Print-Exception([Exception] $exception){
    write-host $("TRAPPED: " + $exception.Message)
}

function global:Fail-Whale(){
    # ASCII art from: http://www.chris.com/ASCII/     
    
    write-host "               __   __" -f Blue
    write-host "              __ \ / __" -f Blue
    write-host "             /  \ | /  \" -f Blue
    write-host "                 \|/" -f Blue
    write-host "            _,.---v---._" -f DarkBlue
    write-host "   /\__/\  /            \" -f DarkBlue
    write-host "   \_  _/ /              \ " -f DarkBlue
    write-host "     \ \_|           @ __|" -f DarkBlue
    write-host "  hjw \                \_" -f DarkBlue
    write-host "   97  \     ,__/       /" -f DarkBlue
    write-host "     ~~~`~~~~~~~~~~~~~~/~~~~" -f DarkBlue
    write-host "         FAIL WHALE!!" -f Red
}