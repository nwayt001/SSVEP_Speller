classdef FT_Nautilus < Signal_IO
    
% FT_Nautilus is the signal aqcuisition module that accesses EEG data from
% the fieldtrip buffer from bci2000. It's designed to work with the
% g.Nautilus Amplifier with parallel port communication!
    properties
        ft_buffer
        hdr
        parallel_obj
        parallel_status
        parallel_address
        prevSample
        debugMode
    end
    methods
        %------------------------------------------------------------------
        % Class constructor: initializes the signal source buffer. It takes
        % as input the trial length (in seconds), and a 1 or 0 to indicate 
        % if delay should be used, respectively.
        
        function ft = FT_Nautilus(trialLength,includeDelay,channels,debugMode)
            ft@Signal_IO('FT_Nautilus',channels);
            ft.debugMode = debugMode;
            
            if(~debugMode)
                % initialize ft buffer and get sampling frequency
                ft.ft_buffer = 'buffer://localhost:1972';
                ft.prevSample = 0;
                ft.hdr = ft_read_header(ft.ft_buffer,'cache',true);
                ft.Fs = ft.hdr.Fs;
                ft.blockSize = trialLength*ft.Fs;
                ft.delay=floor(ft.Fs*ft.delayAmount*includeDelay);
                
                % initialize paralle port comms
                ft.parallel_obj = io64();
                ft.parallel_status = io64(ft.parallel_obj);
                ft.parallel_address = hex2dec('378');
                io64(ft.parallel_obj,ft.parallel_address,0);
            end
        end
        %------------------------------------------------------------------
        
        function data=readBuffer(obj)
        %READBUFFER reads data from the signal buffer and extracts one
        %trial
            if(~obj.debugMode)
                obj.waitingOnData=true;
                while(obj.waitingOnData)
                    obj.hdr = ft_read_header(obj.ft_buffer,'cache',true);
                    newsamples = (obj.hdr.nSamples*obj.hdr.nTrials);
                    begsample = obj.prevSample+1;
                    data = ft_read_data(obj.ft_buffer, 'header', obj.hdr, 'begsample', begsample, 'endsample', newsamples, 'chanindx', 1:obj.hdr.nChans);
                    data = data';
                    startIdx = find(data(2:end,end)==0 & data(1:end-1,end)==1, 1);

                    if(~isempty(startIdx))
                        if(size(data,1) >= (startIdx+obj.blockSize+obj.delay-1))
                            data = data(startIdx+obj.delay:startIdx+obj.delay+obj.blockSize-1,obj.channels);
                            obj.prevSample = obj.prevSample+startIdx+obj.delay+obj.blockSize;
                            obj.waitingOnData = false;
                        end
                    end
                end
            else
                data=[];
            end
        end
        
        function sendTrigger(obj,flag)
        %SENDTRIGGER sends a trigger pulse to mark start or end of trial
        %base on the flag
            if(~obj.debugMode)
                switch flag
                    case 'start'
                        io64(ft.parallel_obj,ft.parallel_address,1);
                    case 'stop'
                        io64(ft.parallel_obj,ft.parallel_address,0);
                end
            end
        end
        
        function terminate(obj)
        %TERMINATE terminates the signal buffer
            if(~obj.debugMode)
                clear obj.parallel_obj
            end
        end
    end
end