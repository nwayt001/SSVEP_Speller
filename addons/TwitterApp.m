classdef TwitterApp < Twitter_API
   
    properties
        creds
        twitterAPI
        twitterTarg
        browser_status
        browser_handle
        twitter_page_url = 'https://twitter.com/SSVEP_BCI';
    end
    
    methods
        % -----------------------------------------------------------------
        % Class constructor:
        
        function self = TwitterApp(creds)
            if nargin < 1
                % initialize twitter api with default credentials (Columbia
                % Postdoc account)
                creds=[];
                creds.ConsumerKey='okCmg791LMBK1zPk9lVbIbda9';
                creds.ConsumerSecret='PBh33IxhKoZGa1jRBBMxOSP9cruEz6CsYnKWXpILEzsucahq5p';
                creds.AccessToken='706928848269611012-HLDjIlTz1l8GMfVfRuEWTUZxhdKmR0L';
                creds.AccessTokenSecret='aUqc1i46gg2bVfPJ5J5EMRsnfckDcAD7GBctIgABrf4UN';
%                 creds=[];
%                 creds.ConsumerKey=' 7g7jQR0coYcFuHJ3osRGwWGAX';
%                 creds.ConsumerSecret='CJAjT1pUTd78tDC89zD4mvnkxxydW0Bhnrwt9w0aFqfuCQ3Kud';
%                 creds.AccessToken=' 323872754-gMxHy4dKhNokPqeJfFxr9d2SSFr3tYTxaPNOR7q0';
%                 creds.AccessTokenSecret='diZIrGSlPsSfkbFIwBOlZB0U0yRSEJI4ew4VyRk42uTp9';
            end
            
            % Initialize the twitter API
            self@Twitter_API(creds);
            self.creds = creds;
        end
        
        % -----------------------------------------------------------------
        
        function sendTweet(self, msg)
        % SENDTWEET takes an input message 'msg' and updates the status 
        % (tweet) of the user according to the credentials supplied
            updateStatus(self,msg);
        end
        
        function show_twitter(self)
        % SHOW_TWITTER starts matlabs browser window and navigates to the
        % default twitter page (columbia postdoc)
            [self.browser_status, self.browser_handle] = web(self.twitter_page_url,'-noaddressbox','-notoolbar');
        end
        
        function close_twitter(self)
        %CLOSE_TWITTER closes the twitter web browser page
            close(self.browser_handle);
        end
        
    end
    
end