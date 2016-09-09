classdef LSL_orig < Signal_IO
   
    properties
        lib
        inlet
        serialTrigger
        data_buffer
        debugMode
        outlet
        info
    end
    
    methods
        %------------------------------------------------------------------
        % Class constructor: initializes the signal source buffer. It takes
        % as input the trial length (in seconds), a 1 or 0 to indicate if
        % delay should be used and the comm port as a string (i.e. 'COM9'),
        % respectively
        function lsl = LSL_orig(trialLength,includeDelay,channels,debugMode,CommPort)
            lsl@Signal_IO('LSL',channels);
            % load LSL library
            lsl.lib = lsl_loadlib();
            lsl.debugMode = debugMode;
            if(~debugMode)
                % initialize LSL buffer and resolve EEG stream
                result={};
                while isempty(result)
                    result = lsl_resolve_byprop(lsl.lib,'type','EEG'); end
                lsl.inlet = lsl_inlet(result{1});
                lsl.Fs = lsl.inlet.info.nominal_srate();
                lsl.blockSize = trialLength*lsl.Fs;
                lsl.delay=floor(lsl.Fs*lsl.delayAmount*includeDelay);
                lsl.data_buffer = zeros(lsl.num_ch+1,ceil(trialLength*lsl.Fs)+lsl.Fs);
                lsl.inlet.pull_chunk(); % initial flush of buffer
                
                % initialize serial trigger
                lsl.serialTrigger = serial(CommPort,'BaudRate',57600);  %replace COM3 with the actual port number your adapter is assigned to
                fopen(lsl.serialTrigger);
            end
            
            % initialize lsl marker stream
            lsl.info = lsl_streaminfo(lsl.lib,'SSVEP-Markers','Markers',1,0,'cf_string','brainflightNB');
            lsl.outlet = lsl_outlet(lsl.info);
        end
        
        %------------------------------------------------------------------
        
        function data=readBuffer(obj)
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
            obj.outlet.push_sample({marker});
        end
        
        function sendTrigger(obj,flag)
        %SENDTRIGGER sends a trigger pulse to mark start or end of trial
        %base on the flag
            if(~obj.debugMode)
                switch flag
                    case 'start'
                        flushBuffer(obj); % flush buffer before start of trial
                        fwrite(obj.serialTrigger,1,'uint8');
                    case 'stop'
                        fwrite(obj.serialTrigger,0,'uint8');
                end
            end
        end
        
        function terminate(obj)
        %TERMINATE terminates the signal buffer
            if(~obj.debugMode)
                fclose(obj.serialTrigger);
            end
        end
        
        function flushBuffer(obj)
        %FLUSHBUFFER flushes out the lsl inlet of all data. lsl
        %inlet.pull_chunk() contains all samples from which the las pull
        %was requested
            obj.inlet.pull_chunk(); % throw away unused data in the buffer
        end
    end
end