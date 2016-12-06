classdef LSL < Signal_IO
   
    properties
        readMrkStream = false
        lib
        EEG_inlet
        Marker_inlet
        serialTrigger
        data_buffer
        debugMode
        Marker_outlet
        info
        trialStart_ts
        trialStop_ts
    end
    
    methods
        %------------------------------------------------------------------
        % Class constructor: initializes the signal source buffer. It takes
        % as input the trial length (in seconds), a 1 or 0 to indicate if
        % delay should be used and the comm port as a string (i.e. 'COM9'),
        % respectively
        function lsl = LSL(trialLength,includeDelay,channels,debugMode)
            lsl@Signal_IO('LSL',channels);
            lsl.debugMode = debugMode;
            
            % load LSL library
            lsl.lib = lsl_loadlib(); 
            
            % initialize lsl marker stream
            lsl.info = lsl_streaminfo(lsl.lib,'SSVEP-Markers','Markers',1,0,'cf_string','SSVEP-Speller');
            lsl.Marker_outlet = lsl_outlet(lsl.info);
            
            % if not in offline or debug mode, get EEG and marker streams
            % for real-time feedback
            if(~debugMode)
                % Resolve EEG stream
                result={};
                while isempty(result)
                    result = lsl_resolve_byprop(lsl.lib,'type','EEG'); end
                lsl.EEG_inlet = lsl_inlet(result{1});
                lsl.Fs = lsl.EEG_inlet.info.nominal_srate();
                lsl.blockSize = trialLength*lsl.Fs;
                lsl.delay=floor(lsl.Fs*lsl.delayAmount*includeDelay);
                lsl.data_buffer = zeros(lsl.num_ch,ceil(trialLength*lsl.Fs)+lsl.Fs);
                lsl.EEG_inlet.pull_chunk(); % initial flush of buffer
                
                if(lsl.readMrkStream)
                    % Resolve Marker stream
                    result={};
                    while isempty(result)
                        result = lsl_resolve_byprop(lsl.lib,'type','Markers'); end
                    lsl.Marker_inlet = lsl_inlet(result{1});
                    % open the stream
                    lsl.Marker_inlet.open_stream();
                end
            end
            
        end
        
        %------------------------------------------------------------------
        function data = readBuffer(obj)
            % new and improved
            if(~obj.debugMode)
                    [tmp_data, timestamps] = obj.EEG_inlet.pull_chunk();
                    data = tmp_data(obj.channels,timestamps>=obj.trialStart_ts & timestamps<=obj.trialStop_ts);
                    obj.waitingOnData=false;
            else
                data=[];
            end
        end
        
        function data = readBufferV1(obj)
        %READBUFFER reads data from the signal buffer
            if(~obj.debugMode)
                obj.waitingOnData=true;
                while(obj.waitingOnData)
                    % extract a marker sample from lsl
                    mrk=[]; 
                    while(isempty(mrk))
                        [mrk, ts] = obj.Marker_inlet.pull_sample(0);
                    end
                    % check to see if it's a start event marker
                    if(strcmp(mrk,'trial_start'))
                        mrk_idx(1) = ts;
                    elseif(strcmp(mrk,'trial_stop'))
                        mrk_idx(2) = ts;
                        % once we see a trial_end, grab data between start
                        % and end time-stamps
                        [tmp_data, timestamps] = obj.EEG_inlet.pull_chunk();
                        data=tmp_data(:,timestamps>=mrk_idx(1) & timestamps<=mrk_idx(2));
                        obj.waitingOnData = false;
                    end
                end
            else
                data=[];
            end
        end
        
        function data=readBufferV2(obj)
        %READBUFFER reads data from the signal buffer
            if(~obj.debugMode)
                obj.waitingOnData=true;
                while(obj.waitingOnData)
                    temp_data = obj.inlet.pull_chunk();
                    obj.data_buffer(:,1:end-size(temp_data,2)) =obj.data_buffer(:,size(temp_data,2)+1:end);
                    obj.data_buffer(:,end-size(temp_data,2)+1:end)=temp_data([obj.channels end],:);
                    startIdx = find(obj.data_buffer(end,2:end)==256 & obj.data_buffer(end,1:end-1)==0,1);

                    if(~isempty(startIdx) && size(obj.data_buffer,2)>=(startIdx+obj.blockSize+obj.delay-1))
                        data = obj.data_buffer(1:end-1,startIdx+obj.delay:startIdx+obj.delay+obj.blockSize-1)';
                        data = EEGfilter(data,obj.Fs,1);  % filter data
                        obj.waitingOnData = false;
                    end
                end
            else
                data=[];
            end
        end
        
        function sendMarker(obj,marker)
        %SENDMARKER sends an lsl marker to be collected and time-stamped
        %with the lsl server for marking events within the speller task
            obj.Marker_outlet.push_sample({marker},lsl_local_clock(obj.lib));
        end
        
        function sendStartMarker(obj,marker)
        %SENDMARKER sends an lsl marker to be collected and time-stamped
        %with the lsl server for marking events within the speller task
            obj.trialStart_ts = lsl_local_clock(obj.lib);
            obj.Marker_outlet.push_sample({marker},obj.trialStart_ts);
            
        end
        
        function sendStopMarker(obj,marker)
        %SENDMARKER sends an lsl marker to be collected and time-stamped
        %with the lsl server for marking events within the speller task
            obj.trialStop_ts = lsl_local_clock(obj.lib);
            obj.Marker_outlet.push_sample({marker},obj.trialStop_ts); 
        end
        
        function sendTrigger(obj,flag)
        %SENDTRIGGER sends a trigger pulse to mark start or end of trial
        %base on the flag. (this function is deprecated)
            if(~obj.debugMode)
                switch flag
                    case 'start'
                        flushBuffer(obj); % flush buffer before start of trial
                    case 'stop'
                end
            end
        end
        
        function terminate(obj)
        %TERMINATE terminates lsl streams
            if(~obj.debugMode)
                obj.EEG_inlet.delete();
                obj.Marker_inlet.delete();
            end
            obj.Marker_outlet.delete();
        end
        
        function flushBuffer(obj)
        %FLUSHBUFFER flushes out the lsl inlet of all data. lsl
        %inlet.pull_chunk() contains all samples from which the las pull
        %was requested
            obj.EEG_inlet.pull_chunk(); % throw away unused data in the buffer
            obj.Marker_inlet.pull_chunk(); 
        end
    end
end