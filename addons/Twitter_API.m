classdef Twitter_API < handle
% Interface-class to the Twitter REST API v1.1.
%
% CONTENT:
% 1. Overview.
% 2. A JSON parser.
% 3. Search API, Streaming API and output functions.
% 4. Obtaining Twitter credentials.
%
% ============
% 1. Overview
% ============
% Twitter_API is a MATLAB class for interaction with the Twitter platform via its REST API v1.1.
% Here are some examples of its usage: 
%
% tw = Twitter_API(credentials); % create a Twitter_API object (Twitter_API_obj) and supply user credentials.
%
% The credentials argument is a structure with the user account credentials. For details, see the
% PROPERTIES and OBTAINING TWITTER CREDENTIALS sections below.
%
% After valid credentials are set, Twitter_API_obj should be able to access the Twitter. E.g.:  
% 1. S = tw.search('matlab'); % search twitter.com for messages including the word 'matlab'.
% 2. S = tw.updateStatus('Hello, Twitter!'); % or twit something cooler.
% 3. S = tw.sampleStatuses(); % get a continuous stream of a random sample of all public statuses.
% 4. S = tw.userTimeline('screen_name', 'matlab'); % get recent messages posted by the user 'matlab';
% 5. S = tw.trendsAvailable(); % get place for which Twitter has trends available.
%
% --------
% METHODS
% --------
% Conceptually, Twitter_API methods are just wrapper functions around the main function which calls the
% twitter API. This API caller function, callTwitterAPI(), does the main job: 
% creates an HTTPS request, handles authentication and encoding, sends the request to and parses a
% response from the Twitter platform. It is not meant to be called directly but should be invoked
% from a wrapper function.  
%
% The wrapper functions provide an intuitive MATLAB-style interface for accessing the
% Twitter's API resources. For the complete description of the REST API v1.1, refer to the official
% documentation at https://dev.twitter.com/docs/api/1.1. 
% The API is quite extensive and Twitter_API doesn't cover it all. It includes most of the
% resources in the following sections: TIMELINES, STREAMING, TWEETS, SEARCH, FRIENDS & FOLLOWERS,
% USERS, PLACES & GEO, TRENDS, and HELP.
%
% For the summary of the Twitter_API's methods run the 'Twitter_API.API' command.
% For information on a particular function, type 'help Twitter_API.<function name>'.
%
% -----------
% PROPERTIES
% -----------
% - credentials - a structure containing credentials of a valid user account. 
%    It consists of 4 fields: .ConsumerKey, .ConsumerSecret, .AccessToken, .AccessTokenSecret. 
%    E.g.,
%     credentials.ConsumerKey = 'WuhMKJJXx0TzEtu435OXVA'
%     credentials.ConsumerSecret = '5ezt6zOG6dDWLZNzxUHsKJtUs52kmMtDqzV7nEjnhU'
%     credentials.AccessToken = '188321184-7iVtMvx3JVhwfdvJf5J2NKiuQzTz47UnQsFJnWlG'
%     credentials.AccessTokenSecret = 'idev6Hmq68EsVIQb3pP8nSeN9Rt629BJ4yPKlqlwZk'.
%    The fields are described in the section on OBTAINING TWITTER CREDENTIALS below.
%    This properties is private. It can be set either by a constructor, i.e., 
%      tw = Twitter_API(credentials);
%    or by invoking one of the following methods: 
%     tw.setCredentials(credentials);
%     tw.saveCredentials.
%
% - jsonParser - handle of a function that takes a string in JSON format, parses it and creates a
%                corresponding MATLAB structure. See the JSON PARSER section below.
%                Default, Twitter_API_obj.jsonParser = @ parse_json. 
%
% - outFcn     - handle of a user-defined output function which processes the retrieved statuses. 
%                To be used in particular in conjunction with the Streaming API. 
%                By default, no output function is specified: tw.outFcn = [].
%                However, if a Twitter_API_obj connects to the Twitter Streaming API and no output
%                function was specified the output function would be set to:
%                   Twitter_API_obj.outFcn = @ Twitter_API_obj.displayStatusText.
%
% - sampleSize - number of statuses to retrieve before terminating the connection to the Twitter
%                Streaming API. Has no effect on the methods connecting to the Search API.
%                Default, Twitter_API_obj.sampleSize = 1000, i.e., 1000 statuses will be retrieved.
%                If a permanent time-unlimited connection is desired, set sampleSize = inf.
% 
% - batchSize  - number of statuses to accumulate in a batch to process by an output function.
%                Has no effect on the methods connecting to the Search API.
%                Default, Twitter_API_obj.batchSize = 20.
%
% - data       - a structure to hold the results of processing of the retrieved statuses by an
%                output function. It comes with 2 predefined fields: 
%                 data.fh - holds a handle of a figure, where the results of the output function can
%                  be visualized.
%                 data.outFcnInitialized - a boolean variable facilitating a one-time initialization
%                  of the output function. See the 'Twitter_API.plotStatusLocation()' function for an
%                  example of its usage. 
%
% =================
% 2. A JSON PARSER
% =================
% Response from the Twitter platform represents a string in the "JSON" format. The Twitter_API class does
% not provide a method for processing JSON strings, but relies on a 3d party JSON parser, e.g., the
% parser by  Joel Feenstra available at MATLAB file exchange, "parse_json.m": 
% http://www.mathworks.co.uk/matlabcentral/fileexchange/20565-json-parser
%
% A desired JSON parser can be specified by assigning a handle of the parser function to the
% Twitter_API's property Twitter_API_obj.jsonParser. 
% By default, 
%    Twitter_API_obj.jsonParser = @ parse_json.
%
% NB: If no JSON parser is specified, Twitter_API's methods would return just plain strings in JSON
%     format. 
%
% ==================================================
% 3. SEARCH API, STREAMING API and OUTPUT FUNCTIONS
% ==================================================
% The Twitter API allows for two modes of searching and retrieving user statuses: REST API (aka
% Search API) and Streaming API. 
%
% Via the Search API, a client (i.e., a Twitter_API object) specifies a search query, sends it to the
% server and receives a response containing the PAST statuses satisfying the search criteria and
% being in a certain time window (ranging from a couple of days up to several weeks). After the
% response is sent, the connection between the server and the client is terminated.
%
% The Streaming API, on the contrary, allows for permanent connection to the Twitter platform,
% whereas a client becomes subscribed to a feed of NEW tweets matching some search criteria.
% Streaming API is convinient, if one is interested in continuous online monitoring of tweets, since
% it eliminates the overhead of establishing recurring connections to the Twitter.
%
% All but two Twitter_API methods implement interfaces for accessing the Search API. 
% The two methods connecting to the Streaming API are 'sampleStatuses()' and 'filterStatuses()'. 
% The former retrieves random samples of all public statuses, whereas the later method allow to
% follow tweets satisfying some search criteria. 
%
% In general, connection to the Twitter Streaming API would persist indefinitely long. In order to
% interrupt the connection, a user have to press <CTRL>-C. 
% Alternatively, Twitter_API can interrupt the connection automatically, after the desired number of
% tweets were retrieved. The property 'Twitter_API_obj.sampleSize' controls this number. By default, 
%    Twitter_API_obj.sampleSize = 1000.
% 
% NB: The sampleSize and batchSize (see below) properties do not have an effect on the methods using
% the Search API. 
%
% -----------------
% OUTPUT FUNCTIONS
% -----------------
% In most cases, it is unnecessary and practically infeasible to store all the streamed statuses.
% It is more reasonable to process them on fly to extract and save only the relevant information. To
% facilitate this, the Twitter_API class allows its users to provide a special function, the so called
% "ouput function", which job is to process the statuses as they are retrieved via the Streaming (or
% Search) API. 
% 
% A user can specify an output function by assigning a handle of the function to the Twitter_API property
% 'outFcn', i.e., 
%    tw = Twitter_API; tw.outFcn = @tweetingSummary.
% 
% An output function can a usual m-file, e.g., the "tweetingSummary.m" file provided with the
% Twitter_API. Alternatively, it can be implemented as a Twitter_API method. Several output functions are
% provided with the Twitter_API as its methods. See, the cell AUXILIARY OUTPUT FUNCTIONS in this file. 
%
% An output function must have two arguments, e.g., tweetingSummary(Twitter_API_obj, S), where
% Twitter_API_obj is the Twitter_API object itself, and S is a cell array of structures containing the
% retrieved statuses. The function doesn't have any output arguments. Instead, the results of the
% statuses analysis are stored in the special Twitter_API variable, Twitter_API_obj.data. This variable is a
% structure with two predefined fields: 'fh' and 'outFcnInitialized'. 'fh' stands for figure handle
% and is to be used to store the handle of the figure where the ouput function displays its results,
% see the 'Twitter_API.plotStatusLocation' function. The boolean variable 'outFcnInitialized' facilitates
% a one-time initialization of an output function. For an example of its usage, see the
% 'Twitter_API.plotStatusLocation()' or the "tweetingSummary.m" functions.
% 
% The statuses can be processed one by one as they are retrieved from the Twitter
% platform. It is more practical, however, to process the statuses in small batches. The
% Twitter_API property 'batchSize' controls the size of a batch of statuses to collect for
% processing by an output function. The default value of the batchSize is 20.
%
% By default, no output function is specified. However, if connecting to the Streaming API the
% default output function will be set to 
%    Twitter_API_obj.outFcn = @ Twitter_API_obj.displayStatusText, 
% which simply displays the text of a tweet in the command line.
% 
% =================================
% 4. OBTAINING TWITTER CREDENTIALS
% =================================
% Since API v1.1, access to all Twitter's resources requires an authorization with the credentials
% corresponidng to a valid user account. The credentials consist of four strings: Consumer key,
% Consumer secret, Access token, and Access token secret. The former two correspond to the
% application accessing twitter API (called the consumer), i.e., to this class. The latter two
% are used to identify a twitter user.
%
% The procedure of obtaining twitter credentials is described in the twitter documentation:
% https://dev.twitter.com/docs/auth/tokens-devtwittercom.
%
% Here is a summary of the steps:
%
% 1. Register Twitter_API in your twitter account. 
%    Go to the dev.twitter.com "My applications" page, either by navigating to
%    dev.twitter.com/apps, or hovering over your profile image in the top right hand corner of
%    the site and selecting "My applications". 
%
% 2. Click "Create new application" and follow the instructions. Enter something like, 
%     Name: Twitter_API MATLAB class; 
%     Description: MATLAB interface to twitter API. 
%     Website: http://www.mathworks.com/matlabcentral/fileexchange/34837
%    Upon creation, your application will be assigned the two Consumer keys.
%
% 3. Click "Create my access token" button at the bottom of the page, to obtain the two Access
%    tokens. 
%
% 4. At the "Settings" tab, change the "Access level" to "Read and write".
% 
% There are two options to use the obtained credentials with the Twitter_API.
% 1. Supply user credentials each time a Twitter_API object is created.
%    This can be done either at a constructor call, i.e., tw = Twitter_API(credentials),
%    or after an object is created without credentials, tw = Twitter_API(), with the
%    tw.setCredentials(credentials) function. The input argument "credentials" is a structure
%    with the four fields: .ConsumerKey, .ConsumerSecret, .AccessToken, and .AccessTokenSecret.
%
% 2. Save credentials to the MATLAB preferences database for persistent use.
%    This option is preferable if Twitter_API is used with a single user account only.
%    Create a Twitter_API object without credentials: tw = Twitter_API(). 
%    Call tw.saveCredentials() and copy and past the credentials into the corresponding fields
%    of the opened gui. 
%    The stored in this way credentials will be used each time a Twitter_API object is created
%    without specifying the credentials, i.e., tw = Twitter_API.

% v1.1.0 (c) 2012-13, Vladimir Bondarenko <http://sites.google.com/site/bondsite> 

    properties(Access = private)
        credentials = '';
        ownOutFcn = 0; % 1 - if the output function is a Twitter_API's method, 0 - if it is a user defined function. 
                       % This variable is set in the 'outFcn' listener "verifyOutFcn".
    end
    properties(SetObservable)
        jsonParser = @parse_json;  % handle to a JSON parser function.
        outFcn = [];  % handle to an output function (see the OUTPUT FUNCTION section in the help).
    end
    properties
        sampleSize = 1000;  % total number of tweets to retrieve via streaming API. 
                            % For indefinitely long streaming set 'sampleSize = inf'.
        batchSize = 20;     % number of tweets to accumulate via streaming API before processing 
                            % them by an output function. 
        
        % data is a structure aimed to be used in conjunction with the output function to store some
        % analysis data: 
        data = struct('fh',1,'outFcnInitialized',0); % fh stands for 'figure handle'.
    end
    properties(Access = private, Dependent = true)
        jsonParserStr;
        outFcnStr;
    end
%% Auxiliary functions    
    methods 
        function twtr = Twitter_API(creds)
        % Constructor of a Twitter_API object. 
        %
        % INPUT: (optional) 
        %  creds - a structure with user account's credentials. The fields:
        %          .ConsumerKey, .ConsumerSecret,
        %          .AccessToken, .AccessTokenSecret.
        % OUTPUT: Twitter_API object.
        % 
        % If credentials are not provided, Twitter_API() attempts to load them
        % from the MATLAB preferences: the group name is 'TwitterAuthentication, 
        % preference name 'AccessTokens'. If the corresponding
        % preference is not set, a warning is issued.
        %
        % For the information about obtaining twitter credentials, see Twitter_API description: 
        % help Twitter_API.
        
        switch nargin
            case 0
                % check if the preference exists:
                groupName = 'TwitterAuthentication';
                prefName  = 'AccessTokens';
                if ispref(groupName, prefName)
                    twtr.credentials = getpref(groupName, prefName);
                else % issue a warning:
                    warning('Twitter_API:CredentialsUnderfined',...
                           ['Twitter credentials were not set.\n',...
                            'Since API v1.1, the credentials must be specified.\n',...
                            'To set credentials use the setCredentials() function\n',...
                            'or save credentials to the MATLAB preferences database for\n',...
                            'persistent use using the saveCredentials() funciton.\n'...
                            'For details, type ''help Twitter_API''.']);
                end
            case 1
                % check input type:
                if ~isstruct(creds), error('Input argument must be a structure.'); end
                % check for the proper field names:
                inputFields = fieldnames(creds);
                credentialFields = {'ConsumerKey','ConsumerSecret',...
                                    'AccessToken','AccessTokenSecret'};
                for ii=1:length(credentialFields)
                    if sum(strcmpi(inputFields(ii),credentialFields))==0
                        error('Wrong field names for the credentials structure.');
                    end
                end
                % set credentials:
                twtr.credentials = creds;
                % check, if the entered credentials are valid:
                try
                    S = twtr.accountVerifyCredentials;
                catch
                    error('The supplied credentials are not valid.');
                end
        end
        % check for a JSON parser:
        if isempty(twtr.jsonParserStr)
            warning('Twitter_API:jsonParserUnspecified',...
                    ['No JSON parser specified.\n',...
                     'It is practical to use some parser, e.g., ''parse_json.m''.\n',...
                     'Otherwise, Twitter_API''s methods will return plain JSON strings.\n']);
        elseif ~exist(twtr.jsonParserStr,'file')
            warning('Twitter_API:jsonParserNotFound',...
                    ['The specified JSON parser, ' twtr.jsonParserStr ', was not found.\n',...
                     'Twitter_API''s methods will return plain JSON strings.\n']);
        end
        
        % set listeners:
        addlistener(twtr,'jsonParser','PostSet',@twtr.verifyJsonParser);
        addlistener(twtr,'outFcn','PostSet',@twtr.verifyOutFcn);
        
        end
        
        function setCredentials(twtr,creds)
        % Set user credentials.
        %
        % Usage: Twitter_API_obj.setCredentials(creds)
        % INPUT:  creds  -  a structure with user account's credentials. The fields:
        %                   .ConsumerKey, .ConsumerSecret,
        %                   .AccessToken, .AccessTokenSecret.
        %
        % OUTPUT: none.
        
        % parse input:
        if nargin~=2, error('Wrong number of input arguments.'); end
        if ~isstruct(creds), error('Input must be a structure.'); end
        % check for the proper field names:
        inputFields = fieldnames(creds);
        credentialFields = {'ConsumerKey','ConsumerSecret',...
                            'AccessToken','AccessTokenSecret'};
        for ii=1:length(credentialFields)
            if sum(strcmpi(inputFields(ii),credentialFields))==0
                error('Wrong field names for the credentials structure.');
            end
        end
        % set credentials:
        twtr.credentials = creds;
        % check, if the entered credentials are valid:
        S = twtr.accountVerifyCredentials;
        if isstruct(S)
            if strcmpi('error', fieldnames(S)), error('The supplied credentials are not valid.'); end
        else
            if strfind(lower(S),'error'), error('The supplied credentials are not valid.'); end
        end
        end
        
        function creds = getCredentials(twtr)
        % Return user credentials.
        %
        % Usage: creds = Twitter_API_obj.getCredentials;
        % 
        % INPUT: none.
        % OUTPUT: creds  - a structure with Twitter account's credentials. The fields:
        %                  .ConsumerKey, .ConsumerSecret, .AccessToken, .AccessTokenSecret.
        
            creds = twtr.credentials;
        end
        
        function saveCredentials(twtr)
        % GUI to set and save credentials to the MATLAB preferences.
        %
        % Usage: Twitter_API_obj.saveCredentials();
        %
        % INPUT: Enter Twitter credentials to the corresponding fields in the opened gui.
        %
        % The credentials will be saved to the MATLAB preferences under the group name 
        % 'TwitterAuthentication' and preference name 'AccessTokens', and will be used each
        % time a Twitter_API object is created without credentials.
        
        % Preference group and name:
        groupName = 'TwitterAuthentication';
        prefName  = 'AccessTokens';
        % Create a dialog box:
        dlgTitle = 'Specify Twitter credentials';
        promt = {'ConsumerKey','ConsumerSecret','AccessToken','AccessTokenSecret'};
        opts = struct('Resize','on','WindowStyle','normal');
        if ispref(groupName,prefName)
            defs = struct2cell( getpref(groupName,prefName) );
        else
            defs = {'','','',''};
        end
        answ = inputdlg(promt,dlgTitle,1,defs,opts);
        
        % Set the preference:
        if isempty(answ)
            return;
        else
            creds = cell2struct(answ,promt,1); 
            setpref(groupName,prefName,creds);
            % Set credentials:
            twtr.credentials = creds;
            % check, if the entered credentials are valid:
            S = twtr.accountVerifyCredentials;
            if isstruct(S)
                if strcmpi('error', fieldnames(S)), error('The credentials are not valid.'); end
            else
                if strfind(lower(S),'error'), error('The credentials are not valid.'); end
            end
        end
        end
        
        function C = parseTwitterResponse(twtr, s)
        % Convert the Twitter response from a java string to a MATLAB cell array.
        %
        % Twitter returns the statuses as strings in JSON format. If a Twitter_API user has provided a
        % parser function by setting the property 'jsonParser', the JSON strings would be processed
        % by the function. If a parser is not defined, a plain JSON string (in a cell array) is
        % returned.
        % 
        % Usage: C = parseTwitterResponse(s)
        % INPUT:
        %  s - a java string or string array object.
        % OUTPUT: 
        %  C - one of the two:
        %  1) MATLAB cell array of structures if parcing by a JSON parser was successful.
        %  2) cell array of strings, otherwise.
        
            ss = char(s); % convert java string to MATLAB string,
            if size(ss,1)>1, ss = cellstr(ss); end  % or cell array of strings.

            % Parse the JSON string:
            if exist(twtr.jsonParserStr,'file')
                % if ss is a cell array, transform it into a 1D string appropriate for parsing:
                if iscellstr(ss)
                    ss = [ '[' twtr.cell2list(ss) ']']; % convert the cell array into a comma-
                                                        % separated list and embrace it with [].
                end
                try
                    C = twtr.jsonParser(ss);
                catch ME
                    warning('Twitter_API:ParseJsonError',[twtr.jsonParser ' error.\n' ME.message]);
                    C = ss;
                end
            else
                C = ss;
            end
            % if C is a single structure, put it into a cell (for uniform post-processing)
            if isstruct(C)
                C = {C};
            end
        end
        
        function l = cell2list(~,c)
        % Convert a 1D cell array to a comma-separated list.
        %
        % Usage: l = Twitter_API_obj.cell2list(c);
        % INPUT: 
        %  c - a 1D cell array of strings or numbers;
        % OUTPUT:
        %  l - a string, representing a comma-separated list.
            
            % Check the input:
            if ~iscell(c) || min(size(c))~=1 
                error('The input argument must be a 1D cell array'); 
            end
            % Convert:
            if iscellstr(c)
                cc = strcat(c,','); % append comma to each element of the array.
                cc{end}(end) = '';  % remove the last comma.
                l = [cc{:}];        % concatenate the cell content into one string. 
            else
                % the cell array contains numbers:
                cc = num2str([c{:}]);
                l = regexprep(cc,'\s+',',');
            end
        end
        
        function val = get.jsonParserStr(twtr)
        % Return the name of the JSON parser function.
            if ~isempty(twtr.jsonParser)
                s1 = func2str(twtr.jsonParser);
                val = regexprep(s1,'@\(\w\)','');
            else
                val = '';
            end
        end

        function val = get.outFcnStr(twtr)
        % Return the name of the output function as a string.
            if ~isempty(twtr.outFcn)
                s1 = func2str(twtr.outFcn);
                val = regexprep(s1,'@?\([\w{}:]+\)','');
            else
                val = '';
            end
        end
        
        function verifyJsonParser(twtr,~,~)
        % verify the specified JSON parser.
        if isa(twtr.jsonParser,'function_handle') || isempty(twtr.jsonParser)            
            if isempty(twtr.jsonParserStr)
                warning('Twitter_API:jsonParserUnspecified',...
                        ['No JSON parser specified.\n',...
                         'It is practical to use some parser, e.g., ''parse_json.m''.\n',...
                         'Otherwise, Twitter_API''s methods will return plain JSON strings.\n']);
            elseif ~exist(twtr.jsonParserStr,'file')
                warning('Twitter_API:jsonParserNotFound',...
                        ['The specified JSON parser function, ' twtr.jsonParserStr ', was not found.\n',...
                         'Twitter_API''s methods will return plain JSON strings.\n']);
            end
        else
            twtr.jsonParser = [];
            error('Twitter_API:jsonParserWrongSetting',...
                  'The ''jsonParser'' must be either a function handle or an empty array.');
        end       
        end
        
        function verifyOutFcn(twtr,~,~)
        % verify the specified output function.
        
        if ~isa(twtr.outFcn,'function_handle') && ~isempty(twtr.outFcn)
            twtr.outFcn = [];  
            error('Twitter_API:outputFunctionWrongSetting',...
                  'The output function, ''outFcn'', must be either a function handle or an empty array.');
        elseif isempty(twtr.outFcn) 
            return; % STOP if the no output function specified.
        else
            % determine if the function is the Twitter_API's own method or a user-defined function:
            funcName = strsplit(twtr.outFcnStr,'.');
            if length(funcName)==2 && ismethod('Twitter_API',funcName{2})
                % output function is a Twitter_API's method:
                twtr.ownOutFcn = 1;
            elseif length(funcName)==1 && ~exist(funcName{1},'file')
                error('Twitter_API:outputFunctionNotFound',...
                      'The specified output function was not found.');
            else 
                % output function is user defined.
                twtr.ownOutFcn = 0;  
            end
        end
        end
            
    end
    
    
    methods(Static)
        function API()
        % Display the list of implemented calls to the Twitter API.
            fid = fopen('Twitter_API.m');
            tline = fgetl(fid);
            while ischar(tline)
                if ~isempty(regexpi(tline,'^%%')) && isempty(strfind(tline,'Auxiliary'))
                    disp(upper(tline));
                end
                if regexpi(tline,'^\s*function S =');
                    % extract the function name:
                    fname = regexpi(tline,'\s*function S = ([a-z_]+)\(\.*','tokens','once');
                    tab = blanks(25-length(fname{1}));
                    % get the first help line:
                    hline = regexprep(fgetl(fid),'^\s+%','');
                    fprintf([' ' fname{1} '()' tab hline '\n']);
                end
                tline = fgetl(fid);
            end
        end
    end
    
%% Methods interfacing Twitter API:            
    methods
%% Timelines
        function S = homeTimeline(twtr,varargin)
        % Returns a collection of the most recent statuses posted by the authenticating user 
        % and the user's they follow.
        %
        % Usage: S = Twitter_API_obj.homeTimeline();
        %        S = Twitter_API_obj.homeTimeline(parKey1, parVal1, parKey2, parVal2, ...);
        % INPUT:    
        % (optional) 
        %        parKey?, 
        %        parVal  - parameters Key/Value pairs. For the complete list, 
        %                  refer to "https://dev.twitter.com/docs/api/1.1/get/statuses/home_timeline".
        % OUTPUT: S      - response from the Twitter API: either a structure
        %                  (requires "parse_json.m" from the MATLAB file exchange), 
        %                  or a json string.
        % Examples:
        % tw = Twitter_API; S = tw.homeTimeline('include_entities','true','count',4);
        
            % Check for credentials:
            twtr.checkCredentials();
            % Parse the input:
            if mod(nargin,2) == 0, error('Wrong number of input arguments.'); end;
            if nargin == 1 
                params = '';
            else
                for ii=1:2:nargin-2
                    parKey = varargin{ii}; parVal = varargin{ii+1};
                    if ~ischar(parKey), error('Parameter Key must be a string.'); end
                    if isnumeric(parVal), parVal = num2str(parVal); end
                    params.(parKey) = parVal;
                end
            end
            % Call Twitter API:
            httpMethod = 'GET';
            url = 'https://api.twitter.com/1.1/statuses/home_timeline.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end
        
        function S = userTimeline(twtr,varargin)
        % Returns a collection of the most recent Tweets posted by the user indicated by the
        % 'screen_name' or 'user_id' parameters. 
        %
        % Usage: S = Twitter_API_obj.userTimeline('user_id', user_id) or
        %        S = Twitter_API_obj.userTimeline('screen_name', screen_name);
        %        S = Twitter_API_obj.userTimeline(..., parKey1, parVal1, parKey2, parVal2, ...);
        % INPUT:  Always specify either
        %        user_id     - a string specifying user ID or 
        %        screen_name - a string specifying user screen_name.
        % (optional) 
        %        parKey?, 
        %        parVal? - parameters Key/Value pairs. For the complete list, 
        %                  refer to "https://dev.twitter.com/docs/api/1.1/get/statuses/user_timeline".
        % OUTPUT: S      - response from the Twitter API: either a structure
        %                  (requires "parse_json.m" from the MATLAB file exchange), 
        %                  or a json string.
        % Examples:
        % 1. tw = Twitter_API; S = tw.userTimeline('screen_name','twitterapi');
        % 2. S = tw.userTimeline('screen_name','twitterapi','count',5,'include_entities','true')
            
            % Check for credentials:
            twtr.checkCredentials();
            % Parse input:
            if nargin < 3, error('Insufficient number of input arguments.'); end;
            if mod(nargin,2) == 0, error('Wrong number of input arguments.'); end;
            for ii=1:2:nargin-1                
                parKey = varargin{ii}; parVal = varargin{ii+1};
                if ~ischar(parKey), error('Parameter Key must be a string.'); end
                if isnumeric(parVal), parVal = num2str(parVal); end
                params.(parKey) = parVal;
            end
            % Call Twitter API:
            httpMethod = 'GET';
            url = 'https://api.twitter.com/1.1/statuses/user_timeline.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end
        
        function S = mentionsTimeline(twtr,varargin)
        % Returns the 20 most recent mentions (status containing @username) 
        % for the authenticating user.
        %
        % Usage: S = Twitter_API_obj.mentionsTimeline(parKey1, parVal1, parKey2, parVal2, ...);
        % INPUT: 
        % (optional) 
        %        parKey?, 
        %        parVal? - parameters Key/Value pairs. For the complete list, 
        %                  refer to "https://dev.twitter.com/docs/api/1.1/get/statuses/mentions".
        % OUTPUT: S      - response from the Twitter API: either a structure
        %                  (requires "parse_json.m" from the MATLAB file exchange), 
        %                  or a json string.
        % Examples:
        % tw = Twitter_API; S = tw.mentionsTimeline('include_entities','true');
        
            % Check for credentials:
            twtr.checkCredentials();
            % Parse input:
            if nargin < 1, error('Insufficient number of input arguments.'); end;
            if mod(nargin,2) == 0, error('Wrong number of input arguments.'); end;
            if nargin == 1 
                params = '';
            else
                for ii=1:2:nargin-1                
                    parKey = varargin{ii}; parVal = varargin{ii+1};
                    if ~ischar(parKey), error('Parameter Key must be a string.'); end
                    if isnumeric(parVal), parVal = num2str(parVal); end
                    params.(parKey) = parVal;
                end
            end
            % Call twitter API:
            httpMethod = 'GET';
            url = 'https://api.twitter.com/1.1/statuses/mentions_timeline.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end

        function S = retweetsOfMe(twtr,varargin)
        % Returns the most recent tweets of the authenticated user that have been retweeted
        % by others. 
        %
        % Usage: S = Twitter_API_obj.retweetsOfMe();
        %        S = Twitter_API_obj.retweetsOfMe(parKey1, parVal1, parKey2, parVal2, ...);
        % INPUT: 
        % (optional) 
        %        parKey?, 
        %        parVal? - parameters Key/Value pairs. For the complete list, 
        %                  refer to "https://dev.twitter.com/docs/api/1.1/get/statuses/retweets_of_me".
        % OUTPUT: S      - response from the Twitter API: either a structure
        %                  (requires a JSON parser), or a plain JSON string.
        % Examples:
        % tw = Twitter_API; S = tw.retweetsOfMe('include_entities','true');
        
            % Check for credentials:
            twtr.checkCredentials();
            % Parse input:
            if nargin < 1, error('Insufficient number of input arguments.'); end;
            if mod(nargin,2) == 0, error('Wrong number of input arguments.'); end;
            if nargin == 1 
                params = '';
            else
                for ii=1:2:nargin-1                
                    parKey = varargin{ii}; parVal = varargin{ii+1};
                    if ~ischar(parKey), error('Parameter Key must be a string.'); end
                    if isnumeric(parVal), parVal = num2str(parVal); end
                    params.(parKey) = parVal;
                end
            end
            % Call twitter API:
            httpMethod = 'GET';
            url = 'https://api.twitter.com/1.1/statuses/retweets_of_me.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end
        
%% Streaming
        function S = sampleStatuses(twtr,varargin)
        % Returns a small random sample of all public statuses via streaming API.
        % (Replaces the publicTimeline() call the the API v1.0)
        %
        % The sampleStatuses() is an interface to the Twitter Stream API, which allows for
        % persisting connection to the Twitter platform and continuous retrieving of public
        % statuses. 
        %
        % Usage: S = Twitter_API_obj.sampleStatuses();
        %             S = Twitter_API_obj.sampleStatuses(parKey1, parVal1, parKey2, parVal2, ...);
        % INPUT:    
        % (optional) 
        %        parKey?, 
        %        parVal? - parameters Key/Value pairs. For the complete list, 
        %                       refer to "https://dev.twitter.com/docs/api/1.1/get/statuses/sample".
        % OUTPUT: S   - the last batch of responses from the Twitter API: either a structure
        %                       (requires "parse_json.m" from the MATLAB file exchange), 
        %                       or a json string. The size of S is determined by the property
        %                       'batchSize'. By default, batchSize = 20.
        %
        % Examples:
        % Retrieve 1000 tweets, display their text in the command line, and return the last 100 of
        % them. 
        % tw = Twitter_API; tw.sampleSize = 1000; tw.batchSize = 100; S = tw.sampleStatuses;
        
            % Parse input:
            if mod(nargin,2) == 0, error('Wrong number of input arguments.'); end;
            if nargin == 1 
                params = '';
            else
                for ii=1:2:nargin-2
                    parKey = varargin{ii}; parVal = varargin{ii+1};
                    if ~ischar(parKey), error('Parameter Key must be a string.'); end
                    if isnumeric(parVal), parVal = num2str(parVal); end
                    params.(parKey) = parVal;
                end
            end
            % Set the output function:
            if isempty(twtr.outFcn)   % if the outFcn isn't set use the default one
                twtr.outFcn = @ twtr.displayStatusText;
                % issue a warning:
                warning('Twitter_API:setDefaultOutputFunction',...
                'The output function was set to the default one: ''Twitter_API_obj.displayStatusText''.');
            end
            twtr.data.outFcnInitialized = 0;
            % Call Twitter API:
            httpMethod = 'GET';
            url = 'https://stream.twitter.com/1.1/statuses/sample.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end
        
        function S = filterStatuses(twtr, varargin)
        % Returns public statuses that match one or more filter predicates.
        %
        % Usage: S = Twitter_API_obj.filterStatuses(parKey1, parVal1, parKey2, parVal2, ...);
        % INPUT:    
        % At least one predicate parameter ('follow', 'locations', or 'track') must be specified.
        %
        %        parKey?, 
        %        parVal? - parameters Key/Value pairs. For the complete list, refer to 
        %                  "https://dev.twitter.com/docs/api/1.1/post/statuses/filter".
        % OUTPUT: S      - the last batch of responses from the Twitter API: either a structure
        %                  (requires "parse_json.m" from the MATLAB file exchange), 
        %                  or a json string. The size of S is determined by the property
        %                  'batchSize'. By default, batchSize = 20.
        %
        % Examples: (press CTRL+C to stop streaming)
        % tw = Twitter_API; tw.sampleSize = inf; tw.batchSize = 1; S = tw.filterStatuses('track','job');
        
            % Parse input:
            if mod(nargin,2) == 0, error('Wrong number of input arguments.'); end;
            if nargin == 1 
                error('At least one predicate parameter (''follow'', ''locations'', or ''track'') must be specified.');
            else
                for ii=1:2:nargin-2
                    parKey = varargin{ii}; parVal = varargin{ii+1};
                    if ~ischar(parKey), error('Parameter Key must be a string.'); end
                    if isnumeric(parVal), parVal = num2str(parVal); end
                    params.(parKey) = parVal;
                end
            end
            % Set the output function:
            if isempty(twtr.outFcn)   % if the outFcn isn't set, use the default one:
                warning('Twitter_API:setDefaultOutputFunction',...
                'The output function was set to the default one: ''Twitter_API_obj.displayStatusText''.');
                twtr.outFcn = @ twtr.displayStatusText;
            end
            twtr.data.outFcnInitialized = 0;
            % Call Twitter API:
            httpMethod = 'POST';
            url = 'https://stream.twitter.com/1.1/statuses/filter.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        
        end
%% Tweets
        function S = updateStatus(twtr,status,varargin)
        % Update the authenticating user's status (twit). 
        %
        % Usage: S = Twitter_API_obj.updateStatus(status);
        %        S = Twitter_API_obj.updateStatus(status, parKey1, parVal1, parKey2, parVal2, ...);
        % INPUT: status  - the status string;
        % (optional) 
        %        parKey?, 
        %        parVal? - parameters Key/Value pairs. For the complete list, 
        %                  refer to "https://dev.twitter.com/docs/api/1.1/post/statuses/update".
        % OUTPUT: S      - response from the Twitter API: either a structure
        %                  (requires a JSON parser), or a plain JSON string.
        % Examples:
        % tw = Twitter_API; S = tw.updateStatus('hello twitter!','include_entities','true');
        
            % Check for credentials:
            twtr.checkCredentials();
            % Parse input:
            if nargin < 2, error('Insufficient number of input arguments.'); end;
            if mod(nargin,2) == 1, error('Wrong number of input arguments.'); end;
            params.status = status;
            for ii=1:2:nargin-2
                parKey = varargin{ii}; parVal = varargin{ii+1};
                if ~ischar(parKey), error('Parameter Key must be a string.'); end
                if isnumeric(parVal), parVal = num2str(parVal); end
                params.(parKey) = parVal;
            end
            % Call Twitter API:
            httpMethod = 'POST';
            url = 'https://api.twitter.com/1.1/statuses/update.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end        
        
        function S = retweets(twtr,id,varargin)
        % Returns up to 100 of the first retweets of a given tweet.
        %
        % Usage: S = Twitter_API_obj.retweets(id);
        %        S = Twitter_API_obj.retweets(id, parKey1, parVal1, parKey2, parVal2, ...);
        % INPUT: id      - a string, specifying the ID of the desired status;
        % (optional) 
        %        parKey?, 
        %        parVal? - parameters Key/Value pairs. For the complete list, 
        %                  refer to "https://dev.twitter.com/docs/api/1.1/get/statuses/retweets/%3Aid".
        % OUTPUT: S      - response from the Twitter API: either a structure
        %                  (requires a JSON parser), or a plain JSON string.
        % Examples:
        % 1. tw = Twitter_API; S = tw.retweets('21947795900469248');
        % 2. S = tw.retweets('21947795900469248','count',10);
        
            % Check for credentials:
            twtr.checkCredentials();
            % Parse input:
            if nargin < 2, error('Insufficient number of input arguments.'); end;
            if mod(nargin,2) == 1, error('Wrong number of input arguments.'); end;
            if ~ischar(id), error('The "id" argument must be a string.'); end;
            if nargin == 2
                params = '';
            else
                for ii=1:2:nargin-2
                    parKey = varargin{ii}; parVal = varargin{ii+1};
                    if ~ischar(parKey), error('Parameter Key must be a string.'); end
                    if isnumeric(parVal), parVal = num2str(parVal); end
                    params.(parKey) = parVal;
                end
            end
            % Call Twitter API:
            httpMethod = 'GET';
            url = ['https://api.twitter.com/1.1/statuses/retweets/' id '.json'];
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end
        
        function S = showStatus(twtr,id,varargin)
        % Returns a single status, specified by the id parameter below.
        %
        % Usage: S = Twitter_API_obj.showStatus(id);
        %        S = Twitter_API_obj.showStatus(id, parKey1, parVal1, parKey2, parVal2, ...);
        % INPUT: id      - a string, specifying the ID of the desired status;
        % (optional) 
        %        parKey?, 
        %        parVal? - parameters Key/Value pairs. For the complete list, 
        %                  refer to "https://dev.twitter.com/docs/api/1.1/get/statuses/show/%3Aid".
        % OUTPUT: S      - response from the Twitter API: either a structure
        %                  (requires a JSON parser), or a plain JSON string.
        % Examples:
        % 1. tw = Twitter_API; S = tw.showStatus('159462956281769985');
        % 2. S = tw.showStatus('159462956281769985','trim_user','true');
        
            % Check for credentials:
            twtr.checkCredentials();
            % Parse input:
            if nargin < 2, error('Insufficient number of input arguments.'); end;
            if mod(nargin,2) == 1, error('Wrong number of input arguments.'); end;
            if ~ischar(id), error('The "id" argument must be a string.'); end;
            if nargin == 2
                params.id = id;
            else
                for ii=1:2:nargin-2
                    parKey = varargin{ii}; parVal = varargin{ii+1};
                    if ~ischar(parKey), error('Parameter Key must be a string.'); end
                    if isnumeric(parVal), parVal = num2str(parVal); end
                    params.(parKey) = parVal;
                end
            end
            % Call Twitter API:
            httpMethod = 'GET';
            url = 'https://api.twitter.com/1.1/statuses/show.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end
        
        function S = destroyStatus(twtr,id,varargin)
        % Destroys the status specified by the required ID parameter.
        %
        % Usage: S = Twitter_API_obj.destroyStatus(id);
        %        S = Twitter_API_obj.destroyStatus(id, parKey1, parVal1, parKey2, parVal2, ...);
        % INPUT: id      - a string, specifying the ID of the desired status;
        % (optional) 
        %        parKey?, 
        %        parVal? - parameters Key/Value pairs. For the complete list, 
        %                  refer to "https://dev.twitter.com/docs/api/1.1/post/statuses/destroy/%3Aid".
        % OUTPUT: S      - destroyed status: either a structure
        %                  (requires a JSON parser), or a plain JSON string.
        % Examples:
        % 1. tw = Twitter_API; S = tw.destroyStatus('158310427602857984');
        % 2. S = tw.destroyStatus('158310427602857984','include_entities','true');
        
            % Check for credentials:
            twtr.checkCredentials();
            % Parse input:
            if nargin < 2, error('Insufficient number of input arguments.'); end;
            if mod(nargin,2) == 1, error('Wrong number of input arguments.'); end;
            if ~ischar(id), error('The "id" argument must be a string.'); end;
            if nargin == 2
                params = '';
            else
                for ii=1:2:nargin-2
                    parKey = varargin{ii}; parVal = varargin{ii+1};
                    if ~ischar(parKey), error('Parameter Key must be a string.'); end
                    if isnumeric(parVal), parVal = num2str(parVal); end
                    params.(parKey) = parVal;
                end
            end
            % Call Twitter API:
            httpMethod = 'POST';
            url = ['https://api.twitter.com/1.1/statuses/destroy/' id '.json'];
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end        
        
        function S = retweetStatus(twtr,id,varargin)
        % Retweets a tweet specified by the required ID parameter.
        %
        % Usage: S = Twitter_API_obj.retweetStatus(id);
        %        S = Twitter_API_obj.retweetStatus(id, parKey1, parVal1, parKey2, parVal2, ...);
        % INPUT: id      - a string, specifying the ID of the desired status;
        % (optional) 
        %        parKey?, 
        %        parVal? - parameters Key/Value pairs. For the complete list, 
        %                  refer to "https://dev.twitter.com/docs/api/1.1/post/statuses/retweet/%3Aid".
        % OUTPUT: S      - the original tweet: either a structure
        %                  (requires a JSON parser), or a plain JSON string.
        % Examples:
        % 1. tw = Twitter_API; S = tw.destroyStatus('158310427602857984');
        % 2. S = tw.destroyStatus('158310427602857984','trim_user','true');
        
            % Check for credentials:
            twtr.checkCredentials();
            % Parse input:
            if nargin < 2, error('Insufficient number of input arguments.'); end;
            if mod(nargin,2) == 1, error('Wrong number of input arguments.'); end;
            if ~ischar(id), error('The "id" argument must be a string.'); end;
            if nargin == 2
                params = '';
            else
                for ii=1:2:nargin-2
                    parKey = varargin{ii}; parVal = varargin{ii+1};
                    if ~ischar(parKey), error('Parameter Key must be a string.'); end
                    if isnumeric(parVal), parVal = num2str(parVal); end
                    params.(parKey) = parVal;
                end
            end
            % Call Twitter API:
            httpMethod = 'POST';
            url = ['https://api.twitter.com/1.1/statuses/retweet/' id '.json'];
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end        
        
        function S = retweeters(twtr,id,varargin)
        % Returns a collection of up to 100 ids of users who retweeted the specified status.
        %
        % Usage: S = Twitter_API_obj.retweeters(id);
        %        S = Twitter_API_obj.retweeters(id, parKey1, parVal1, parKey2, parVal2, ...);
        % INPUT: id      - a string, specifying the ID of the desired status;
        % (optional) 
        %        parKey?, 
        %        parVal? - parameters Key/Value pairs. For the complete list, 
        %                  refer to "https://dev.twitter.com/docs/api/1.1/get/statuses/retweeters/ids".
        % OUTPUT: S      - response from the Twitter API: either a structure (requires a JSON
        %                  parser), or a plain JSON string. 
        % Examples:
        % 1. tw = Twitter_API; S = tw.retweeters('21947795900469248');
        % 2. S = tw.retweeters('21947795900469248','stringify_ids','true','count',100);
        
            % Check for credentials:
            twtr.checkCredentials();
            % Parse input:
            if nargin < 2, error('Insufficient number of input arguments.'); end;
            if mod(nargin,2) == 1, error('Wrong number of input arguments.'); end;
            if ~ischar(id), error('The "id" argument must be a string.'); end;
            if nargin == 2
                params.id = id;
            else
                for ii=1:2:nargin-2
                    parKey = varargin{ii}; parVal = varargin{ii+1};
                    if ~ischar(parKey), error('Parameter Key must be a string.'); end
                    if isnumeric(parVal), parVal = num2str(parVal); end
                    params.(parKey) = parVal;
                end
            end
            % Call Twitter API:
            httpMethod = 'GET';
            url = 'https://api.twitter.com/version/statuses/retweeters/ids.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end        
                    
%% Search
        function S = search(twtr,query,varargin)
        % Search twitter.
        %
        % Usage: S = Twitter_API_obj.search(query);
        %        S = Twitter_API_obj.search(query, parKey1, parVal1, parKey2, parVal2, ...);
        % INPUT: query   - the query string;
        % (optional) 
        %        parKey?, 
        %        parVal? - parameters Key/Value pairs. For the complete list, 
        %                  refer to "https://dev.twitter.com/docs/api/1.1/get/search/tweets".
        % OUTPUT: S      - response from the Twitter API: either a structure
        %                  (requires a JSON parser, or a plain json string.
        % Examples:
        % tw = Twitter_API; S = tw.search('matlab','include_entities','true');
        
            % Parse input:
            if nargin < 2, error('Insufficient number of input arguments.'); end;
            if mod(nargin,2) == 1, error('Wrong number of input arguments.'); end;
            params.q = query;
            for ii=1:2:nargin-2
                parKey = varargin{ii}; parVal = varargin{ii+1};
                if ~ischar(parKey), error('Parameter Key must be a string.'); end
                if isnumeric(parVal), parVal = num2str(parVal); end
                params.(parKey) = parVal;
            end
            % Call Twitter API:
            httpMethod = 'GET';
            url = 'https://api.twitter.com/1.1/search/tweets.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end
        
%% Friends & Followers
        function S = friendsIds(twtr,varargin)
        % Returns an array of numeric IDs for every user the specified user is following.
        %
        % Usage: S = Twitter_API_obj.friendsIds('user_id', user_id) or
        %        S = Twitter_API_obj.friendsIds('screen_name', screen_name);
        %        S = Twitter_API_obj.friendsIds(..., parKey1, parVal1, parKey2, parVal2, ...);
        % INPUT:  Specify either
        %        user_id     - a string specifying user ID or 
        %        screen_name - a string specifying user screen_name.
        % (optional) 
        %        parKey?, 
        %        parVal? - parameters Key/Value pairs. For the complete list, 
        %                  refer to "https://dev.twitter.com/docs/api/1.1/get/friends/ids".
        % OUTPUT: S      - response from the Twitter API: either a structure
        %                  (requires a JSON parser), or a plain JSON string.
        % Examples:
        % 1. tw = Twitter_API; S = tw.friendsIds('screen_name','twitterapi');
        % 2. S = tw.friendsIds('screen_name','twitterapi','cursor',-1);
            
            % Check for credentials:
            twtr.checkCredentials();
            % Parse input:
            if nargin < 3, error('Insufficient number of input arguments.'); end;
            if mod(nargin,2) == 0, error('Wrong number of input arguments.'); end;
            for ii=1:2:nargin-1                
                parKey = varargin{ii}; parVal = varargin{ii+1};
                if ~ischar(parKey), error('Parameter Key must be a string.'); end
                if isnumeric(parVal), parVal = num2str(parVal); end
                params.(parKey) = parVal;
            end
            % Call Twitter API:
            httpMethod = 'GET';
            url = 'https://api.twitter.com/1.1/friends/ids.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end
        
        function S = followersIds(twtr,varargin)
        % Returns an array of numeric IDs for every user following the specified user.
        %
        % Usage: S = Twitter_API_obj.followersIds('user_id', user_id) or
        %        S = Twitter_API_obj.followersIds('screen_name', screen_name);
        %        S = Twitter_API_obj.followersIds(..., parKey1, parVal1, parKey2, parVal2, ...);
        % INPUT:  Specify either
        %        user_id     - a string specifying user ID or 
        %        screen_name - a string specifying user screen_name.
        % (optional) 
        %        parKey?, 
        %        parVal? - parameters Key/Value pairs. For the complete list, 
        %                  refer to "https://dev.twitter.com/docs/api/1.1/get/followers/ids".
        % OUTPUT: S      - response from the Twitter API: either a structure
        %                  (requires a JSON parser), or a plain JSON string.
        % Examples:
        % 1. tw = Twitter_API; S = tw.followersIds('screen_name','twitterapi');
        % 2. S = tw.followersIds('screen_name','twitterapi','cursor',-1);
            
            % Check for credentials:
            twtr.checkCredentials();
            % Parse input:
            if nargin < 3, error('Insufficient number of input arguments.'); end;
            if mod(nargin,2) == 0, error('Wrong number of input arguments.'); end;
            for ii=1:2:nargin-1                
                parKey = varargin{ii}; parVal = varargin{ii+1};
                if ~ischar(parKey), error('Parameter Key must be a string.'); end
                if isnumeric(parVal), parVal = num2str(parVal); end
                params.(parKey) = parVal;
            end
            % Call Twitter API:
            httpMethod = 'GET';
            url = 'https://api.twitter.com/1.1/followers/ids.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end
        
        function S = friendshipsLookup(twtr,varargin)
        % Returns the relationship of the authenticating user to a list of up to 100
        % screen_names or user_ids provided. 
        %
        % Usage: S = Twitter_API_obj.friendshipsLookup('user_id', {user_id1, user_id2,...}) or
        %        S = Twitter_API_obj.friendshipsLookup('screen_name', {screen_name1, screen_name2,...});
        % INPUT:  Specify either
        %        {user_id1,user_id2,..}           - a cell array containing a list of user IDs
        %                                           (either as numbers or strings) 
        %               or 
        %        {screen_name1,screen_name2,...}  - their screen names (up to 100).
        %  For the detailed description of the input parameters,  refer to
        %  "https://dev.twitter.com/docs/api/1.1/get/friendships/lookup". 
        %
        % OUTPUT: S      - response from the Twitter API: either a structure
        %                  (requires a JSON parser, or a plain JSON string.
        % Examples:
        % tw = Twitter_API; S = tw.friendshipsLookup('screen_name',{'twitterapi','twitter','matlab'});
            
            % Check for credentials:
            twtr.checkCredentials();
            % Parse input:
            if nargin ~= 3, error('Wrong number of input arguments.'); end;
            parKey = varargin{1};
            if ~ischar(parKey), error('The Key parameter must be a string.'); end
            parVal = varargin{2};
            if ~iscell(parVal), error('The Value parameter must be a cell array.'); end
            if length(parVal) > 100, error('The list is too long. 100 is the maximum length.'); end
            % Convert the cell array to a comma separated list:
            params.(parKey) = twtr.cell2list(parVal);
                
            % Call Twitter API:
            httpMethod = 'GET';
            url = 'https://api.twitter.com/1.1/friendships/lookup.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end
       
        function S = friendshipsCreate(twtr,varargin)
        % Allows the authenticating users to follow the specified user.
        %
        % Usage: S = Twitter_API_obj.friendshipsCreate('user_id', user_id) or
        %        S = Twitter_API_obj.friendshipsCreate('screen_name', screen_name);
        %        S = Twitter_API_obj.friendshipsCreate(..., 'follow', follow_val);
        % INPUT:  Specify either
        %        user_id     - a string/number specifying user ID or 
        %        screen_name - a string specifying user screen_name.
        % (optional) 
        %        follow_val  - either 'true' or 'false'. 
        %                      Enable notifications for the target user.
        % 
        % OUTPUT: S      - response from the Twitter API: either a structure
        %                  (requires a JSON parser), or a plain JSON string.
        %
        % For more information, refer to "https://dev.twitter.com/docs/api/1.1/post/friendships/create".
        %
        % Examples:
        % tw = Twitter_API; S = tw.friendshipsCreate('screen_name','matlab','follow','true');
            
            % Check for credentials:
            twtr.checkCredentials();
            % Parse input:
            if nargin < 3, error('Insufficient number of input arguments.'); end;
            if mod(nargin,2) == 0, error('Wrong number of input arguments.'); end;
            for ii=1:2:nargin-1                
                parKey = varargin{ii}; parVal = varargin{ii+1};
                if ~ischar(parKey), error('Parameter Key must be a string.'); end
                if isnumeric(parVal), parVal = num2str(parVal); end
                params.(parKey) = parVal;
            end
            % Call Twitter API:
            httpMethod = 'POST';
            url = 'https://api.twitter.com/1.1/friendships/create.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end
        
        function S = friendshipsDestroy(twtr,varargin)
        % Allows the authenticating users to unfollow the specified user.
        %
        % Usage: S = Twitter_API_obj.friendshipsDestroy('user_id', user_id) or
        %        S = Twitter_API_obj.friendshipsDestroy('screen_name', screen_name);
        %        S = Twitter_API_obj.friendshipsCreate(..., parKey1, parVal1,...);
        % INPUT:  Specify either
        %        user_id     - a string/number specifying user ID or 
        %        screen_name - a string specifying user screen_name.
        % (optional) 
        %        parKey/parVal  - paramter Key/Value pairs. Must be strings.                     
        % 
        % OUTPUT: S      - response from the Twitter API: either a structure
        %                  (requires a JSON parser), or a plain JSON string.
        %
        % For more information, refer to "https://dev.twitter.com/docs/api/1.1/post/friendships/destroy".
        %
        % Examples:
        % tw = Twitter_API; S = tw.friendshipsDestroy('screen_name','twitter');
            
            % Check for credentials:
            twtr.checkCredentials();
            % Parse input:
            if nargin < 3, error('Insufficient number of input arguments.'); end;
            if mod(nargin,2) == 0, error('Wrong number of input arguments.'); end;
            for ii=1:2:nargin-1                
                parKey = varargin{ii}; parVal = varargin{ii+1};
                if ~ischar(parKey), error('Parameter Key must be a string.'); end
                if isnumeric(parVal), parVal = num2str(parVal); end
                params.(parKey) = parVal;
            end
            % Call Twitter API:
            httpMethod = 'POST';
            url = 'https://api.twitter.com/1.1/friendships/destroy.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end
        
        function S = friendshipsShow(twtr,varargin)
        % Returns detailed information about the relationship between two arbitrary users.
        %
        % Usage: S = Twitter_API_obj.friendshipsShow('source_id', source_id, 'target_id, target_id) or
        %        S = Twitter_API_obj.friendshipsShow('source_screen_name', source_screen_name,... 
        %                                        'target_screen_name', target_screen_name);
        %        S = Twitter_API_obj.friendshipsShow(..., parKey1, parVal1, parKey2, parVal2, ...);
        % INPUT:  Specify either
        %        {source,target}_id - strings/numbers specifying IDs of subject and target users or 
        %        {source,target}_screen_name - their names.
        %
        %  For more information refer to "https://dev.twitter.com/docs/api/1.1/get/friendships/show".
        % OUTPUT: S      - Twitter API response: either a structure
        %                  (requires a JSON parser), or a plain JSON string.
        % Examples:
        % tw = Twitter_API; 
        % S = tw.friendshipsShow('source_screen_name','twitter','target_screen_name','twitterapi');
            
            % Check for credentials:
            twtr.checkCredentials();
            % Parse input:
            if nargin < 5, error('Insufficient number of input arguments.'); end;
            if mod(nargin,2) == 0, error('Wrong number of input arguments.'); end;
            for ii=1:2:nargin-1                
                parKey = varargin{ii}; parVal = varargin{ii+1};
                if ~ischar(parKey), error('Parameter Key must be a string.'); end
                if isnumeric(parVal), parVal = num2str(parVal); end
                params.(parKey) = parVal;
            end
            % Call Twitter API:
            httpMethod = 'GET';
            url = 'https://api.twitter.com/1.1/friendships/show.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end        
        
%% Users
        function S = usersLookup(twtr,varargin)
        % Return up to 100 users worth of extended information, specified by either ID, 
        % screen name, or combination of the two.
        %
        % Usage: S = Twitter_API_obj.usersLookup('user_id', {user_id1, user_id2,...}) or
        %        S = Twitter_API_obj.usersLookup('screen_name', {screen_name1, screen_name2,...});
        % INPUT: (optional)
        %        {user_id1,user_id2,..}           - a cell array containing a list of user IDs,
        %        {screen_name1,screen_name2,...}  - or user screen names (up to 100).
        %        'include_entities'               - a string: either 'true' or 'false'.
        %
        % OUTPUT: S      - response from the Twitter API: either a structure
        %                  (requires a JSON parser, or a plain JSON string.
        %
        % For more information, refer to "https://dev.twitter.com/docs/api/1.1/get/users/lookup".
        %
        % Examples:
        % tw = Twitter_API; 
        % S = tw.usersLookup('screen_name',{'twitterapi','twitter'},'include_entities','true');
            
            % Check for credentials:
            twtr.checkCredentials();
            % Parse input:
            if nargin < 3, error('Wrong number of input arguments.'); end;
            for ii=1:2:nargin-1
                parKey = varargin{ii};
                if ~ischar(parKey), error('The Key parameter must be a string.'); end
                if sum(strcmpi(parKey,{'user_id','screen_name'}))
                    parVal = varargin{ii+1};
                    if ~iscell(parVal), error('The Value parameter must be a cell array.'); end
                    if length(parVal) > 100, error('The list is too long.'); end
                    % Convert cell array to a comma separated list:
                    params.(parKey) = twtr.cell2list(parVal); 
                elseif strcmpi(parKey,'include_entities')
                    parVal = varargin{ii+1};
                    if ~ischar(parVal), error('Include_entities parameter must be a string.'); end
                    if sum(strcmpi(parVal,{'true','false'})) == 0
                        error('Include_entities parameter must be either ''true'' or ''false''');
                    end
                    params.(parKey) = parVal;
                end
            end
            % Call Twitter API:
            httpMethod = 'GET';
            url = 'https://api.twitter.com/1.1/users/lookup.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end

        function S = usersShow(twtr,varargin)
        % Returns extended information about a given user.
        %
        % Usage: S = Twitter_API_obj.usersShow('user_id', user_id) or
        %        S = Twitter_API_obj.usersShow('screen_name', screen_name);
        %        S = Twitter_API_obj.usersShow(..., parKey1, parVal1,...);
        % INPUT:  Specify either
        %        user_id     - a string/number specifying user ID or 
        %        screen_name - a string specifying user screen_name.
        % (optional) 
        %        parKey/parVal  - paramter Key/Value pairs. Must be strings.                     
        % 
        % OUTPUT: S      - response from the Twitter API: either a structure
        %                  (requires a JSON parser, or a plain JSON string.
        %
        % For more information, refer to "https://dev.twitter.com/docs/api/1.1/get/users/show".
        %
        % Examples:
        % tw = Twitter_API; S = tw.usersShow('screen_name','matlab');
            
            % Check for credentials:
            twtr.checkCredentials();
            % Parse input:
            if nargin < 3, error('Insufficient number of input arguments.'); end;
            if mod(nargin,2) == 0, error('Wrong number of input arguments.'); end;
            for ii=1:2:nargin-1                
                parKey = varargin{ii}; parVal = varargin{ii+1};
                if ~ischar(parKey), error('Parameter Key must be a string.'); end
                if isnumeric(parVal), parVal = num2str(parVal); end
                params.(parKey) = parVal;
            end
            % Call Twitter API:
            httpMethod = 'GET';
            url = 'https://api.twitter.com/1.1/users/show.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end
        
        function S = usersSearch(twtr,query,varargin)
        % Runs a search for users similar to "Find People" button on Twitter.com.
        %
        % Usage: S = Twitter_API_obj.usersSearch(query);
        %        S = Twitter_API_obj.usersSearch(query, parKey1, parVal1, parKey2, parVal2, ...);
        % INPUT: query   - the query string;
        % (optional) 
        %        parKey?, 
        %        parVal? - parameters Key/Value pairs. For the complete list, 
        %                  refer to "https://dev.twitter.com/docs/api/1.1/get/users/search".
        % OUTPUT: S      - Response from Twitter API: either a structure
        %                  (requires a JSON parser, or a plain JSON string.
        %                  Only the first 1000 matches are available.
        % Examples:
        % tw = Twitter_API; S = tw.usersSearch('matlab','include_entities','true');

            % Check for credentials:
            twtr.checkCredentials();
            % Parse input:
            if nargin < 2, error('Insufficient number of input arguments.'); end;
            if mod(nargin,2) == 1, error('Wrong number of input arguments.'); end;
            if ~ischar(query), error('Query must be a string.'); end;
            params.q = query;
            for ii=1:2:nargin-2
                parKey = varargin{ii}; parVal = varargin{ii+1};
                if ~ischar(parKey), error('Parameter Key must be a string.'); end
                if isnumeric(parVal), parVal = num2str(parVal); end
                params.(parKey) = parVal;
            end
            % Call Twitter API:
            httpMethod = 'GET';
            url = 'https://api.twitter.com/1.1/users/search.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end
        
%% Accounts
        function S = accountSettings(twtr)
        % Returns settings (including current trend, geo and sleep time information) 
        % for the authenticating user.
        %
        % Usage: S = Twitter_API_obj.accountSettings();
        %        
        % INPUT:         - none.
        %
        % OUTPUT: S      - response from the Twitter API: either a structure
        %                  (requires a JSON parser), or a plain JSON string.
        %
        % For more information, refer to "https://dev.twitter.com/docs/api/1.1/get/account/settings".
        %
        % Examples:
        % tw = Twitter_API; S = tw.accountSettings;
            
            % Check for credentials:
            twtr.checkCredentials();

            params = '';
            % Call Twitter API:
            httpMethod = 'GET';
            url = 'https://api.twitter.com/1.1/account/settings.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end
        
        function S = accountVerifyCredentials(twtr,varargin)
        % Test if supplied user credentials are valid.
        %
        % Usage: S = Twitter_API_obj.accountVerifyCredentials();
        %        S = Twitter_API_obj.accountVerifyCredentials(parKey1, parVal1, parKey2, parVal2, ...);
        % INPUT:    
        % (optional) 
        %        parKey?, 
        %        parVal? - parameters Key/Value pairs. For the complete list, 
        %                  refer to "https://dev.twitter.com/docs/api/1.1/get/account/verify_credentials".
        % OUTPUT: S      - response from the Twitter API: 
        %                  an HTTP 200 OK response code and a representation of the requesting user
        %                  if authentication was successful; returns a 401 status code and an error
        %                  message if not. 
        % Examples:
        % tw = Twitter_API; S = tw.accountVerifyCredentials('include_entities','true');
        
            % Check for credentials:
            twtr.checkCredentials();

            % Parse input:
            if mod(nargin,2) == 0, error('Wrong number of input arguments.'); end;
            if nargin == 1 
                params = '';
            else
                for ii=1:2:nargin-2
                    parKey = varargin{ii}; parVal = varargin{ii+1};
                    if ~ischar(parKey), error('Parameter Key must be a string.'); end
                    if isnumeric(parVal), parVal = num2str(parVal); end
                    params.(parKey) = parVal;
                end
            end
            % Call Twitter API:
            httpMethod = 'GET';
            url = 'https://api.twitter.com/1.1/account/verify_credentials.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end
        
%% Trends
        function S = trendsPlace(twtr,woeid,varargin)
        % Returns the top 10 trending topics for a specific place (woeid), 
        % if trending information is available for it.
        %
        % Usage: S = Twitter_API_obj.trendsPlace(woeid);
        %        S = Twitter_API_obj.trendsPlace(woeid, 'exclude', 'hashtags');
        % INPUT: woeid   - either a string or a number, specifying The Yahoo! Where On Earth ID 
        %                  of the location to return trending information for. 
        %                  Global information is available by using 1 as the woeied;
        % (optional) 
        %      'exclude' - Setting this equal to hashtags will remove all hashtags 
        %                  from the trends list.
        %
        % OUTPUT: S      - response from the Twitter API: either a structure
        %                  (requires a JSON parser), or a plain JSON string.
        %
        % For more information, refer to "https://dev.twitter.com/docs/api/1.1/get/trends/place".
        %
        % Examples:
        % tw = Twitter_API; S = tw.trendsPlace(1);
        
            % Parse input:
            if nargin < 2, error('Insufficient number of input arguments.'); end;
            if mod(nargin,2) == 1, error('Wrong number of input arguments.'); end;
            if isnumeric(woeid)
                woeid = num2str(woeid);
            elseif ~ischar(woeid)
                error('woeid parameter must be either a number or a string.'); 
            end
            if nargin == 2
                params.id = woeid;
            else
                for ii=1:2:nargin-2
                    parKey = varargin{ii}; parVal = varargin{ii+1};
                    if ~ischar(parKey), error('Parameter Key must be a string.'); end
                    if isnumeric(parVal), parVal = num2str(parVal); end
                    params.(parKey) = parVal;
                end
            end
            % Call Twitter API:
            httpMethod = 'GET';
            url = 'https://api.twitter.com/1.1/trends/place.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end
        
        function S = trendsAvailable(twtr)
        % Returns the locations that Twitter has trending topic information for.
        %
        % Usage: S = Twitter_API_obj.trendsAvailable();
        %      
        % INPUT: none.
        % OUTPUT: S      - array of "locations": either a structure
        %                  (requires a JSON parser), or a plain JSON string.
        %
        % For more information, refer to "https://dev.twitter.com/docs/api/1.1/get/trends/available".
        %
        % Examples:
        % 1. tw = Twitter_API; S = tw.trendsAvailable();
        
            % Parse input:
            if nargin > 1, error('Too many input arguments.'); end;
            params = '';
            % Call Twitter API:
            httpMethod = 'GET';
            url = 'https://api.twitter.com/1.1/trends/available.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end
        
        function S = trendsClosest(twtr,coord)
        % Returns the locations that Twitter has trending topic information for, closest to
        % specified location.
        %
        % Usage: S = Twitter_API_obj.trendsClosest(coord);
        % INPUT: (required) 
        %        coord   - either a 2-by-1 vector of latitude and longitude (numeric) or 
        %                  a 2-by-1 cell array of strings: [lat long] or {'lat', 'long'}. 
        %                  The available trend locations will be sorted by distance, nearest to
        %                  furthest, to the coordinate pair. The valid ranges for longitude is
        %                  -180.0 to +180.0 (East is positive), for latitude -90.0 to + 90.0 (North
        %                  is positive). 
        %
        % OUTPUT: S      - an array of "locations": either a structure
        %                  (requires a JSON parser), or a plain JSON string.
        %
        % For more information, refer to "https://dev.twitter.com/docs/api/1.1/get/trends/closest".
        %
        % Examples:
        % 1. tw = Twitter_API; S = tw.trendsAvailable([53.5 -2.25]);
        
            % Parse input:
            if nargin ~= 2, error('Wrong number of input arguments.'); end;
                        
            if numel(coord)~=2 
                error('"coord" argument must be a two-element vector or cell array.'); 
            end
            
            if isnumeric(coord)
                params.lat  = num2str(coord(1));
                params.long = num2str(coord(2));
            elseif iscell(coord)
                params.lat  = coord{1};
                params.long = coord{2};
            else
                error('"coord" argument must be either a vector or a cell array.');
            end                    

            % Call Twitter API:
            httpMethod = 'GET';
            url = 'https://api.twitter.com/1.1/trends/closest.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end

%% Places & Geo
        function S = geoInfo(twtr,placeID)
        % Returns all the information about a known place.
        %
        % Usage: S = Twitter_API_obj.geoInfo(placeID);
        % INPUT: placeID - a string, specifying an ID of a place in the world. 
        %                  These IDs can be retrieved from geoReverseCode.
        %
        % OUTPUT: S      - Response from Twitter API: either a structure
        %                  (requires a JSON parser), or a plain JSON string.
        %
        % For more information, refer to "https://dev.twitter.com/docs/api/1.1/get/geo/id/%3Aplace_id".
        %
        % Examples:
        % tw = Twitter_API; S = tw.geoInfo('6416b8512febefc9');
        
            % Parse input:
            if nargin < 2, error('Insufficient number of input arguments.'); end;
            if ~ischar(placeID), error('The ''placeID'' must be a string.'); end;
            params = '';
            % Call Twitter API:
            httpMethod = 'GET';
            url = ['https://api.twitter.com/1.1/geo/id/' placeID '.json'];
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end
        
        function S = geoReverseCode(twtr,coord,varargin)
        % Given geographical coordinates, searches for up to 20 places that can be used 
        % as a placeID when updating a status.
        %
        % Usage: S = Twitter_API_obj.geoReverseCode(coord);
        %        S = Twitter_API_obj.getReverseCode(..., parKey1, parVal1, parKey2, parVal2, ...);
        % INPUT: coord   - either a 2-by-1 vector of latitude and longitude (numeric) or 
        %                  a 2-by-1 cell array of strings. The valid ranges are 
        %                  -90.0 to + 90.0 for latitude (North positive) and 
        %                  -180.0 to +180.0 for longitude (East positive);
        % (optional) 
        %        parKey?, 
        %        parVal? - parameters Key/Value pairs. For the complete list, 
        %                  refer to "https://dev.twitter.com/docs/api/1.1/get/geo/reverse_geocode".
        % OUTPUT: S      - response from the Twitter API: either a structure
        %                  (requires a JSON parser), or a plain JSON string.
        % Examples:
        % tw = Twitter_API; S = tw.geoReverseCode([53.5 -2.25],'granularity','poi');
            
            % Parse input:
            if nargin < 2, error('Insufficient number of input arguments.'); end;
            if mod(nargin,2) == 1, error('Wrong number of input arguments.'); end;
            % parse coordinates:
            if numel(coord)~=2 
                error('The ''coord'' argument must be a two-element vector or cell array.'); 
            end
            if isnumeric(coord)
                params.lat  = num2str(coord(1));
                params.long = num2str(coord(2));
            elseif iscell(coord)
                params.lat  = coord{1};
                params.long = coord{2};
            else
                error('The ''coord'' argument must be either vector or a cell array.');
            end
            % parse other parameters:
            for ii=1:2:nargin-2
                parKey = varargin{ii}; parVal = varargin{ii+1};
                if ~ischar(parKey), error('Parameter Key must be a string.'); end
                if isnumeric(parVal), parVal = num2str(parVal); end
                params.(parKey) = parVal;
            end
            % Call Twitter API:
            httpMethod = 'GET';
            url = 'https://api.twitter.com/1.1/geo/reverse_geocode.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,0);
        end
        
        function S = geoSearch(twtr,varargin)
        % Search for places that can be attached to a statuses/update.
        %
        % Usage: S = Twitter_API_obj.geoSearch('coord', coord) or
        %        S = Twitter_API_obj.geoSearch('ip', ip) or
        %        S = Twitter_API_obj.geoSearch('query', query);
        %        S = Twitter_API_obj.getFollowersIds(..., parKey1, parVal1, parKey2, parVal2, ...);
        % INPUT:  Specify at least one of the following:
        %        coord       - either a 2-by-1 vector of latitude and longitude (numeric) or 
        %                      a 2-by-1 cell array of strings. The valid ranges are 
        %                      -90.0 to + 90.0 for latitude (North positive) and 
        %                      -180.0 to +180.0 for longitude (East positive);
        %        ip          - a string specifying an IP address;
        %        'query'     - Free-form text for a geo-based query.
        % (optional) 
        %        parKey?, 
        %        parVal? - parameters Key/Value pairs. For the complete list, 
        %                  refer to "https://dev.twitter.com/docs/api/1.1/get/geo/search".
        % OUTPUT: S      - response from the Twitter API: either a structure
        %                  (requires a JSON parser), or a plain JSON string.
        % Examples:
        % 1. tw = Twitter_API; S = tw.geoSearch('coord',[53.5 -2.25],'granularity','city');
        % 2. S = tw.geoSearch('query','manchester','max_results',10);
            
            % Parse input:
            if nargin < 3, error('Insufficient number of input arguments.'); end;
            if mod(nargin,2) == 0, error('Wrong number of input arguments.'); end;
            for ii=1:2:nargin-1                
                parKey = varargin{ii}; parVal = varargin{ii+1};
                if ~ischar(parKey), error('Parameter Key must be a string.'); end
                if strcmpi(parKey,'coord')
                    coord = parVal;
                    if numel(coord)~=2 
                        error('The ''coord'' argument must be a two-element vector or cell array.'); 
                    end
                    if isnumeric(coord)
                        params.lat  = num2str(coord(1));
                        params.long = num2str(coord(2));
                    elseif iscell(coord)
                        params.lat  = coord{1};
                        params.long = coord{2};
                    else
                        error('The ''coord'' argument must be either vector or a cell array.');
                    end
                else
                    if isnumeric(parVal), parVal = num2str(parVal); end
                    params.(parKey) = parVal;                    
                end
            end
            % Call Twitter API:
            httpMethod = 'GET';
            url = 'https://api.twitter.com/1.1/geo/search.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end

        function S = geoSimilarPlaces(twtr,coord,placeName,varargin)
        % Locates places near the given coordinates which are similar in name.
        %
        % Usage: S = Twitter_API_obj.geoSimilarPlaces(coord, placeName);
        %        S = Twitter_API_obj.getFollowersIds(..., parKey1, parVal1, parKey2, parVal2, ...);
        % INPUT: coord     - either a 2-by-1 vector of latitude and longitude (numeric) or 
        %                    a 2-by-1 cell array of strings. The valid ranges are 
        %                    -90.0 to + 90.0 for latitude (North positive) and 
        %                    -180.0 to +180.0 for longitude (East positive);
        %        placeName - the name a place is known as.
        % (optional) 
        %        parKey?, 
        %        parVal?   - parameters Key/Value pairs. For the complete list, 
        %                    refer to "https://dev.twitter.com/docs/api/1.1/get/geo/similar_places".
        % OUTPUT: S        - response from the Twitter API: either a structure
        %                    (requires a JSON parser), or a plain JSON string.
        % Examples:
        % tw = Twitter_API; S = tw.geoSimilarPlaces([53.5 -2.25],'manchester');
            
            % Parse input:
            if nargin < 3, error('Insufficient number of input arguments.'); end;
            if mod(nargin,2) == 0, error('Wrong number of input arguments.'); end;
            % parse coordinates:
            if numel(coord)~=2 
                error('The ''coord'' argument must be a two-element vector or cell array.'); 
            end
            if isnumeric(coord)
                params.lat  = num2str(coord(1));
                params.long = num2str(coord(2));
            elseif iscell(coord)
                params.lat  = coord{1};
                params.long = coord{2};
            else
                error('The ''coord'' argument must be either vector or a cell array.');
            end
            % parse the name:
            if ~ischar(placeName), error('The ''place'' arguments must be a string.'); end;
            params.name = placeName;
            % parse other parameters:
            for ii=1:2:nargin-3                
                parKey = varargin{ii}; parVal = varargin{ii+1};
                if ~ischar(parKey), error('Parameter Key must be a string.'); end
                if strcmpi(parKey,'coord')
                else
                    if isnumeric(parVal), parVal = num2str(parVal); end
                    params.(parKey) = parVal;                    
                end
            end
            % Call Twitter API:
            httpMethod = 'GET';
            url = 'https://api.twitter.com/1.1/geo/similar_places.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,0);
        end
        
%% Help
        function S = helpConfiguration(twtr)
        % Returns the current configuration used by Twitter including twitter.com slugs 
        % which are not usernames, maximum photo resolutions, and t.co URL lengths.
        %
        % Usage: S = Twitter_API_obj.helpConfiguration();
        %        
        % INPUT:         - none.
        %
        % OUTPUT: S      - response from the Twitter API: either a structure
        %                  (requires a JSON parser), or a plain JSON string.
        %
        % For more information, refer to "https://dev.twitter.com/docs/api/1.1/get/help/configuration".
        %
        % Examples:
        % tw = Twitter_API; S = tw.helpConfiguration;
            
            params = '';
            % Call Twitter API:
            httpMethod = 'GET';
            url = 'https://api.twitter.com/1.1/help/configuration.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,1);
        end

        function S = helpLanguages(twtr)
        % Returns the list of languages supported by Twitter along with their ISO 639-1 code.
        %
        % Usage: S = Twitter_API_obj.helpLanguages();
        %        
        % INPUT:         - none.
        %
        % OUTPUT: S      - response from the Twitter API: either a structure
        %                  (requires a JSON parser), or a plain JSON string.
        %
        % For more information, refer to "https://dev.twitter.com/docs/api/1.1/get/help/languages".
        %
        % Examples:
        % tw = Twitter_API; S = tw.helpLanguages;
            
            params = '';
            % Call Twitter API:
            httpMethod = 'GET';
            url = 'https://api.twitter.com/1.1/help/languages.json';
            S = twtr.callTwitterAPI(httpMethod,url,params,0);
        end
        
    end
  
%% The main API caller
    methods(Access = private)
        function S = callTwitterAPI(twtr,httpMethod,url,params,~)
        % Call to the twitter API. 
        %
        % Usage: S = callTwitterAPI(httpMethod, url, params, authorize)
        %
        % INPUT:
        % httpMethod - string: 'GET' or 'POST';
        % url        - string specifying the base URL of the call;
        % params     - structure of key/value pairs of the HTTP request.
        %              The values must be strings.
        % authorize  - 0 or 1, indicating whether authorization is required for the given request.
        %              (since version 1.1 of Twitter API authorization is required for all calls).
        % 
        % OUTPUT:
        % S          - HTTP response variable. If the response format is 'json' and JSON parser
        %              function  is available, S is a structure. Otherwise S is a string.
        %             
        % Examples:
        % 1. Get the home timeline:
        % S = callTwitterAPI('GET','https://api.twitter.com/1.1/statuses/home_timeline.json','',1);
        %
        % 2. Search twitter:
        % httpMethod = 'GET';
        % url = 'http://search.twitter.com/search.json';
        % params = struct('q','matlab','include_entities', 'true');
        % authorize = 0;
        % S = callTwitterAPI(httpMethod,url,params,authorize);
        %
        % 3. Get user timeline:
        % httpMethod = 'GET';
        % url = 'http://api.twitter.com/1/statuses/user_timeline.json';
        % params = struct('include_entities', 'true','screen_name','twitterapi');
        % authorize = 1;
        % S = callTwitterAPI(httpMethod,url,params,authorize);
        %
        % 4. Update status (aka twit):
        % httpMethod = 'POST';
        % url = 'http://api.twitter.com/1/statuses/update.json';
        % params = struct('include_entities','true','status','A test call to twitter from MATLAB.');
        % S = callTwitterAPI(httpMethod,url,params,1);
        % 
        % See also:

        % (c) 2012-13, Vladimir Bondarenko <http://sites.google.com/site/bondsite>

        import java.net.URL 
        import java.io.*;
        import javax.net.ssl.HttpsURLConnection;   
        import java.security.* javax.crypto.*

        % Define the percent encoding function: 
        percentEncode = @(str) strrep( char( java.net.URLEncoder.encode(str,'UTF-8') ),'+','%20');

        % Parse input:
        if nargin~=5, error('Wrong number of input parameters.'); end
        httpMethod = upper(httpMethod);

        % Build complete URL:
        if ~isempty(params)
            params = orderfields(params);
            % Compose parameter string:
            paramStr = '';
            parKey = fieldnames(params);
            for ii=1:length(parKey)
                parVal = percentEncode( params.(parKey{ii}) );
                paramStr = [paramStr parKey{ii} '=' parVal '&'];
            end
            paramStr(end) = []; % remove the last ampersand.
            switch httpMethod
                case 'GET'
                    theURL = URL([], [url '?' paramStr], sun.net.www.protocol.https.Handler);
%                     theURL = URL([url '?' paramStr]);
                case 'POST'
                    theURL = URL([], url, sun.net.www.protocol.https.Handler);
                otherwise
                    error('Uknown request method.');
            end
        else
            theURL = URL([],url, sun.net.www.protocol.https.Handler);
        end

        % Open http connection:
        httpConn = theURL.openConnection;
        httpConn.setRequestProperty('Content-Type', 'application/x-www-form-urlencoded');

        % Set authorization property if required:
        authorize = 1;   % since API v1.1, all calls to the twitter API must be authorized.
        if authorize
            % define oauth parameters:
            signMethod = 'HMAC-SHA1';
            params.oauth_consumer_key = twtr.credentials.ConsumerKey;
            params.oauth_nonce = strrep([num2str(now) num2str(rand)], '.', '');
            params.oauth_signature_method = signMethod;
            params.oauth_timestamp = int2str((java.lang.System.currentTimeMillis)/1000);
            params.oauth_token = twtr.credentials.AccessToken;
            params.oauth_version = '1.0';
            params = orderfields(params);

            % Compose oauth parameters string:
            oauth_paramStr = '';
            parKey = fieldnames(params);
            for ii=1:length(parKey)
                parVal = percentEncode( params.(parKey{ii}) );
                oauth_paramStr = [oauth_paramStr parKey{ii} '=' parVal '&'];
            end
            oauth_paramStr(end) = []; % remove the last ampersand.
            % Create the signature base string and signature key:
            signStr = [ upper(httpMethod) '&' percentEncode(url) '&'...
                             percentEncode(oauth_paramStr) ];
            signKey = [ twtr.credentials.ConsumerSecret '&'... 
                               twtr.credentials.AccessTokenSecret];
            % Calculate the signature by the HMAC-SHA1 algorithm:
            import javax.crypto.spec.*                               % key spec methods
            import org.apache.commons.codec.binary.*    % base64 codec
            algorithm = strrep(signMethod,'-','');
            key = SecretKeySpec(int8(signKey), algorithm);
            mac = Mac.getInstance(algorithm);
            mac.init(key);
            mac.update( int8(signStr) );
            params.oauth_signature = char( Base64.encodeBase64(mac.doFinal)' );
            params = orderfields(params);
            % Build the HTTP header string:
            httpAuthStr = 'OAuth ';
            parKey = fieldnames(params);
            ix_mask = ~cellfun(@isempty, strfind(parKey,'oauth'));
            ix = find(ix_mask');
            for ii=ix
                httpAuthStr = [ httpAuthStr ... 
                                percentEncode(parKey{ii}) '="'... 
                                percentEncode(params.(parKey{ii})) '", '];
            end
            httpAuthStr(end-1:end) = []; % remove the last comma-space.

            % Set the http connection's Authorization property:
            httpConn.setRequestProperty('Authorization', httpAuthStr);
        end

        % if POST request:
        if strcmpi(httpMethod,'POST')
            % Configure the POST request:
            httpConn.setUseCaches (false);
            httpConn.setRequestMethod('POST');
            if exist('paramStr','var')
                httpConn.setRequestProperty('CONTENT_LENGTH', num2str(length(paramStr)));
                httpConn.setDoOutput(true);

                outputStream = httpConn.getOutputStream;
                outputStream.write(java.lang.String(paramStr).getBytes());
                outputStream.close;
            end
        end
       
        % open the connection:
        try
            inStream = BufferedReader( InputStreamReader( httpConn.getInputStream ) );
        catch ME
            error('Twitter_API:connectionError', ME.message);
%             errStream = BufferedReader( InputStreamReader(httpConn.getErrorStream) );
        end
        
        % start reading from the connection:
        s = ''; cnt = 0;
        sLine = inStream.readLine;
        
        % Check if the connection is to the normal or stream API:
        if isempty(strfind(url,'https://stream.twitter.com'))
            % normal api:
            while ( ~isempty(sLine) ) 
                s = [s sLine];
                sLine = inStream.readLine;
            end
        else
            % streaming api:
            while (~isempty(sLine)) && ( cnt < twtr.sampleSize )
                if ~(sLine.isEmpty)
                    s = [s sLine]; cnt = cnt + 1;
                    % when the batch is completed, call the output function to process it:
                    if mod(cnt,twtr.batchSize)==0
                        S = twtr.parseTwitterResponse(s);
                        if twtr.ownOutFcn
                            twtr.outFcn(S);
                        else
                            twtr.outFcn(twtr,S);
                        end
                        s = []; % clear the batch.
                    end
                end
                sLine = inStream.readLine;
            end
        end
        
        % close the connection:
        inStream.close;
        
        % convert the Twitter response from java string to a MATLAB type.
        if ~isempty(s)
            S = twtr.parseTwitterResponse(s);
            % if an outFcn is set, process the accumulated tweets:
            if ~isempty(twtr.outFcnStr)
                % output function calls are different for Twitter_API's own methods and user-defined
                % functions:
                if twtr.ownOutFcn
                    twtr.outFcn(S);
                else
                    twtr.outFcn(twtr,S);
                end
            end
        end
        
        end
    end

    methods (Access = private, Hidden=true)
        function checkCredentials(twtr)
        % Issue an error if credentials are not set or are not valid.
            if isempty(twtr.credentials)
                error(['Twitter credentials are not set.\n',...
                       'Set credentials using either ''setCredentials()'' or ''saveCredentials()'' method.']);
            end
        end        
    end
    
%% Auxiliary output functions
    methods
        function displayStatusText(~, S)
        % Display the text of the Twitter statuses in the command window. 
        %
        % Usage: Twitter_API_obj.displayStatusText(S)
        % INPUT:
        %  S - cell array of structures containing Twitter statuses.
        % OUTPUT: none. 
        %
        % Examples:
        %  tw=Twitter_API; tw.outFcn=@tw.displayStatusText; S = tw.sampleStatuses;
        
            % Parse input:
            if length(S)==1 && isfield(S{1}, 'statuses')
                T = S{1}.statuses;
            else
                T = S;
            end
            % Display text:
            for ii=1:length(T)
                if isfield(T{ii}, 'text')
                    disp(T{ii}.text);
                else
                    disp(T{ii});
                end
            end
        end
        
        function displayStatusHashtags(~, S)
        % Display the hashtags of the Twitter statuses in the command window. 
        %
        % Usage: Twitter_API_obj.displayStatusHashtags(S)
        % INPUT:
        %  S - cell array of structures containing Twitter statuses.
        % OUTPUT: none.
        % Examples:
        %  tw=Twitter_API; tw.outFcn=@tw.displayStatusHashtags; S = tw.sampleStatuses;
        
            % Parse input:
            if length(S)==1 && isfield(S{1}, 'statuses')  % if S is returned by Twitter_API.search(query)
                T = S{1}.statuses;                        % command.  
            else
                T = S;
            end
            % Display hash tags:
            for ii=1:length(T)
                if isfield(T{ii},'entities')
                    ht = '';
                    for jj=1:length(T{ii}.entities.hashtags)
                        ht = [ht ', ' T{ii}.entities.hashtags{jj}.text];
                    end
                    disp(ht);
                end
            end
        end
        
        function plotStatusLocation(twtr, S)
        % Plot tweets geo-locations on a world map.
        %
        % Usage: Twitter_API_obj.plotStatusLocation(twtr, S)
        % INPUT: 
        %  S - cell array of structures containing Twitter statuses.
        % OUTPUT: none.
        %
        % Requirement: the coastLine.mat file with the coordinates of the Earth coast lines. 
        %
        % Examples: 
        %  tw = Twitter_API; tw.outFcn=@tw.plotStatusLocation; tw.sampleSize=5000; tw.batchSize=1; 
        %  S = tw.sampleStatuses;
            
            % Initialization:
            if ~twtr.data.outFcnInitialized
                twtr.data.fh = figure(9991); clf;
                if exist('coastLine.mat', 'file')    % load the lon-lat coordinates of Earth coasts
                    coasts = load('coastLine.mat');
                    plot(coasts.coastLine(:,1), coasts.coastLine(:,2), 'k.', 'MarkerSize', 4);
                    hold on;
                end
                twtr.data.title = datestr(now,'dd-mmm-yyyy: HH:MM');
                title(twtr.data.title,'FontSize', 14);
                twtr.data.outFcnInitialized = 1; % indicate that the function has been initialized.
            end
            
            % Main function:
            for ii=1:length(S)
                if isfield(S{ii},'geo')
                    if ~isempty(S{ii}.geo)
                        figure(twtr.data.fh)
                        if strfind(S{ii}.text,'RT @') % if retweet.
                            mtype = 's';
                            mcolor = 'kb';
                        else 
                            mtype = 'kd'
                            mcolor = 'm';
                        end
                        plot( S{ii}.geo.coordinates{2},... 
                              S{ii}.geo.coordinates{1}, mtype, 'MarkerSize', 5,...
                                                               'LineWidth', 1,...
                                                               'MarkerFaceColor', mcolor);
                        title([twtr.data.title ' - ' datestr(now,'HH:MM:SS')], 'FontSize', 14);
                        refresh(twtr.data.fh);
                    end
                elseif isfield(S{ii},'statuses')   % e.g., if S is returned by tw.search() function.
                    for k=1:length(S{ii}.statuses)
                        if ~isempty(S{ii}.statuses{k}.geo)
                            if strfind(S{ii}.statuses{k}.text,'RT @') % if retweet.
                                mtype = 's';
                                mcolor = 'kb';
                            else 
                                mtype = 'kd'
                                mcolor = 'm';
                            end
                            plot(S{ii}.statuses{k}.geo.coordinates{2},...
                                 S{ii}.statuses{k}.geo.coordinates{1},...
                                 mtype, 'MarkerSize', 5,...
                                 'LineWidth', 1,...
                                 'MarkerFaceColor', mcolor);
                        end
                    end
                end
            end
        end
        
        function statsTwitterUsageByLanguage(twtr,S)
        % Compute the statistics: number of tweets per language.
        %
        % Usage: Twitter_API_obj.statsTwitterUsageByLanguage(twtr.S)
        % INPUT: 
        % S - cell array of structures of Twitter statuses.
        % OUTPUT: none. 
        %         The statistics is stored in the cell array Twitter_API_obj.data.stats.
        %
        % Example:
        %   tw = Twitter_API; tw.sampleSize = 1000; tw.batchSize = 20;
        %   tw.outFcn = @tw.statsTwitterUsageByLanguage;
        %   tw.sampleStatuses;
        %  
        % To visualize the resulting statistics as a histogram, run the following code:
        %    stats = sortrows(tw.data.stats, -2); % sort rows by the 2nd column in descending order.
        %    bar([stats{:,2}]); 
        %    set(gca,'XTick',1:length(stats),'XTickLabel',stats(:,1));
            
            % Initialization:
            if ~twtr.data.outFcnInitialized
                twtr.data.stats = {'en', 0};
                twtr.data.outFcnInitialized = 1; % indicate that the function has been initialized.
            end
            
            % Main function:
            % 1. Update usage statistics with the current batch of tweets:
            for ii=1:length(S)
                if isfield(S{ii},'lang')
                    if ~isempty(S{ii}.lang)
                        lang = S{ii}.lang;
                        ix = find(strcmpi(twtr.data.stats(:,1),lang)); 
                        if isempty(ix)
                            twtr.data.stats(end+1,:) = {lang, 1}; % add a new language,
                        else % or increment the record for the existing one:
                            twtr.data.stats{ix,2} = twtr.data.stats{ix,2}+1;
                        end
                    end
                elseif isfield(S{ii},'statuses')   % e.g., if S is returned by tw.search() function.
                    for k=1:length(S{ii}.statuses)
                        if ~isempty(S{ii}.statuses{k}.lang)
                            lang = S{ii}.statuses{k}.lang;
                            ix = find(strcmpi(twtr.data.stats(:,1),lang));
                            if isempty(ix)
                                twtr.data.stats(end+1,:) = {lang, 1};
                            else
                                twtr.data.stats{ix,2} = twtr.data.stats{ix,2}+1;
                            end                            
                        end
                    end
                end
            end
        end   
    end
end